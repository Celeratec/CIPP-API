function Invoke-ExecSharingTroubleshoot {
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
    $TenantFilter = $Request.Body.tenantFilter
    $UserEmail = $Request.Body.userEmail
    $ResourceUrl = $Request.Body.resourceUrl
    $ResourceType = $Request.Body.resourceType ?? 'auto'

    $MSAConsumerTenantId = '9188040d-6c67-4c5b-b112-36a304b66dad'

    if (-not $TenantFilter -or -not $UserEmail) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter and userEmail are required.' }
        })
    }

    try {
        $Domain = ($UserEmail -split '@')[1]
        $Checks = [System.Collections.Generic.List[hashtable]]::new()
        $OverallStatus = 'pass'

        # --- Check 1: Domain type classification ---
        $DomainType = 'unknown'
        $ExternalTenantId = $null
        try {
            $OidcConfig = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$Domain/.well-known/openid-configuration" -Method GET -ErrorAction Stop
            $ResolvedTenantId = ($OidcConfig.issuer -split '/')[3]
            if (-not $ResolvedTenantId -or $ResolvedTenantId -eq $MSAConsumerTenantId) {
                $DomainType = 'consumer'
                $Checks.Add(@{
                    step     = 'Domain Classification'
                    status   = 'info'
                    detail   = "'$Domain' is a personal email domain (consumer account). The user must use Guest Access (B2B Collaboration) and will authenticate via Email One-Time Passcode."
                    category = 'Domain'
                })
            } else {
                $DomainType = 'organizational'
                $ExternalTenantId = $ResolvedTenantId
                $Checks.Add(@{
                    step     = 'Domain Classification'
                    status   = 'pass'
                    detail   = "'$Domain' belongs to Microsoft 365 tenant $ResolvedTenantId. Both Guest Access and External Access are available."
                    category = 'Domain'
                })
            }
        } catch {
            $Checks.Add(@{
                step     = 'Domain Classification'
                status   = 'warning'
                detail   = "Could not resolve '$Domain' via OIDC discovery. This may be a personal email or a domain without Microsoft 365."
                category = 'Domain'
            })
        }

        # --- Check 2: Guest account existence ---
        $GuestUser = $null
        try {
            $EncodedEmail = $UserEmail -replace '#', '%23'
            $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/users?`$filter=mail eq '$EncodedEmail' or userPrincipalName eq '$EncodedEmail'&`$select=id,displayName,userPrincipalName,userType,accountEnabled,externalUserState,signInActivity" -tenantid $TenantFilter -AsApp $true
            $GuestUser = if ($UserLookup -is [array]) { $UserLookup[0] } else { $UserLookup }

            if ($GuestUser) {
                $Checks.Add(@{
                    step     = 'Guest Account Exists'
                    status   = 'pass'
                    detail   = "Found user '$($GuestUser.displayName)' (ID: $($GuestUser.id), Type: $($GuestUser.userType), State: $($GuestUser.externalUserState))."
                    category = 'Identity'
                })
            } else {
                $Checks.Add(@{
                    step     = 'Guest Account Exists'
                    status   = 'fail'
                    detail   = "No user account found for '$UserEmail' in this tenant. The user must be invited as a guest first."
                    fix      = 'Invite the user as a guest using the External Access Wizard or the guest invite dialog on a site/team details page.'
                    category = 'Identity'
                })
                $OverallStatus = 'fail'
            }
        } catch {
            $Checks.Add(@{
                step     = 'Guest Account Exists'
                status   = 'warning'
                detail   = "Could not look up user '$UserEmail'. Check CIPP permissions (User.Read.All)."
                category = 'Identity'
            })
        }

        # --- Check 3: Guest account status ---
        if ($GuestUser) {
            if (-not $GuestUser.accountEnabled) {
                $Checks.Add(@{
                    step     = 'Account Status'
                    status   = 'fail'
                    detail   = "The guest account is DISABLED. The user cannot sign in."
                    fix      = 'Enable the guest account in Identity > Users or via the Edit User page.'
                    category = 'Identity'
                })
                $OverallStatus = 'fail'
            } elseif ($GuestUser.externalUserState -eq 'PendingAcceptance') {
                $Checks.Add(@{
                    step     = 'Account Status'
                    status   = 'warning'
                    detail   = "The guest invitation is still pending acceptance. The user has not yet redeemed their invitation."
                    fix      = 'Ask the user to check their email for the invitation, or re-send the invitation.'
                    category = 'Identity'
                })
                if ($OverallStatus -ne 'fail') { $OverallStatus = 'warning' }
            } else {
                $LastSignIn = $GuestUser.signInActivity.lastSignInDateTime
                $SignInInfo = if ($LastSignIn) { "Last sign-in: $LastSignIn" } else { 'No sign-in recorded' }
                $Checks.Add(@{
                    step     = 'Account Status'
                    status   = 'pass'
                    detail   = "Guest account is enabled and active. $SignInInfo."
                    category = 'Identity'
                })
            }
        }

        # --- Check 4: Entra External Collaboration ---
        try {
            $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

            if ($AuthPolicy.allowInvitesFrom -eq 'none') {
                $Checks.Add(@{
                    step         = 'Guest Invite Policy'
                    status       = 'fail'
                    detail       = 'Guest invitations are completely disabled. No one can invite external users.'
                    fix          = 'Change guest invite restrictions to allow at least admins to invite.'
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                    category     = 'Entra Policy'
                })
                $OverallStatus = 'fail'
            } else {
                $Checks.Add(@{
                    step         = 'Guest Invite Policy'
                    status       = 'pass'
                    detail       = "Guest invite policy: $($AuthPolicy.allowInvitesFrom)."
                    settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                    category     = 'Entra Policy'
                })
            }
        } catch {
            $Checks.Add(@{
                step     = 'Guest Invite Policy'
                status   = 'warning'
                detail   = 'Could not retrieve Entra authorization policy.'
                category = 'Entra Policy'
            })
        }

        # --- Check 5: Entra B2B domain restrictions ---
        try {
            $B2BPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
            $B2BManagement = $B2BPolicy | Where-Object { $_.type -eq 6 }
            if ($B2BManagement) {
                $B2BDefinition = ($B2BManagement.definition | ConvertFrom-Json).B2BManagementPolicy
                $DomainPolicy = $B2BDefinition.InvitationsAllowedAndBlockedDomainsPolicy
                $DomainBlocked = $false

                if ($DomainPolicy.AllowedDomains -and $DomainPolicy.AllowedDomains.Count -gt 0 -and $Domain -notin $DomainPolicy.AllowedDomains) {
                    $Checks.Add(@{
                        step         = 'Entra Domain Restrictions'
                        status       = 'fail'
                        detail       = "Domain '$Domain' is NOT in the Entra allowed domains list. Allowed: $($DomainPolicy.AllowedDomains -join ', ')."
                        fix          = "Add '$Domain' to the allowed domains list in External Collaboration settings."
                        settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                        category     = 'Entra Policy'
                    })
                    $OverallStatus = 'fail'
                    $DomainBlocked = $true
                }

                if ($DomainPolicy.BlockedDomains -and $DomainPolicy.BlockedDomains.Count -gt 0 -and $Domain -in $DomainPolicy.BlockedDomains) {
                    $Checks.Add(@{
                        step         = 'Entra Domain Restrictions'
                        status       = 'fail'
                        detail       = "Domain '$Domain' is explicitly BLOCKED for guest invitations."
                        fix          = "Remove '$Domain' from the blocked domains list."
                        settingsPage = '/tenant/administration/cross-tenant-access/external-collaboration'
                        category     = 'Entra Policy'
                    })
                    $OverallStatus = 'fail'
                    $DomainBlocked = $true
                }

                if (-not $DomainBlocked) {
                    $Checks.Add(@{
                        step     = 'Entra Domain Restrictions'
                        status   = 'pass'
                        detail   = "Domain '$Domain' is permitted by Entra B2B domain policies."
                        category = 'Entra Policy'
                    })
                }
            } else {
                $Checks.Add(@{
                    step     = 'Entra Domain Restrictions'
                    status   = 'pass'
                    detail   = 'No B2B domain restrictions configured. All domains are permitted.'
                    category = 'Entra Policy'
                })
            }
        } catch {
            $Checks.Add(@{
                step     = 'Entra Domain Restrictions'
                status   = 'warning'
                detail   = 'Could not retrieve B2B management policy.'
                category = 'Entra Policy'
            })
        }

        # --- Check 6: Email OTP ---
        if ($DomainType -eq 'consumer') {
            try {
                $EmailOTPPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/email' -tenantid $TenantFilter -AsApp $true
                if ($EmailOTPPolicy.state -ne 'enabled') {
                    $Checks.Add(@{
                        step     = 'Email OTP Authentication'
                        status   = 'fail'
                        detail   = "Email OTP is NOT enabled. Personal email users ('$Domain') cannot authenticate without it."
                        fix      = 'Enable Email One-Time Passcode in Authentication Methods.'
                        category = 'Authentication'
                    })
                    $OverallStatus = 'fail'
                } else {
                    $Checks.Add(@{
                        step     = 'Email OTP Authentication'
                        status   = 'pass'
                        detail   = 'Email OTP is enabled. Personal email guests can authenticate.'
                        category = 'Authentication'
                    })
                }
            } catch {
                $Checks.Add(@{
                    step     = 'Email OTP Authentication'
                    status   = 'warning'
                    detail   = 'Could not check Email OTP policy.'
                    category = 'Authentication'
                })
            }
        }

        # --- Check 7: SharePoint sharing settings ---
        if ($ResourceType -in @('sharepoint', 'auto')) {
            try {
                $SPSettings = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -tenantid $TenantFilter -AsApp $true

                if ($SPSettings.sharingCapability -eq 'disabled') {
                    $Checks.Add(@{
                        step         = 'SharePoint External Sharing'
                        status       = 'fail'
                        detail       = 'SharePoint external sharing is DISABLED. No external users can access SharePoint content.'
                        fix          = "Set sharing to at least 'Existing guests' or 'New and existing guests'."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                        category     = 'SharePoint'
                    })
                    $OverallStatus = 'fail'
                } elseif ($SPSettings.sharingCapability -eq 'existingExternalUserSharingOnly' -and -not $GuestUser) {
                    $Checks.Add(@{
                        step         = 'SharePoint External Sharing'
                        status       = 'fail'
                        detail       = "SharePoint is set to 'Existing guests' only, but this user is not yet a guest. Invite the user first."
                        fix          = "Invite the user as a guest, or change sharing to 'New and existing guests'."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                        category     = 'SharePoint'
                    })
                    $OverallStatus = 'fail'
                } else {
                    $Checks.Add(@{
                        step         = 'SharePoint External Sharing'
                        status       = 'pass'
                        detail       = "SharePoint sharing: $($SPSettings.sharingCapability)."
                        settingsPage = '/teams-share/sharepoint/sharing-settings'
                        category     = 'SharePoint'
                    })
                }

                if ($SPSettings.sharingDomainRestrictionMode -eq 'allowList') {
                    $SPAllowed = @($SPSettings.sharingAllowedDomainList)
                    if ($SPAllowed.Count -gt 0 -and $Domain -notin $SPAllowed) {
                        $Checks.Add(@{
                            step         = 'SharePoint Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is NOT in the SharePoint allowed list. Allowed: $($SPAllowed -join ', ')."
                            fix          = "Add '$Domain' to the SharePoint sharing allowed domains."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            category     = 'SharePoint'
                        })
                        $OverallStatus = 'fail'
                    } else {
                        $Checks.Add(@{
                            step     = 'SharePoint Domain Restrictions'
                            status   = 'pass'
                            detail   = "Domain '$Domain' is allowed in SharePoint sharing."
                            category = 'SharePoint'
                        })
                    }
                } elseif ($SPSettings.sharingDomainRestrictionMode -eq 'blockList') {
                    $SPBlocked = @($SPSettings.sharingBlockedDomainList)
                    if ($SPBlocked.Count -gt 0 -and $Domain -in $SPBlocked) {
                        $Checks.Add(@{
                            step         = 'SharePoint Domain Restrictions'
                            status       = 'fail'
                            detail       = "Domain '$Domain' is BLOCKED in SharePoint sharing."
                            fix          = "Remove '$Domain' from the blocked list."
                            settingsPage = '/teams-share/sharepoint/sharing-settings'
                            category     = 'SharePoint'
                        })
                        $OverallStatus = 'fail'
                    }
                }
            } catch {
                $Checks.Add(@{
                    step     = 'SharePoint External Sharing'
                    status   = 'warning'
                    detail   = 'Could not retrieve SharePoint settings.'
                    category = 'SharePoint'
                })
            }
        }

        # --- Check 8: Teams guest access ---
        if ($ResourceType -in @('teams', 'auto')) {
            try {
                $TeamsConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsClientConfiguration' -CmdParams @{Identity = 'Global' }
                if ($TeamsConfig.AllowGuestUser -eq $false) {
                    $Checks.Add(@{
                        step         = 'Teams Guest Access'
                        status       = 'fail'
                        detail       = 'Guest access is DISABLED for Teams. Guests cannot join any teams.'
                        fix          = "Enable 'Allow guest access' in Teams Settings."
                        settingsPage = '/teams-share/teams/teams-settings'
                        category     = 'Teams'
                    })
                    $OverallStatus = 'fail'
                } else {
                    $Checks.Add(@{
                        step     = 'Teams Guest Access'
                        status   = 'pass'
                        detail   = 'Teams guest access is enabled.'
                        category = 'Teams'
                    })
                }
            } catch {
                $Checks.Add(@{
                    step     = 'Teams Guest Access'
                    status   = 'warning'
                    detail   = 'Could not retrieve Teams settings.'
                    category = 'Teams'
                })
            }
        }

        # --- Check 9: Cross-tenant access (for organizational domains + shared channels) ---
        if ($DomainType -eq 'organizational' -and $ExternalTenantId) {
            try {
                $DefaultCTA = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -tenantid $TenantFilter -AsApp $true
                $DefaultB2BCollab = $DefaultCTA.b2bCollaborationInbound
                $CollabBlocked = ($DefaultB2BCollab.usersAndGroups.accessType -eq 'blocked' -and ($DefaultB2BCollab.usersAndGroups.targets | Where-Object { $_.target -eq 'AllUsers' }))

                $PartnerPolicy = $null
                try {
                    $PartnerPolicy = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners/$ExternalTenantId" -tenantid $TenantFilter -AsApp $true
                } catch { }

                if ($PartnerPolicy) {
                    $PartnerCollab = $PartnerPolicy.b2bCollaborationInbound
                    $InheritDefault = -not $PartnerCollab -or ($null -eq $PartnerCollab.usersAndGroups)
                    if ($InheritDefault -and $CollabBlocked) {
                        $Checks.Add(@{
                            step         = 'Cross-Tenant B2B Collaboration'
                            status       = 'fail'
                            detail       = "Partner policy for '$Domain' inherits defaults which block B2B collaboration inbound."
                            fix          = 'Set B2B collaboration inbound to Allow on the partner policy.'
                            settingsPage = "/tenant/administration/cross-tenant-access/partners/partner?tenantId=$ExternalTenantId"
                            category     = 'Cross-Tenant'
                        })
                        $OverallStatus = 'fail'
                    } else {
                        $Checks.Add(@{
                            step     = 'Cross-Tenant B2B Collaboration'
                            status   = 'pass'
                            detail   = "B2B collaboration inbound is allowed for '$Domain'."
                            category = 'Cross-Tenant'
                        })
                    }
                } elseif ($CollabBlocked) {
                    $Checks.Add(@{
                        step         = 'Cross-Tenant B2B Collaboration'
                        status       = 'fail'
                        detail       = "No partner policy for '$Domain' and defaults block B2B collaboration inbound."
                        fix          = "Create a partner policy for '$Domain' with B2B collaboration inbound allowed."
                        settingsPage = '/tenant/administration/cross-tenant-access/partners'
                        category     = 'Cross-Tenant'
                    })
                    $OverallStatus = 'fail'
                } else {
                    $Checks.Add(@{
                        step     = 'Cross-Tenant B2B Collaboration'
                        status   = 'pass'
                        detail   = 'Default policy allows B2B collaboration inbound.'
                        category = 'Cross-Tenant'
                    })
                }
            } catch {
                $Checks.Add(@{
                    step     = 'Cross-Tenant B2B Collaboration'
                    status   = 'warning'
                    detail   = 'Could not retrieve cross-tenant access policies.'
                    category = 'Cross-Tenant'
                })
            }
        }

        # --- Check 10: Site-level membership (if resource URL provided) ---
        if ($ResourceUrl -and $GuestUser) {
            try {
                $SiteId = $null
                if ($ResourceUrl -match 'sites/([^/]+)') {
                    $SitePath = $Matches[1]
                    $SiteInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/root:/$SitePath" -tenantid $TenantFilter -AsApp $true
                    $SiteId = $SiteInfo.id
                }

                if ($SiteId) {
                    $SiteMembers = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/permissions" -tenantid $TenantFilter -AsApp $true
                    $IsMember = $SiteMembers | Where-Object {
                        $_.grantedToIdentitiesV2 | Where-Object {
                            $_.user.id -eq $GuestUser.id
                        }
                    }

                    if ($IsMember) {
                        $Checks.Add(@{
                            step     = 'Site Membership'
                            status   = 'pass'
                            detail   = "The guest has permissions on this site."
                            category = 'Resource Access'
                        })
                    } else {
                        $Checks.Add(@{
                            step     = 'Site Membership'
                            status   = 'fail'
                            detail   = "The guest does not have permissions on this site. They need to be added as a member."
                            fix      = 'Add the guest as a site member from the site details page.'
                            category = 'Resource Access'
                        })
                        if ($OverallStatus -ne 'fail') { $OverallStatus = 'warning' }
                    }
                }
            } catch {
                $Checks.Add(@{
                    step     = 'Site Membership'
                    status   = 'warning'
                    detail   = 'Could not check site-level membership. The user may need to be added manually.'
                    category = 'Resource Access'
                })
            }
        }

        $FailCount = ($Checks | Where-Object { $_.status -eq 'fail' }).Count
        $WarnCount = ($Checks | Where-Object { $_.status -eq 'warning' }).Count
        $PassCount = ($Checks | Where-Object { $_.status -eq 'pass' }).Count

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Sharing troubleshoot for '$UserEmail': $PassCount pass, $FailCount fail, $WarnCount warning" -Sev 'Info'

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results = @{
                email         = $UserEmail
                domain        = $Domain
                domainType    = $DomainType
                overallStatus = $OverallStatus
                checks        = @($Checks)
                summary       = @{
                    totalChecks = $Checks.Count
                    passed      = $PassCount
                    failed      = $FailCount
                    warnings    = $WarnCount
                }
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Sharing troubleshoot failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Sharing troubleshoot failed: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
