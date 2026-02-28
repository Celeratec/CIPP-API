Function Invoke-ExecTeamAction {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.TenantFilter
    $TeamID = $Request.Body.TeamID
    $Action = $Request.Body.Action
    $DisplayName = $Request.Body.DisplayName

    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }
    if (-not $TeamID) { $TeamID = $Request.Query.TeamID }

    $TeamLabel = if ($DisplayName) { $DisplayName } else { $TeamID }

    try {
        switch ($Action) {
            'Archive' {
                $Body = @{
                    shouldSetSpoSiteReadOnlyForMembers = $false
                } | ConvertTo-Json
                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/archive" -tenantid $TenantFilter -type POST -body $Body
                $Message = "Successfully archived team '$TeamLabel'"
            }
            'Unarchive' {
                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/unarchive" -tenantid $TenantFilter -type POST -body '{}'
                $Message = "Successfully unarchived team '$TeamLabel'"
            }
            'Clone' {
                $CloneDisplayName = $Request.Body.CloneDisplayName
                $CloneVisibility = $Request.Body.CloneVisibility
                if (-not $CloneDisplayName) { $CloneDisplayName = "$TeamLabel (Copy)" }
                if (-not $CloneVisibility) { $CloneVisibility = 'public' }

                $Body = @{
                    displayName  = $CloneDisplayName
                    description  = $Request.Body.CloneDescription
                    mailNickname = ($CloneDisplayName -replace '[^a-zA-Z0-9]', '').ToLower()
                    partsToClone = 'apps,tabs,settings,channels'
                    visibility   = $CloneVisibility
                } | ConvertTo-Json
                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/clone" -tenantid $TenantFilter -type POST -body $Body
                $Message = "Successfully started cloning team '$TeamLabel' as '$CloneDisplayName'. This may take a few minutes to complete."
            }
            'CreateChannel' {
                $ChannelName = $Request.Body.ChannelName
                $ChannelDescription = $Request.Body.ChannelDescription
                $ChannelType = $Request.Body.ChannelType
                $ChannelOwnerID = $Request.Body.ChannelOwnerID
                if (-not $ChannelName) { throw 'ChannelName is required' }
                if (-not $ChannelType) { $ChannelType = 'standard' }

                # Support autocomplete/select field format: { value: "...", label: "..." }
                if ($ChannelOwnerID -is [hashtable] -or $ChannelOwnerID -is [PSCustomObject]) {
                    $ChannelOwnerID = $ChannelOwnerID.value
                } elseif ($ChannelOwnerID -is [System.Collections.IDictionary]) {
                    $ChannelOwnerID = $ChannelOwnerID['value']
                }

                $ChannelBody = @{
                    displayName    = $ChannelName
                    description    = $ChannelDescription
                    membershipType = $ChannelType
                }

                # Private and Shared channels require at least one owner when using app permissions
                if ($ChannelType -in @('private', 'shared')) {
                    if (-not $ChannelOwnerID) {
                        throw "A channel owner is required when creating a $ChannelType channel. Please select a channel owner."
                    }
                    $ChannelBody['members'] = @(
                        @{
                            '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                            'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$ChannelOwnerID')"
                            'roles'           = [string[]]@('owner')
                        }
                    )
                }

                $ChannelJson = $ChannelBody | ConvertTo-Json -Depth 10 -Compress

                if ($ChannelType -eq 'shared') {
                    # Shared channels require the beta endpoint — v1.0 with app-only fails with GetThreadAsync
                    $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/beta/teams/$TeamID/channels" -tenantid $TenantFilter -type POST -body $ChannelJson
                } else {
                    $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels" -tenantid $TenantFilter -type POST -body $ChannelJson
                }
                $Message = "Successfully created channel '$ChannelName' in team '$TeamLabel'"
            }
            'DeleteChannel' {
                $ChannelID = $Request.Body.ChannelID
                $ChannelName = $Request.Body.ChannelName
                if (-not $ChannelID) { throw 'ChannelID is required' }
                $ChannelLabel = if ($ChannelName) { $ChannelName } else { $ChannelID }

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$ChannelID" -tenantid $TenantFilter -type DELETE
                $Message = "Successfully deleted channel '$ChannelLabel' from team '$TeamLabel'. All messages, files, and tabs in this channel have been permanently removed."
            }
            'RemoveApp' {
                $AppInstallationID = $Request.Body.AppInstallationID
                $AppName = $Request.Body.AppName
                if (-not $AppInstallationID) { throw 'AppInstallationID is required' }
                $AppLabel = if ($AppName) { $AppName } else { $AppInstallationID }

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/installedApps/$AppInstallationID" -tenantid $TenantFilter -type DELETE
                $Message = "Successfully removed app '$AppLabel' from team '$TeamLabel'"
            }
            'ListChannelMembers' {
                $ChannelID = $Request.Body.ChannelID
                $ChannelType = $Request.Body.ChannelType
                if (-not $ChannelID) { throw 'ChannelID is required' }

                $GraphVersion = if ($ChannelType -eq 'shared') { 'beta' } else { 'v1.0' }
                $ChannelMembers = New-GraphGetRequest -uri "https://graph.microsoft.com/$GraphVersion/teams/$TeamID/channels/$ChannelID/members" -tenantid $TenantFilter -AsApp $true
                $MemberList = @($ChannelMembers | ForEach-Object {
                    [PSCustomObject]@{
                        id              = $_.id
                        displayName     = $_.displayName
                        email           = $_.email
                        roles           = ($_.roles -join ', ')
                        userId          = $_.userId
                    }
                })

                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{ Results = $MemberList }
                })
            }
            'AddChannelMember' {
                $ChannelID = $Request.Body.ChannelID
                $ChannelName = $Request.Body.ChannelName
                $ChannelType = $Request.Body.ChannelType
                $UserID = $Request.Body.UserID
                $ChannelRole = $Request.Body.ChannelRole
                if (-not $ChannelID) { throw 'ChannelID is required' }
                if (-not $UserID) { throw 'UserID is required' }

                # Support autocomplete/select field format: { value: "...", label: "..." }
                if ($UserID -is [hashtable] -or $UserID -is [PSCustomObject]) {
                    $UserID = $UserID.value
                } elseif ($UserID -is [System.Collections.IDictionary]) {
                    $UserID = $UserID['value']
                }

                if ($ChannelRole -is [hashtable] -or $ChannelRole -is [PSCustomObject]) {
                    $ChannelRole = $ChannelRole.value
                } elseif ($ChannelRole -is [System.Collections.IDictionary]) {
                    $ChannelRole = $ChannelRole['value']
                }

                if (-not $ChannelRole) { $ChannelRole = 'member' }
                $ChannelLabel = if ($ChannelName) { $ChannelName } else { $ChannelID }
                $OriginalInput = $UserID

                $GuestInvited = $false
                $ExternalTenantId = $null
                $IsNonStandard = $ChannelType -eq 'shared' -or $ChannelType -eq 'private'

                if ($UserID -match '@') {
                    if ($ChannelType -eq 'shared') {
                        $EncodedEmail = $UserID -replace '#', '%23'
                        $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=mail eq '$EncodedEmail' or userPrincipalName eq '$EncodedEmail'&`$select=id,displayName,userType" -tenantid $TenantFilter -AsApp $true
                        $ResolvedUser = if ($UserLookup -is [array]) { $UserLookup[0] } else { $UserLookup }

                        if ($ResolvedUser -and $ResolvedUser.userType -eq 'Member') {
                            $UserID = $ResolvedUser.id
                        } else {
                            $EmailDomain = ($UserID -split '@')[1]
                            try {
                                $OidcConfig = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$EmailDomain/.well-known/openid-configuration" -Method GET -ErrorAction Stop
                                $ExternalTenantId = ($OidcConfig.issuer -split '/')[3]
                            } catch {
                                throw "Could not resolve tenant for domain '$EmailDomain'. Ensure the domain belongs to a valid Microsoft 365 organization."
                            }
                            if (-not $ExternalTenantId -or $ExternalTenantId -eq '9188040d-6c67-4c5b-b112-36a304b66dad') {
                                throw "The domain '$EmailDomain' does not belong to a Microsoft 365 organization. Shared channels require a work or school account."
                            }
                            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Adding external user '$UserID' from tenant $ExternalTenantId to shared channel via B2B direct connect" -Sev Info
                        }
                    } else {
                        $EncodedEmail = $UserID -replace '#', '%23'
                        $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=mail eq '$EncodedEmail' or userPrincipalName eq '$EncodedEmail'&`$select=id,displayName,userType" -tenantid $TenantFilter -AsApp $true
                        if (-not $UserLookup -or $UserLookup.Count -eq 0) {
                            $InviteBody = @{
                                invitedUserEmailAddress = $UserID
                                inviteRedirectUrl       = 'https://myapps.microsoft.com'
                                sendInvitationMessage   = $false
                            } | ConvertTo-Json -Depth 5
                            $InviteResult = New-GraphPostRequest -uri 'https://graph.microsoft.com/beta/invitations' -tenantid $TenantFilter -type POST -body $InviteBody
                            $UserID = $InviteResult.invitedUser.id
                            if (-not $UserID) { throw "Guest invitation succeeded but no user ID was returned for '$OriginalInput'" }
                            $GuestInvited = $true
                            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Auto-invited guest '$OriginalInput' to tenant for channel access" -Sev Info
                        } else {
                            $ResolvedUser = if ($UserLookup -is [array]) { $UserLookup[0] } else { $UserLookup }
                            $UserID = $ResolvedUser.id
                        }
                    }
                }

                $MemberBody = @{
                    '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                    'roles'           = if ($ChannelRole -eq 'owner') { @('owner') } else { @() }
                    'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$UserID')"
                }
                if ($ExternalTenantId) {
                    $MemberBody['tenantId'] = $ExternalTenantId
                }
                $MemberBodyJson = $MemberBody | ConvertTo-Json -Depth 5 -Compress

                $GraphUri = "https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$ChannelID/members"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "AddChannelMember: URI=$GraphUri ChannelType=$ChannelType IsNonStandard=$IsNonStandard TeamID=$TeamID ChannelID=$ChannelID Body=$MemberBodyJson" -Sev Debug

                if ($IsNonStandard) {
                    $null = New-GraphPostRequest -uri $GraphUri -tenantid $TenantFilter -type POST -body $MemberBodyJson -NoAuthCheck $true
                } else {
                    $null = New-GraphPostRequest -AsApp $true -uri $GraphUri -tenantid $TenantFilter -type POST -body $MemberBodyJson
                }

                $Message = if ($GuestInvited) {
                    "Successfully invited guest '$OriginalInput' and added as $ChannelRole to channel '$ChannelLabel' in team '$TeamLabel'"
                } elseif ($ExternalTenantId) {
                    "Successfully added external user '$OriginalInput' as $ChannelRole to shared channel '$ChannelLabel' in team '$TeamLabel' via B2B direct connect"
                } else {
                    "Successfully added $ChannelRole to channel '$ChannelLabel' in team '$TeamLabel'"
                }
            }
            'RemoveChannelMember' {
                $ChannelID = $Request.Body.ChannelID
                $ChannelName = $Request.Body.ChannelName
                $ChannelType = $Request.Body.ChannelType
                $MembershipID = $Request.Body.MembershipID
                $MemberName = $Request.Body.MemberName
                if (-not $ChannelID) { throw 'ChannelID is required' }
                if (-not $MembershipID) { throw 'MembershipID is required' }
                $ChannelLabel = if ($ChannelName) { $ChannelName } else { $ChannelID }
                $MemberLabel = if ($MemberName) { $MemberName } else { $MembershipID }

                $GraphVersion = if ($ChannelType -eq 'shared') { 'beta' } else { 'v1.0' }
                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/$GraphVersion/teams/$TeamID/channels/$ChannelID/members/$MembershipID" -tenantid $TenantFilter -type DELETE
                $Message = "Successfully removed '$MemberLabel' from channel '$ChannelLabel' in team '$TeamLabel'"
            }
            default {
                throw "Unknown action: $Action. Supported actions: Archive, Unarchive, Clone, CreateChannel, DeleteChannel, RemoveApp, ListChannelMembers, AddChannelMember, RemoveChannelMember"
            }
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $NormError = [string]$ErrorMessage.NormalizedError
        $RawError = [string]$ErrorMessage.Message
        # Translate Microsoft's internal "xTap" abbreviation and format the action name
        $FriendlyError = $NormError -replace 'due to xTap', 'due to a cross-tenant access policy restriction'
        $FriendlyAction = ($Action -creplace '([a-z])([A-Z])', '$1 $2').ToLower()
        $Message = "Failed to $FriendlyAction team '$TeamLabel'. Error: $FriendlyError"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden

        # Run B2B / cross-tenant diagnostics for AddChannelMember failures
        if ($Action -eq 'AddChannelMember') {
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "AddChannelMember debug: ChannelType=$($Request.Body.ChannelType), UserID=$($Request.Body.UserID), ChannelID=$($Request.Body.ChannelID), RawError=$RawError" -Sev Debug
            try {
                $DiagMessages = [System.Collections.Generic.List[string]]::new()
                $IsSharedChannel = $Request.Body.ChannelType -eq 'shared'
                $IsBackendError = $NormError -match 'backend request' -or $RawError -match 'backend request'
                $IsExternalError = $NormError -match 'not allowed' -or $NormError -match 'external' -or $NormError -match 'guest' -or $NormError -match 'cross-tenant' -or $NormError -match 'collaboration' -or $RawError -match 'not allowed' -or $RawError -match 'Externally authenticated'

                if ($IsBackendError -and $IsSharedChannel) {
                    $DiagMessages.Add("[Teams Service] 'Failed to execute backend request' on a shared channel typically indicates a permissions or provisioning issue. Verify: (1) The CIPP app has ChannelMember.ReadWrite.All application permission granted and consented. (2) The shared channel is fully provisioned. (3) If adding an external user, cross-tenant access policies must allow B2B direct connect on BOTH tenants.")
                }

                if ($IsExternalError -or $IsBackendError) {
                    $EmailInput = $Request.Body.UserID
                    if ($EmailInput -is [hashtable] -or $EmailInput -is [PSCustomObject]) { $EmailInput = $EmailInput.value }
                    $EmailDomain = if ($EmailInput -match '@') { ($EmailInput -split '@')[1] } else { $null }

                    # --- Check Entra External Collaboration settings ---
                    try {
                        $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

                        if ($AuthPolicy.allowInvitesFrom -eq 'none') {
                            $DiagMessages.Add("[Entra External Collaboration] Guest invitations are completely disabled ('No one in the organization can invite guest users'). Change this to allow at least admins to send invitations. CIPP Settings: /tenant/administration/cross-tenant-access/external-collaboration")
                        }

                        # Check B2B domain allow/block lists
                        try {
                            $B2BPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
                            $B2BManagement = $B2BPolicy | Where-Object { $_.type -eq 6 }
                            if ($B2BManagement -and $EmailDomain) {
                                $B2BDefinition = ($B2BManagement.definition | ConvertFrom-Json).B2BManagementPolicy
                                $DomainPolicy = $B2BDefinition.InvitationsAllowedAndBlockedDomainsPolicy

                                if ($DomainPolicy.AllowedDomains -and $DomainPolicy.AllowedDomains.Count -gt 0) {
                                    if ($EmailDomain -notin $DomainPolicy.AllowedDomains) {
                                        $DiagMessages.Add("[Entra External Collaboration] Domain '$EmailDomain' is NOT in the allowed domains list. Currently allowed: $($DomainPolicy.AllowedDomains -join ', '). Add '$EmailDomain' to the allowed list or switch to a block-list approach. CIPP Settings: /tenant/administration/cross-tenant-access/external-collaboration")
                                    }
                                }

                                if ($DomainPolicy.BlockedDomains -and $DomainPolicy.BlockedDomains.Count -gt 0) {
                                    if ($EmailDomain -in $DomainPolicy.BlockedDomains) {
                                        $DiagMessages.Add("[Entra External Collaboration] Domain '$EmailDomain' is BLOCKED. Remove it from the blocked domains list to allow collaboration. CIPP Settings: /tenant/administration/cross-tenant-access/external-collaboration")
                                    }
                                }
                            }
                        } catch {
                            # B2B management policy may not be available
                        }
                    } catch {
                        # Could not retrieve Entra settings
                    }

                    # --- Check Teams guest access ---
                    try {
                        $ClientConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsClientConfiguration' -CmdParams @{Identity = 'Global' }
                        if ($ClientConfig.AllowGuestUser -eq $false) {
                            $DiagMessages.Add("[Teams Guest Access] Guest access is DISABLED for Microsoft Teams. Enable 'Allow guest access' in Teams Settings. CIPP Settings: /teams-share/teams/teams-settings")
                        }
                    } catch {
                        # Teams settings may not be accessible
                    }

                    # --- Check cross-tenant access policies (critical for shared channels) ---
                    if ($IsSharedChannel -and $EmailDomain) {
                        try {
                            $ExternalTenantIdDiag = $null
                            try {
                                $OidcDiag = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$EmailDomain/.well-known/openid-configuration" -Method GET -ErrorAction Stop
                                $ExternalTenantIdDiag = ($OidcDiag.issuer -split '/')[3]
                            } catch {}

                            # Check default cross-tenant access policy
                            $DefaultPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -tenantid $TenantFilter -AsApp $true

                            $DefaultB2BDirect = $DefaultPolicy.b2bDirectConnectInbound
                            $DefaultB2BDirectBlocked = ($DefaultB2BDirect.applications.accessType -eq 'blocked' -and $DefaultB2BDirect.applications.targets.target -eq 'AllApplications') -or ($DefaultB2BDirect.usersAndGroups.accessType -eq 'blocked' -and $DefaultB2BDirect.usersAndGroups.targets.target -eq 'AllUsers')

                            # Check partner-specific policy if we resolved the external tenant
                            $PartnerPolicy = $null
                            if ($ExternalTenantIdDiag) {
                                try {
                                    $PartnerPolicy = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners/$ExternalTenantIdDiag" -tenantid $TenantFilter -AsApp $true
                                } catch {
                                    # No partner-specific policy — default policy applies
                                }
                            }

                            $PartnerEditLink = if ($ExternalTenantIdDiag) {
                                "/tenant/administration/cross-tenant-access/partners/partner?tenantId=$ExternalTenantIdDiag"
                            } else {
                                '/tenant/administration/cross-tenant-access/partners/partner'
                            }

                            if ($PartnerPolicy) {
                                $PartnerB2BDirect = $PartnerPolicy.b2bDirectConnectInbound
                                $PartnerB2BDirectBlocked = ($PartnerB2BDirect.applications.accessType -eq 'blocked') -or ($PartnerB2BDirect.usersAndGroups.accessType -eq 'blocked')
                                $InheritDefault = -not $PartnerB2BDirect -or ($null -eq $PartnerB2BDirect.applications -and $null -eq $PartnerB2BDirect.usersAndGroups)

                                if ($InheritDefault -and $DefaultB2BDirectBlocked) {
                                    $DiagMessages.Add("[Cross-Tenant Access Policy] Partner policy for '$EmailDomain' exists but B2B direct connect inbound is set to 'Inherit from default', and the default policy BLOCKS it. Change B2B direct connect inbound to 'Allow' on the partner policy. CIPP Settings: $PartnerEditLink")
                                } elseif (-not $InheritDefault -and $PartnerB2BDirectBlocked) {
                                    $DiagMessages.Add("[Cross-Tenant Access Policy] Partner policy for '$EmailDomain' explicitly BLOCKS B2B direct connect inbound. Shared channels require this to be set to 'Allow'. CIPP Settings: $PartnerEditLink")
                                }
                            } elseif ($DefaultB2BDirectBlocked) {
                                $DiagMessages.Add("[Cross-Tenant Access Policy] No partner-specific policy exists for '$EmailDomain', and the DEFAULT policy BLOCKS B2B direct connect inbound. Create a partner-specific policy for '$EmailDomain' and set B2B direct connect inbound to 'Allow'. CIPP Settings: /tenant/administration/cross-tenant-access/partners/partner")
                            }

                            if ($DiagMessages.Count -eq 0 -or -not ($DiagMessages | Where-Object { $_ -match 'Cross-Tenant' })) {
                                $DiagMessages.Add("[Cross-Tenant Access Policy] The inbound B2B direct connect policy on THIS tenant appears to allow access. However, the EXTERNAL tenant ($EmailDomain) must also configure their OUTBOUND cross-tenant access policy to allow B2B direct connect to this tenant. This must be configured by the external organization's admin.")
                            }
                        } catch {
                            $DiagMessages.Add("[Cross-Tenant Access Policy] Could not retrieve cross-tenant access policies. Ensure the CIPP app has 'Policy.Read.All' permission. Shared channels require B2B direct connect policies to be configured on BOTH tenants.")
                        }
                    }

                    if ($DiagMessages.Count -gt 0) {
                        $Message = "Failed to $FriendlyAction team '$TeamLabel'. Error: $FriendlyError`n`nDiagnostics:`n" + ($DiagMessages -join "`n`n")
                    }
                }
            } catch {
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Channel member diagnostics failed: $($_.Exception.Message)" -Sev Debug
            }
        }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
