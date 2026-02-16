function Invoke-ExecSharePointInviteGuest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter

    try {
        $ResultMessages = [System.Collections.Generic.List[string]]::new()

        # Step 1: Invite the guest user to the tenant
        $RedirectUrl = if ($Request.Body.redirectUri) { $Request.Body.redirectUri } else { 'https://myapps.microsoft.com' }
        $InviteBody = [pscustomobject]@{
            InvitedUserDisplayName  = $Request.Body.displayName
            InvitedUserEmailAddress = $Request.Body.mail
            sendInvitationMessage   = [bool]$Request.Body.sendInvite
            inviteRedirectUrl       = $RedirectUrl
        }
        $InviteBodyJson = ConvertTo-Json -Depth 10 -InputObject $InviteBody -Compress
        $InviteResult = New-GraphPostRequest -uri 'https://graph.microsoft.com/beta/invitations' -tenantid $TenantFilter -type POST -body $InviteBodyJson -Verbose

        $GuestUserId = $InviteResult.invitedUser.id
        $GuestUPN = $InviteResult.invitedUser.userPrincipalName

        if ($Request.Body.sendInvite -eq $true) {
            $ResultMessages.Add("Invited guest $($Request.Body.displayName) ($($Request.Body.mail)) with email invite.")
        } else {
            $ResultMessages.Add("Invited guest $($Request.Body.displayName) ($($Request.Body.mail)) without email invite.")
        }

        # Step 2: Add guest to the target resource
        if ($Request.Body.TeamID -and $GuestUserId) {
            # Teams mode: add guest to the Team via Graph API.
            # Azure AD needs a few seconds to propagate the freshly-invited guest
            # user object before it can be resolved for team membership, so we
            # retry with increasing delays.
            $TeamID = $Request.Body.TeamID
            $TeamMemberBody = @{
                '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                'roles'           = @()
                'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$GuestUserId')"
            } | ConvertTo-Json -Depth 5

            $MaxRetries = 3
            $RetryDelays = @(5, 10, 15)
            $TeamAddSuccess = $false

            # Initial delay: the guest was just created, give Azure AD time to propagate
            Start-Sleep -Seconds 5

            for ($i = 0; $i -lt $MaxRetries; $i++) {
                try {
                    if ($i -gt 0) {
                        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Retry $i/$MaxRetries: waiting $($RetryDelays[$i])s for guest user to propagate before adding to Team" -Sev 'Debug'
                        Start-Sleep -Seconds $RetryDelays[$i]
                    }
                    $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members" -tenantid $TenantFilter -type POST -body $TeamMemberBody
                    $ResultMessages.Add("Added guest as a member of the Team.")
                    $TeamAddSuccess = $true
                    break
                } catch {
                    $TeamError = Get-CippException -Exception $_
                    $ErrorMsg = [string]$TeamError.NormalizedError + [string]$TeamError.Message
                    # Only retry on transient/propagation errors, not permission errors
                    if ($ErrorMsg -match '403' -or $ErrorMsg -match 'Authorization_RequestDenied' -or $ErrorMsg -match 'Access denied') {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to Team: Insufficient permissions. Ensure the CIPP app has 'Group.ReadWrite.All' application permission and CPV consent has been refreshed for this tenant.")
                        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add guest to Team (permissions): $($TeamError.NormalizedError)" -Sev 'Warning' -LogData $TeamError
                        $TeamsAddWarning = $true
                        break
                    }
                    if ($i -eq ($MaxRetries - 1)) {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to Team after $MaxRetries attempts: $($TeamError.NormalizedError)")
                        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add guest to Team after $MaxRetries retries: $($TeamError.NormalizedError)" -Sev 'Warning' -LogData $TeamError
                        $TeamsAddWarning = $true
                    }
                }
            }
        } elseif ($Request.Body.SharePointType -eq 'Group' -and $Request.Body.groupId -and $GuestUserId) {
            # SharePoint Group-connected site: add guest to the M365 group
            try {
                $GroupId = $Request.Body.groupId
                if ($GroupId -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                    $GroupId = (New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$GroupId' or proxyAddresses/any(x:endsWith(x,'$GroupId')) or mailNickname eq '$GroupId'" -ComplexFilter -tenantid $TenantFilter).id
                }

                if ($GroupId) {
                    $MemberIdentifier = if ($GuestUPN) { $GuestUPN } else { $GuestUserId }
                    $null = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $MemberIdentifier -TenantFilter $TenantFilter -Headers $Headers
                    $ResultMessages.Add("Added guest as a member of the SharePoint site.")
                } else {
                    $ResultMessages.Add("Warning: Could not resolve group ID for site membership.")
                }
            } catch {
                $GroupError = Get-CippException -Exception $_
                $ResultMessages.Add("Guest invited, but failed to add to site group: $($GroupError.NormalizedError)")
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add guest to site group: $($GroupError.NormalizedError)" -Sev 'Warning' -LogData $GroupError
            }
        } elseif ($Request.Body.SharePointType -ne 'Group') {
            # Non-group site (Communication, classic Team, etc.): add guest to the
            # site's Members permission group via SharePoint REST API.
            $SiteUrl = $Request.Body.URL
            if ($SiteUrl -and $GuestUPN) {
                try {
                    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                    $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                    $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
                    $SPContentType = 'application/json;odata=verbose'
                    $LoginName = "i:0#.f|membership|$GuestUPN"

                    # Ensure the guest user exists in the site's User Information List
                    # Note: SharePoint REST _api/web endpoints do not support app-only tokens,
                    # so we use delegated auth (SAM refresh token) instead of -AsApp $true.
                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                    # Add the user to the site's default Members permission group
                    $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                    $ResultMessages.Add("Added guest as a member of the SharePoint site.")
                } catch {
                    $SiteError = Get-CippException -Exception $_
                    $ErrorMsg = [string]$SiteError.NormalizedError + [string]$SiteError.Message
                    if ($ErrorMsg -match 'ID3035' -or $ErrorMsg -match 'is malformed' -or $ErrorMsg -match 'Could not get token') {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to site members: The CIPP app registration is missing the SharePoint 'AllSites.FullControl' delegated permission. To fix: Go to CIPP Settings > Super Admin > SAM App Permissions, ensure the SharePoint 'AllSites.FullControl' scope is included, then refresh CPV consent for this tenant.")
                    } elseif ($ErrorMsg -match 'Unsupported app only token') {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to site members: SharePoint rejected the app-only token. This is an internal error -- please report it.")
                    } elseif ($ErrorMsg -match 'unauthorized' -or $ErrorMsg -match 'Access denied' -or $ErrorMsg -match '403') {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to site members: Insufficient SharePoint permissions. Ensure CPV consent has been refreshed for this tenant so the CIPP SAM app has 'AllSites.FullControl' delegated access.")
                    } else {
                        $ResultMessages.Add("Guest invited to tenant, but could not add to site members: $($SiteError.NormalizedError)")
                    }
                    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add guest to non-group site members: $($SiteError.NormalizedError)" -Sev 'Warning' -LogData $SiteError
                    $NonGroupSiteWarning = $true
                }
            } else {
                $ResultMessages.Add("Guest invited to tenant. Site URL or guest identity not available for automatic site membership.")
                $NonGroupSiteWarning = $true
            }
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($ResultMessages -join ' ') -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = @($ResultMessages) }
        if ($NonGroupSiteWarning) {
            $Body['NonGroupSiteWarning'] = $true
        }
        if ($TeamsAddWarning) {
            $Body['TeamsAddWarning'] = $true
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = "Failed to invite guest. $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ErrorText -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{ Results = @($ErrorText) }

        # Attempt to diagnose domain collaboration errors
        # Wrapped in safety try/catch so diagnostics never cause a 500
        try {
            $NormError = [string]$ErrorMessage.NormalizedError
            $RawError = [string]$ErrorMessage.Message
            $IsDomainError = $NormError -like '*does not allow collaboration*' -or $NormError -like '*collaboration with the domain*' -or $RawError -like '*does not allow collaboration*' -or $RawError -like '*collaboration with the domain*'

            if ($IsDomainError -and $Request.Body.mail) {
                $BlockedDomain = ($Request.Body.mail -split '@')[1]
                $DiagList = [System.Collections.Generic.List[hashtable]]::new()

                # --- Check Entra External Collaboration settings ---
                try {
                    $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

                    if ($AuthPolicy.allowInvitesFrom -eq 'none') {
                        $DiagList.Add(@{
                            source       = 'Entra External Collaboration'
                            issue        = 'Guest invitations are completely disabled'
                            detail       = "The Guest invite restrictions setting is set to No one in the organization can invite guest users including admins. All guest invitations will be blocked regardless of domain."
                            fix          = 'Change the guest invite restrictions to allow at least admins and users in the Guest Inviter role to send invitations.'
                            settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                            severity     = 'error'
                        })
                    }

                    # Check B2B domain allow/block lists
                    try {
                        $B2BPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
                        $B2BManagement = $B2BPolicy | Where-Object { $_.type -eq 6 }
                        if ($B2BManagement) {
                            $B2BDefinition = ($B2BManagement.definition | ConvertFrom-Json).B2BManagementPolicy
                            $DomainPolicy = $B2BDefinition.InvitationsAllowedAndBlockedDomainsPolicy

                            if ($DomainPolicy.AllowedDomains -and $DomainPolicy.AllowedDomains.Count -gt 0) {
                                if ($BlockedDomain -notin $DomainPolicy.AllowedDomains) {
                                    $DiagList.Add(@{
                                        source       = 'Entra External Collaboration'
                                        issue        = "Domain '$BlockedDomain' is not in the allowed domains list"
                                        detail       = "The tenant uses a domain allow-list for guest invitations. Only these domains can be invited: $($DomainPolicy.AllowedDomains -join ', '). The domain '$BlockedDomain' is not on this list."
                                        fix          = "Add '$BlockedDomain' to the allowed domains list in External Collaboration settings, or switch to a block-list approach."
                                        settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                                        severity     = 'error'
                                        currentList  = @($DomainPolicy.AllowedDomains)
                                        listType     = 'allowList'
                                    })
                                }
                            }

                            if ($DomainPolicy.BlockedDomains -and $DomainPolicy.BlockedDomains.Count -gt 0) {
                                if ($BlockedDomain -in $DomainPolicy.BlockedDomains) {
                                    $DiagList.Add(@{
                                        source       = 'Entra External Collaboration'
                                        issue        = "Domain '$BlockedDomain' is explicitly blocked"
                                        detail       = "The domain '$BlockedDomain' appears in the blocked domains list for guest invitations."
                                        fix          = "Remove '$BlockedDomain' from the blocked domains list in External Collaboration settings."
                                        settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                                        severity     = 'error'
                                        currentList  = @($DomainPolicy.BlockedDomains)
                                        listType     = 'blockList'
                                    })
                                }
                            }
                        }
                    } catch {
                        # B2B management policy may not be available in all tenants
                    }
                } catch {
                    # Could not retrieve Entra External Collaboration settings
                }

                if ($Request.Body.TeamID) {
                    # --- Check Teams guest access settings ---
                    try {
                        $ClientConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsClientConfiguration' -CmdParams @{Identity = 'Global' }
                        if ($ClientConfig.AllowGuestUser -eq $false) {
                            $DiagList.Add(@{
                                source       = 'Teams Guest Access'
                                issue        = 'Guest access is disabled for Microsoft Teams'
                                detail       = 'The Teams tenant setting "Allow guest access" is currently disabled. Guests cannot be added to any teams until this is enabled.'
                                fix          = 'Enable guest access in Teams Settings > Guest & Cloud Storage, or use the CIPP Teams Settings page.'
                                settingsPage = '/teams-share/teams/teams-settings'
                                severity     = 'error'
                            })
                        }
                    } catch {
                        # Teams settings may not be accessible
                    }
                } else {
                    # --- Check SharePoint sharing settings ---
                    try {
                        $SPSettings = New-GraphGetRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true

                        if ($SPSettings.sharingCapability -eq 'disabled') {
                            $DiagList.Add(@{
                                source       = 'SharePoint Sharing Settings'
                                issue        = 'External sharing is completely disabled for SharePoint'
                                detail       = "SharePoint external sharing is set to Only people in your organization. No external guests can access any SharePoint content."
                                fix          = "Enable external sharing in SharePoint Sharing Settings. At minimum, set it to Existing guests or New and existing guests."
                                settingsPage = '/teams-share/sharepoint/sharing-settings'
                                severity     = 'error'
                            })
                        }

                        if ($SPSettings.sharingDomainRestrictionMode -eq 'allowList') {
                            $SPAllowed = @($SPSettings.sharingAllowedDomainList)
                            if ($SPAllowed.Count -gt 0 -and $BlockedDomain -notin $SPAllowed) {
                                $DiagList.Add(@{
                                    source       = 'SharePoint Sharing Settings'
                                    issue        = "Domain '$BlockedDomain' is not in the SharePoint allowed domains list"
                                    detail       = "SharePoint uses a domain allow-list for external sharing. Permitted domains: $($SPAllowed -join ', '). The domain '$BlockedDomain' is not on this list."
                                    fix          = "Add '$BlockedDomain' to the SharePoint sharing allowed domains list."
                                    settingsPage = '/teams-share/sharepoint/sharing-settings'
                                    severity     = 'warning'
                                    currentList  = $SPAllowed
                                    listType     = 'allowList'
                                })
                            }
                        } elseif ($SPSettings.sharingDomainRestrictionMode -eq 'blockList') {
                            $SPBlocked = @($SPSettings.sharingBlockedDomainList)
                            if ($SPBlocked.Count -gt 0 -and $BlockedDomain -in $SPBlocked) {
                                $DiagList.Add(@{
                                    source       = 'SharePoint Sharing Settings'
                                    issue        = "Domain '$BlockedDomain' is blocked in SharePoint sharing settings"
                                    detail       = "The domain '$BlockedDomain' appears in the SharePoint blocked domains list."
                                    fix          = "Remove '$BlockedDomain' from the SharePoint sharing blocked domains list."
                                    settingsPage = '/teams-share/sharepoint/sharing-settings'
                                    severity     = 'warning'
                                    currentList  = $SPBlocked
                                    listType     = 'blockList'
                                })
                            }
                        }
                    } catch {
                        # SharePoint settings may not be accessible
                    }
                }

                # Fallback if no specific cause found
                if ($DiagList.Count -eq 0) {
                    $ContextLabel = if ($Request.Body.TeamID) { 'Teams Settings' } else { 'SharePoint Sharing settings' }
                    $DiagList.Add(@{
                        source       = 'Unknown Policy'
                        issue        = "Could not determine the specific policy blocking domain '$BlockedDomain'"
                        detail       = "The domain '$BlockedDomain' is being blocked by a tenant policy, but the specific restriction could not be identified. This may be caused by a Cross-Tenant Access Policy, Conditional Access policy, or another setting."
                        fix          = "Review External Collaboration settings, $ContextLabel, and Cross-Tenant Access Policies for domain restrictions."
                        settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                        severity     = 'warning'
                    })
                }

                $Body.Diagnostics = @($DiagList)
                $Body.BlockedDomain = $BlockedDomain
            }
        } catch {
            # Diagnostics failed - log but do not affect the error response
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Guest invite diagnostics failed: $($_.Exception.Message)" -Sev 'Debug'
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
