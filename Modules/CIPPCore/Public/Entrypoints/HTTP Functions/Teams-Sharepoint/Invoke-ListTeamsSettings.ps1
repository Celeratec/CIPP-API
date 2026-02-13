function Invoke-ListTeamsSettings {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.tenantFilter

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        # Fetch all Teams tenant-level settings in parallel where possible
        $FederationConfig = $null
        $ExternalAccessPolicy = $null
        $MeetingPolicy = $null
        $ClientConfig = $null
        $MessagingPolicy = $null

        # Federation Configuration
        try {
            $FederationConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTenantFederationConfiguration' -CmdParams @{Identity = 'Global' }
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get federation config: $($_.Exception.Message)" -Sev 'Debug'
        }

        # External Access Policy
        try {
            $ExternalAccessPolicy = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsExternalAccessPolicy' -CmdParams @{Identity = 'Global' }
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get external access policy: $($_.Exception.Message)" -Sev 'Debug'
        }

        # Meeting Policy
        try {
            $MeetingPolicy = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsMeetingPolicy' -CmdParams @{Identity = 'Global' }
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get meeting policy: $($_.Exception.Message)" -Sev 'Debug'
        }

        # Client Configuration
        try {
            $ClientConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsClientConfiguration' -CmdParams @{Identity = 'Global' }
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get client config: $($_.Exception.Message)" -Sev 'Debug'
        }

        # Messaging Policy
        try {
            $MessagingPolicy = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTeamsMessagingPolicy' -CmdParams @{Identity = 'Global' }
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get messaging policy: $($_.Exception.Message)" -Sev 'Debug'
        }

        # Parse federation allowed/blocked domains
        $FederationAllowedDomains = @()
        $FederationBlockedDomains = @()
        $FederationMode = 'AllowAllExternal'

        if ($FederationConfig) {
            if ($FederationConfig.AllowFederatedUsers -eq $false) {
                $FederationMode = 'BlockAllExternal'
            } elseif ($FederationConfig.AllowedDomains -and $FederationConfig.AllowedDomains.GetType().Name -eq 'PSObject') {
                $FederationMode = 'AllowSpecificExternal'
                $FederationAllowedDomains = @($FederationConfig.AllowedDomains.Domain)
            } elseif ($FederationConfig.BlockedDomains -and $FederationConfig.BlockedDomains.Count -gt 0) {
                $FederationMode = 'BlockSpecificExternal'
                $FederationBlockedDomains = @($FederationConfig.BlockedDomains)
            }
        }

        $Result = [PSCustomObject]@{
            Tenant = $TenantFilter

            # Federation & External Access
            federationMode              = $FederationMode
            allowFederatedUsers         = $FederationConfig.AllowFederatedUsers ?? $true
            allowTeamsConsumer          = $FederationConfig.AllowTeamsConsumer ?? $false
            federationAllowedDomains    = $FederationAllowedDomains
            federationBlockedDomains    = $FederationBlockedDomains
            enableFederationAccess      = $ExternalAccessPolicy.EnableFederationAccess ?? $true
            enableTeamsConsumerAccess   = $ExternalAccessPolicy.EnableTeamsConsumerAccess ?? $false

            # Client Configuration
            allowGuestUser              = $ClientConfig.AllowGuestUser ?? $false
            allowGoogleDrive            = $ClientConfig.AllowGoogleDrive ?? $false
            allowShareFile              = $ClientConfig.AllowShareFile ?? $false
            allowBox                    = $ClientConfig.AllowBox ?? $false
            allowDropBox                = $ClientConfig.AllowDropBox ?? $false
            allowEgnyte                 = $ClientConfig.AllowEgnyte ?? $false

            # Meeting Policy
            allowAnonymousUsersToJoinMeeting           = $MeetingPolicy.AllowAnonymousUsersToJoinMeeting ?? $true
            allowAnonymousUsersToStartMeeting          = $MeetingPolicy.AllowAnonymousUsersToStartMeeting ?? $false
            autoAdmittedUsers                          = $MeetingPolicy.AutoAdmittedUsers ?? 'EveryoneInCompanyExcludingGuests'
            allowPSTNUsersToBypassLobby                = $MeetingPolicy.AllowPSTNUsersToBypassLobby ?? $false
            meetingChatEnabledType                     = $MeetingPolicy.MeetingChatEnabledType ?? 'Enabled'
            designatedPresenterRoleMode                = $MeetingPolicy.DesignatedPresenterRoleMode ?? 'EveryoneUserOverride'
            allowExternalParticipantGiveRequestControl = $MeetingPolicy.AllowExternalParticipantGiveRequestControl ?? $false

            # Messaging Policy
            allowOwnerDeleteMessage                      = $MessagingPolicy.AllowOwnerDeleteMessage ?? $false
            allowUserDeleteMessage                       = $MessagingPolicy.AllowUserDeleteMessage ?? $true
            allowUserEditMessage                         = $MessagingPolicy.AllowUserEditMessage ?? $true
            allowUserDeleteChat                          = $MessagingPolicy.AllowUserDeleteChat ?? $true
            readReceiptsEnabledType                      = $MessagingPolicy.ReadReceiptsEnabledType ?? 'UserPreference'
            createCustomEmojis                           = $MessagingPolicy.CreateCustomEmojis ?? $true
            deleteCustomEmojis                           = $MessagingPolicy.DeleteCustomEmojis ?? $false
            allowSecurityEndUserReporting                = $MessagingPolicy.AllowSecurityEndUserReporting ?? $true
            allowCommunicationComplianceEndUserReporting = $MessagingPolicy.AllowCommunicationComplianceEndUserReporting ?? $true
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = $Result
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to retrieve Teams settings: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve Teams settings: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
