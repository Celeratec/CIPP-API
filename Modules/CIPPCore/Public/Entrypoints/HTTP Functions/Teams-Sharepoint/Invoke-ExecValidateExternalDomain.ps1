function Invoke-ExecValidateExternalDomain {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter ?? $Request.Query.tenantFilter
    $Email = $Request.Body.email ?? $Request.Query.email
    $Context = $Request.Body.context ?? $Request.Query.context ?? 'general'

    $MSAConsumerTenantId = '9188040d-6c67-4c5b-b112-36a304b66dad'

    if (-not $TenantFilter -or -not $Email) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter and email are required.' }
        })
    }

    try {
        $Domain = ($Email -split '@')[1]
        if (-not $Domain) {
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'Invalid email address format.' }
            })
        }

        $Result = @{
            email                = $Email
            domain               = $Domain
            domainType           = 'unknown'
            externalTenantId     = $null
            existingGuest        = $null
            recommendedAccessType   = 'guest'
            recommendedAccessReason = ''
            supportedContexts    = @()
            unsupportedContexts  = @()
            policyChecks         = [System.Collections.Generic.List[hashtable]]::new()
            canProceed           = $true
        }

        # --- Domain type classification via OIDC discovery ---
        try {
            $OidcConfig = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$Domain/.well-known/openid-configuration" -Method GET -ErrorAction Stop
            $ResolvedTenantId = ($OidcConfig.issuer -split '/')[3]

            if (-not $ResolvedTenantId -or $ResolvedTenantId -eq $MSAConsumerTenantId) {
                $Result.domainType = 'consumer'
                $Result.externalTenantId = $null
                $Result.recommendedAccessType = 'guest'
                $Result.recommendedAccessReason = "'$Domain' is a personal email domain (consumer account). Guest Access (B2B Collaboration) is the only option. The guest will authenticate via Email One-Time Passcode."
                $Result.supportedContexts = @('sharepoint', 'teams-standard', 'teams-private')
                $Result.unsupportedContexts = @(@{
                    context = 'teams-shared'
                    reason  = "Shared channels use External Access (B2B Direct Connect) which requires a work or school account from another Microsoft 365 organization. Personal email addresses like '$Domain' are not supported. Use a standard or private channel instead."
                })
            } else {
                $Result.domainType = 'organizational'
                $Result.externalTenantId = $ResolvedTenantId
                $Result.recommendedAccessType = if ($Context -eq 'teams-shared') { 'external' } else { 'guest' }
                $Result.recommendedAccessReason = "'$Domain' belongs to Microsoft 365 tenant $ResolvedTenantId. Both Guest Access (B2B Collaboration) and External Access (B2B Direct Connect) are available depending on the target resource."
                $Result.supportedContexts = @('sharepoint', 'teams-standard', 'teams-private', 'teams-shared')
                $Result.unsupportedContexts = @()
            }
        } catch {
            $Result.domainType = 'unresolvable'
            $Result.recommendedAccessType = 'guest'
            $Result.recommendedAccessReason = "Could not resolve '$Domain' via OIDC discovery. This may be a personal email domain or a domain without a Microsoft 365 tenant. Try Guest Access (B2B Collaboration)."
            $Result.supportedContexts = @('sharepoint', 'teams-standard', 'teams-private')
            $Result.unsupportedContexts = @(@{
                context = 'teams-shared'
                reason  = "Cannot verify that '$Domain' has a Microsoft 365 tenant. Shared channels require B2B Direct Connect with a verified organizational domain."
            })
        }

        # --- Check for existing guest user ---
        try {
            $EncodedEmail = $Email -replace '#', '%23'
            $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=mail eq '$EncodedEmail' or userPrincipalName eq '$EncodedEmail'&`$select=id,displayName,userPrincipalName,userType,accountEnabled,externalUserState,signInActivity" -tenantid $TenantFilter -AsApp $true
            $ResolvedUser = if ($UserLookup -is [array]) { $UserLookup[0] } else { $UserLookup }

            if ($ResolvedUser) {
                $Result.existingGuest = @{
                    id                = $ResolvedUser.id
                    displayName       = $ResolvedUser.displayName
                    upn               = $ResolvedUser.userPrincipalName
                    userType          = $ResolvedUser.userType
                    accountEnabled    = $ResolvedUser.accountEnabled
                    externalUserState = $ResolvedUser.externalUserState
                    lastSignIn        = $ResolvedUser.signInActivity.lastSignInDateTime
                }
            }
        } catch {
            # Non-critical — user lookup may fail for permission reasons
        }

        # --- Entra External Collaboration: invite restrictions ---
        try {
            $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

            if ($AuthPolicy.allowInvitesFrom -eq 'none') {
                $Result.policyChecks.Add(@{
                    source       = 'Entra External Collaboration'
                    status       = 'fail'
                    detail       = 'Guest invitations are completely disabled. No one in the organization can invite guest users.'
                    fix          = 'Change guest invite restrictions to allow at least admins and the Guest Inviter role to send invitations.'
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                })
                $Result.canProceed = $false
            } elseif ($AuthPolicy.allowInvitesFrom -eq 'everyone') {
                $Result.policyChecks.Add(@{
                    source       = 'Entra External Collaboration'
                    status       = 'warning'
                    detail       = 'Anyone in the organization (including existing guests) can invite guest users. Consider restricting to admins or the Guest Inviter role.'
                    fix          = 'Restrict guest invite permissions for better security.'
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                })
            } else {
                $Result.policyChecks.Add(@{
                    source       = 'Entra External Collaboration'
                    status       = 'pass'
                    detail       = "Guest invite restrictions: $($AuthPolicy.allowInvitesFrom)"
                    fix          = $null
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                })
            }
        } catch {
            $Result.policyChecks.Add(@{
                source       = 'Entra External Collaboration'
                status       = 'warning'
                detail       = 'Could not retrieve authorization policy. Check CIPP permissions.'
                fix          = 'Ensure CIPP has Policy.Read.All permission.'
                settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
            })
        }

        # --- Entra B2B domain allow/block lists ---
        try {
            $B2BPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
            $B2BManagement = $B2BPolicy | Where-Object { $_.type -eq 6 }
            if ($B2BManagement) {
                $B2BDefinition = ($B2BManagement.definition | ConvertFrom-Json).B2BManagementPolicy
                $DomainPolicy = $B2BDefinition.InvitationsAllowedAndBlockedDomainsPolicy

                if ($DomainPolicy.AllowedDomains -and $DomainPolicy.AllowedDomains.Count -gt 0) {
                    if ($Domain -notin $DomainPolicy.AllowedDomains) {
                        $Result.policyChecks.Add(@{
                            source       = 'Entra Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is not in the Entra allowed domains list. Allowed: $($DomainPolicy.AllowedDomains -join ', ')."
                            fix          = "Add '$Domain' to the allowed domains list or switch to a block-list approach."
                            settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                            currentList  = @($DomainPolicy.AllowedDomains)
                            listType     = 'allowList'
                        })
                        $Result.canProceed = $false
                    } else {
                        $Result.policyChecks.Add(@{
                            source       = 'Entra Domain Restrictions'
                            status       = 'pass'
                            detail       = "Domain '$Domain' is in the allowed domains list."
                            fix          = $null
                            settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                        })
                    }
                }

                if ($DomainPolicy.BlockedDomains -and $DomainPolicy.BlockedDomains.Count -gt 0) {
                    if ($Domain -in $DomainPolicy.BlockedDomains) {
                        $Result.policyChecks.Add(@{
                            source       = 'Entra Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is explicitly blocked for guest invitations."
                            fix          = "Remove '$Domain' from the blocked domains list."
                            settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                            currentList  = @($DomainPolicy.BlockedDomains)
                            listType     = 'blockList'
                        })
                        $Result.canProceed = $false
                    }
                }
            } else {
                $Result.policyChecks.Add(@{
                    source       = 'Entra Domain Restrictions'
                    status       = 'pass'
                    detail       = 'No B2B domain allow-list or block-list configured. All domains are permitted for guest invitations.'
                    fix          = $null
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                })
            }
        } catch {
            # Non-critical
        }

        # --- SharePoint sharing settings ---
        if ($Context -in @('sharepoint', 'general')) {
            try {
                $SPSettings = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -tenantid $TenantFilter -AsApp $true

                if ($SPSettings.sharingCapability -eq 'disabled') {
                    $Result.policyChecks.Add(@{
                        source       = 'SharePoint Sharing'
                        status       = 'fail'
                        detail       = 'SharePoint external sharing is completely disabled. No external users can access SharePoint content.'
                        fix          = "Set sharing level to at least 'Existing guests' or 'New and existing guests'."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                    })
                    if ($Context -eq 'sharepoint') { $Result.canProceed = $false }
                } elseif ($SPSettings.sharingCapability -eq 'existingExternalUserSharingOnly' -and -not $Result.existingGuest) {
                    $Result.policyChecks.Add(@{
                        source       = 'SharePoint Sharing'
                        status       = 'warning'
                        detail       = "SharePoint sharing is set to 'Existing guests' only, and this user is not yet a guest in the tenant. The user must be invited first, then granted SharePoint access."
                        fix          = "Invite the user as a guest first, or change sharing to 'New and existing guests'."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                    })
                } else {
                    $Result.policyChecks.Add(@{
                        source       = 'SharePoint Sharing'
                        status       = 'pass'
                        detail       = "SharePoint sharing capability: $($SPSettings.sharingCapability)"
                        fix          = $null
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                    })
                }

                if ($SPSettings.sharingDomainRestrictionMode -eq 'allowList') {
                    $SPAllowed = @($SPSettings.sharingAllowedDomainList)
                    if ($SPAllowed.Count -gt 0 -and $Domain -notin $SPAllowed) {
                        $Result.policyChecks.Add(@{
                            source       = 'SharePoint Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is not in the SharePoint allowed domains list. Allowed: $($SPAllowed -join ', ')."
                            fix          = "Add '$Domain' to the SharePoint sharing allowed domains list."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            currentList  = $SPAllowed
                            listType     = 'allowList'
                        })
                        if ($Context -eq 'sharepoint') { $Result.canProceed = $false }
                    }
                } elseif ($SPSettings.sharingDomainRestrictionMode -eq 'blockList') {
                    $SPBlocked = @($SPSettings.sharingBlockedDomainList)
                    if ($SPBlocked.Count -gt 0 -and $Domain -in $SPBlocked) {
                        $Result.policyChecks.Add(@{
                            source       = 'SharePoint Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is blocked in SharePoint sharing settings."
                            fix          = "Remove '$Domain' from the SharePoint blocked domains list."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            currentList  = $SPBlocked
                            listType     = 'blockList'
                        })
                        if ($Context -eq 'sharepoint') { $Result.canProceed = $false }
                    }
                }
            } catch {
                $Result.policyChecks.Add(@{
                    source       = 'SharePoint Sharing'
                    status       = 'warning'
                    detail       = 'Could not retrieve SharePoint settings.'
                    fix          = 'Check CIPP permissions for SharePoint admin access.'
                    settingsPage = '/teams-share/sharepoint/sharing-settings'
                })
            }
        }

        # --- Teams guest access ---
        if ($Context -in @('teams-standard', 'teams-private', 'teams-shared', 'general')) {
            try {
                $ClientConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsClientConfiguration' -CmdParams @{Identity = 'Global' }
                if ($ClientConfig.AllowGuestUser -eq $false) {
                    $Result.policyChecks.Add(@{
                        source       = 'Teams Guest Access'
                        status       = 'fail'
                        detail       = 'Guest access is disabled for Microsoft Teams. Guests cannot be added to any teams.'
                        fix          = "Enable 'Allow guest access' in Teams Settings."
                        settingsPage = '/teams-share/teams/teams-settings'
                    })
                    if ($Context -like 'teams-*') { $Result.canProceed = $false }
                } else {
                    $Result.policyChecks.Add(@{
                        source       = 'Teams Guest Access'
                        status       = 'pass'
                        detail       = 'Teams guest access is enabled.'
                        fix          = $null
                        settingsPage = '/teams-share/teams/teams-settings'
                    })
                }
            } catch {
                $Result.policyChecks.Add(@{
                    source       = 'Teams Guest Access'
                    status       = 'warning'
                    detail       = 'Could not retrieve Teams settings.'
                    fix          = 'Check CIPP permissions for Teams administration.'
                    settingsPage = '/teams-share/teams/teams-settings'
                })
            }
        }

        # --- Cross-tenant access policies (for shared channels / organizational domains) ---
        if ($Result.domainType -eq 'organizational' -and $Context -in @('teams-shared', 'general')) {
            try {
                $DefaultCTA = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -tenantid $TenantFilter -AsApp $true

                $DefaultB2BDirect = $DefaultCTA.b2bDirectConnectInbound
                $DefaultBlocked = ($DefaultB2BDirect.applications.accessType -eq 'blocked' -and ($DefaultB2BDirect.applications.targets | Where-Object { $_.target -eq 'AllApplications' })) -or
                    ($DefaultB2BDirect.usersAndGroups.accessType -eq 'blocked' -and ($DefaultB2BDirect.usersAndGroups.targets | Where-Object { $_.target -eq 'AllUsers' }))

                $PartnerPolicy = $null
                if ($Result.externalTenantId) {
                    try {
                        $PartnerPolicy = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners/$($Result.externalTenantId)" -tenantid $TenantFilter -AsApp $true
                    } catch {
                        # No partner-specific policy
                    }
                }

                if ($PartnerPolicy) {
                    $PartnerB2BDirect = $PartnerPolicy.b2bDirectConnectInbound
                    $InheritDefault = -not $PartnerB2BDirect -or ($null -eq $PartnerB2BDirect.applications -and $null -eq $PartnerB2BDirect.usersAndGroups)
                    $PartnerBlocked = ($PartnerB2BDirect.applications.accessType -eq 'blocked') -or ($PartnerB2BDirect.usersAndGroups.accessType -eq 'blocked')

                    if ($InheritDefault -and $DefaultBlocked) {
                        $Result.policyChecks.Add(@{
                            source       = 'Cross-Tenant Access Policy'
                            status       = 'fail'
                            detail       = "Partner policy for '$Domain' inherits from default, which blocks B2B Direct Connect inbound. Shared channels will not work."
                            fix          = "Set B2B Direct Connect inbound to 'Allow' on the partner policy for '$Domain'."
                            settingsPage = "/tenant/administration/cross-tenant-access/partners/partner?tenantId=$($Result.externalTenantId)"
                        })
                        if ($Context -eq 'teams-shared') { $Result.canProceed = $false }
                    } elseif (-not $InheritDefault -and $PartnerBlocked) {
                        $Result.policyChecks.Add(@{
                            source       = 'Cross-Tenant Access Policy'
                            status       = 'fail'
                            detail       = "Partner policy for '$Domain' explicitly blocks B2B Direct Connect inbound."
                            fix          = "Change B2B Direct Connect inbound to 'Allow' on the partner policy."
                            settingsPage = "/tenant/administration/cross-tenant-access/partners/partner?tenantId=$($Result.externalTenantId)"
                        })
                        if ($Context -eq 'teams-shared') { $Result.canProceed = $false }
                    } else {
                        $Result.policyChecks.Add(@{
                            source       = 'Cross-Tenant Access Policy'
                            status       = 'pass'
                            detail       = "B2B Direct Connect inbound is allowed for '$Domain'. Note: the external tenant must also allow outbound B2B Direct Connect."
                            fix          = $null
                            settingsPage = "/tenant/administration/cross-tenant-access/partners/partner?tenantId=$($Result.externalTenantId)"
                        })
                    }
                } elseif ($DefaultBlocked) {
                    $Result.policyChecks.Add(@{
                        source       = 'Cross-Tenant Access Policy'
                        status       = 'fail'
                        detail       = "No partner policy exists for '$Domain' and the default policy blocks B2B Direct Connect inbound."
                        fix          = "Create a partner policy for '$Domain' with B2B Direct Connect inbound set to 'Allow'."
                        settingsPage = '/tenant/administration/cross-tenant-access/partners'
                    })
                    if ($Context -eq 'teams-shared') { $Result.canProceed = $false }
                } else {
                    $Result.policyChecks.Add(@{
                        source       = 'Cross-Tenant Access Policy'
                        status       = 'pass'
                        detail       = "Default policy allows B2B Direct Connect inbound. Note: the external tenant must also allow outbound."
                        fix          = $null
                        settingsPage = '/tenant/administration/cross-tenant-access/policy'
                    })
                }
            } catch {
                $Result.policyChecks.Add(@{
                    source       = 'Cross-Tenant Access Policy'
                    status       = 'warning'
                    detail       = 'Could not retrieve cross-tenant access policies.'
                    fix          = 'Ensure CIPP has Policy.Read.All permission.'
                    settingsPage = '/tenant/administration/cross-tenant-access/policy'
                })
            }
        }

        # --- Context-specific validation ---
        if ($Context -eq 'teams-shared' -and $Result.domainType -eq 'consumer') {
            $Result.canProceed = $false
        }

        $Result.policyChecks = @($Result.policyChecks)

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Validated external domain '$Domain' (type: $($Result.domainType)) for context '$Context'" -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Domain validation failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Domain validation failed: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
