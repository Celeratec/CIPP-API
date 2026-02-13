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

        # Step 2: Add guest to the SharePoint site group (for Group-connected sites)
        if ($Request.Body.SharePointType -eq 'Group' -and $Request.Body.groupId -and $GuestUserId) {
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
            $ResultMessages.Add("Guest invited to tenant. Non-group sites require manual permission assignment in SharePoint.")
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($ResultMessages -join ' ') -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = @($ResultMessages) }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ResultMessages = [System.Collections.Generic.List[string]]::new()
        $ResultMessages.Add("Failed to invite guest. $($ErrorMessage.NormalizedError)")
        $Diagnostics = $null
        $BlockedDomain = $null

        # Detect domain collaboration errors and run diagnostics
        $IsDomainError = ($ErrorMessage.NormalizedError -like '*does not allow collaboration*') -or
                         ($ErrorMessage.NormalizedError -like '*collaboration with the domain*') -or
                         ($ErrorMessage.Message -like '*does not allow collaboration*') -or
                         ($ErrorMessage.Message -like '*collaboration with the domain*')

        if ($IsDomainError -and $Request.Body.mail) {
            $BlockedDomain = ($Request.Body.mail -split '@')[1]
            $Diagnostics = [System.Collections.Generic.List[object]]::new()

            # --- Check Entra External Collaboration settings ---
            try {
                $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

                # Check if invitations are disabled entirely
                if ($AuthPolicy.allowInvitesFrom -eq 'none') {
                    $Diagnostics.Add([PSCustomObject]@{
                        source       = 'Entra External Collaboration'
                        issue        = 'Guest invitations are completely disabled'
                        detail       = "The 'Guest invite restrictions' setting is set to 'No one in the organization can invite guest users including admins (most restrictive)'. All guest invitations will be blocked regardless of domain."
                        fix          = "Change the guest invite restrictions to allow at least admins and users in the Guest Inviter role to send invitations."
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
                                $Diagnostics.Add([PSCustomObject]@{
                                    source       = 'Entra External Collaboration'
                                    issue        = "Domain '$BlockedDomain' is not in the allowed domains list"
                                    detail       = "The tenant uses a domain allow-list for guest invitations. Only users from these domains can be invited: $($DomainPolicy.AllowedDomains -join ', '). The domain '$BlockedDomain' is not on this list."
                                    fix          = "Add '$BlockedDomain' to the allowed domains list in External Collaboration settings, or switch to a block-list approach instead."
                                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                                    severity     = 'error'
                                    currentList  = @($DomainPolicy.AllowedDomains)
                                    listType     = 'allowList'
                                })
                            }
                        }

                        if ($DomainPolicy.BlockedDomains -and $DomainPolicy.BlockedDomains.Count -gt 0) {
                            if ($BlockedDomain -in $DomainPolicy.BlockedDomains) {
                                $Diagnostics.Add([PSCustomObject]@{
                                    source       = 'Entra External Collaboration'
                                    issue        = "Domain '$BlockedDomain' is explicitly blocked"
                                    detail       = "The domain '$BlockedDomain' appears in the blocked domains list for guest invitations. Users from this domain cannot be invited."
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
                    # B2B management policy may not be available in all tenants - non-critical
                }
            } catch {
                $ResultMessages.Add('Could not retrieve Entra External Collaboration settings for diagnosis.')
            }

            # --- Check SharePoint sharing settings ---
            try {
                $SPSettings = New-GraphGetRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true

                if ($SPSettings.sharingCapability -eq 'disabled') {
                    $Diagnostics.Add([PSCustomObject]@{
                        source       = 'SharePoint Sharing Settings'
                        issue        = 'External sharing is completely disabled for SharePoint'
                        detail       = "SharePoint external sharing is set to 'Only people in your organization'. No external guests can access any SharePoint content."
                        fix          = "Enable external sharing in SharePoint Sharing Settings. At minimum, set it to 'Existing guests' or 'New and existing guests'."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                        severity     = 'error'
                    })
                }

                if ($SPSettings.sharingDomainRestrictionMode -eq 'allowList') {
                    $SPAllowed = $SPSettings.sharingAllowedDomainList
                    if ($SPAllowed -and ($BlockedDomain -notin $SPAllowed)) {
                        $Diagnostics.Add([PSCustomObject]@{
                            source       = 'SharePoint Sharing Settings'
                            issue        = "Domain '$BlockedDomain' is not in the SharePoint allowed domains list"
                            detail       = "SharePoint uses a domain allow-list for external sharing. Only these domains are permitted: $($SPAllowed -join ', '). The domain '$BlockedDomain' is not on this list."
                            fix          = "Add '$BlockedDomain' to the SharePoint sharing allowed domains list."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            severity     = 'warning'
                            currentList  = @($SPAllowed)
                            listType     = 'allowList'
                        })
                    }
                } elseif ($SPSettings.sharingDomainRestrictionMode -eq 'blockList') {
                    $SPBlocked = $SPSettings.sharingBlockedDomainList
                    if ($SPBlocked -and ($BlockedDomain -in $SPBlocked)) {
                        $Diagnostics.Add([PSCustomObject]@{
                            source       = 'SharePoint Sharing Settings'
                            issue        = "Domain '$BlockedDomain' is blocked in SharePoint sharing settings"
                            detail       = "The domain '$BlockedDomain' appears in the SharePoint blocked domains list for external sharing."
                            fix          = "Remove '$BlockedDomain' from the SharePoint sharing blocked domains list."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            severity     = 'warning'
                            currentList  = @($SPBlocked)
                            listType     = 'blockList'
                        })
                    }
                }
            } catch {
                # Non-critical - SharePoint settings may not be accessible
            }

            # If we couldn't determine the specific cause, provide general guidance
            if ($Diagnostics.Count -eq 0) {
                $Diagnostics.Add([PSCustomObject]@{
                    source       = 'Unknown Policy'
                    issue        = "Could not determine the specific policy blocking domain '$BlockedDomain'"
                    detail       = "The domain '$BlockedDomain' is being blocked by a tenant policy, but the specific restriction could not be identified. This may be caused by a Cross-Tenant Access Policy, Conditional Access policy, or a setting not visible to this diagnostic check."
                    fix          = "Review External Collaboration settings, SharePoint Sharing settings, and Cross-Tenant Access Policies for domain restrictions."
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                    severity     = 'warning'
                })
            }
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResultMessages[0] -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{ Results = @($ResultMessages) }
        if ($Diagnostics) {
            $Body.Diagnostics = @($Diagnostics)
            $Body.BlockedDomain = $BlockedDomain
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
