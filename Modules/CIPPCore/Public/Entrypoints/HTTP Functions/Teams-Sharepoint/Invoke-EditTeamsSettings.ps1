function Invoke-EditTeamsSettings {
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
    $TenantFilter = $Request.Body.tenantFilter

    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        $Section = $Request.Body.section

        switch ($Section) {
            'federation' {
                # Establish Teams session first (required before calling New-CsEdgeAllowAllKnownDomains
                # which uses the Teams ConfigAPI and requires an active connection)
                $null = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTenantFederationConfiguration' -CmdParams @{ Identity = 'Global' }

                # Now build federation configuration parameters
                $FederationMode = $Request.Body.federationMode
                $cmdParams = @{
                    Identity            = 'Global'
                    AllowFederatedUsers = $true
                    BlockedDomains      = @()
                }
                $AllowedDomainsAsAList = @()

                switch ($FederationMode) {
                    'AllowAllExternal' {
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                    }
                    'BlockAllExternal' {
                        $cmdParams['AllowFederatedUsers'] = $false
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                    }
                    'AllowSpecificExternal' {
                        $AllowedDomainsAsAList = @($Request.Body.federationAllowedDomains)
                    }
                    'BlockSpecificExternal' {
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                        $BlockedDomains = @($Request.Body.federationBlockedDomains)
                        if ($BlockedDomains.Count -gt 0) {
                            $cmdParams['BlockedDomains'] = $BlockedDomains
                        }
                    }
                }

                # Use AllowedDomainsAsAList for specific domain lists, AllowedDomains for the allow-all object
                if ($AllowedDomainsAsAList.Count -gt 0) {
                    $cmdParams.Remove('AllowedDomains')
                    $cmdParams['AllowedDomainsAsAList'] = $AllowedDomainsAsAList
                }

                if ($null -ne $Request.Body.allowTeamsConsumer) {
                    $cmdParams['AllowTeamsConsumer'] = [bool]$Request.Body.allowTeamsConsumer
                }

                New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTenantFederationConfiguration' -CmdParams $cmdParams
                $Results.Add('Successfully updated federation configuration.')

                # Update External Access Policy
                $ExternalParams = @{ Identity = 'Global' }
                if ($null -ne $Request.Body.enableFederationAccess) {
                    $ExternalParams['EnableFederationAccess'] = [bool]$Request.Body.enableFederationAccess
                }
                if ($null -ne $Request.Body.enableTeamsConsumerAccess) {
                    $ExternalParams['EnableTeamsConsumerAccess'] = [bool]$Request.Body.enableTeamsConsumerAccess
                }
                if ($ExternalParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsExternalAccessPolicy' -CmdParams $ExternalParams
                    $Results.Add('Successfully updated external access policy.')
                }
            }

            'client' {
                # Update Client Configuration (guest access, external file sharing)
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowGuestUser) {
                    $cmdParams['AllowGuestUser'] = [bool]$Request.Body.allowGuestUser
                }
                if ($null -ne $Request.Body.allowGoogleDrive) {
                    $cmdParams['AllowGoogleDrive'] = [bool]$Request.Body.allowGoogleDrive
                }
                if ($null -ne $Request.Body.allowShareFile) {
                    $cmdParams['AllowShareFile'] = [bool]$Request.Body.allowShareFile
                }
                if ($null -ne $Request.Body.allowBox) {
                    $cmdParams['AllowBox'] = [bool]$Request.Body.allowBox
                }
                if ($null -ne $Request.Body.allowDropBox) {
                    $cmdParams['AllowDropBox'] = [bool]$Request.Body.allowDropBox
                }
                if ($null -ne $Request.Body.allowEgnyte) {
                    $cmdParams['AllowEgnyte'] = [bool]$Request.Body.allowEgnyte
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsClientConfiguration' -CmdParams $cmdParams
                    $Results.Add('Successfully updated client configuration.')
                }
            }

            'meeting' {
                # Update Global Meeting Policy
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowAnonymousUsersToJoinMeeting) {
                    $cmdParams['AllowAnonymousUsersToJoinMeeting'] = [bool]$Request.Body.allowAnonymousUsersToJoinMeeting
                }
                if ($null -ne $Request.Body.allowAnonymousUsersToStartMeeting) {
                    $cmdParams['AllowAnonymousUsersToStartMeeting'] = [bool]$Request.Body.allowAnonymousUsersToStartMeeting
                }
                if ($null -ne $Request.Body.autoAdmittedUsers) {
                    $cmdParams['AutoAdmittedUsers'] = $Request.Body.autoAdmittedUsers
                }
                if ($null -ne $Request.Body.allowPSTNUsersToBypassLobby) {
                    $cmdParams['AllowPSTNUsersToBypassLobby'] = [bool]$Request.Body.allowPSTNUsersToBypassLobby
                }
                if ($null -ne $Request.Body.meetingChatEnabledType) {
                    $cmdParams['MeetingChatEnabledType'] = $Request.Body.meetingChatEnabledType
                }
                if ($null -ne $Request.Body.designatedPresenterRoleMode) {
                    $cmdParams['DesignatedPresenterRoleMode'] = $Request.Body.designatedPresenterRoleMode
                }
                if ($null -ne $Request.Body.allowExternalParticipantGiveRequestControl) {
                    $cmdParams['AllowExternalParticipantGiveRequestControl'] = [bool]$Request.Body.allowExternalParticipantGiveRequestControl
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsMeetingPolicy' -CmdParams $cmdParams
                    $Results.Add('Successfully updated meeting policy.')
                }
            }

            'messaging' {
                # Update Global Messaging Policy
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowOwnerDeleteMessage) {
                    $cmdParams['AllowOwnerDeleteMessage'] = [bool]$Request.Body.allowOwnerDeleteMessage
                }
                if ($null -ne $Request.Body.allowUserDeleteMessage) {
                    $cmdParams['AllowUserDeleteMessage'] = [bool]$Request.Body.allowUserDeleteMessage
                }
                if ($null -ne $Request.Body.allowUserEditMessage) {
                    $cmdParams['AllowUserEditMessage'] = [bool]$Request.Body.allowUserEditMessage
                }
                if ($null -ne $Request.Body.allowUserDeleteChat) {
                    $cmdParams['AllowUserDeleteChat'] = [bool]$Request.Body.allowUserDeleteChat
                }
                if ($null -ne $Request.Body.readReceiptsEnabledType) {
                    $cmdParams['ReadReceiptsEnabledType'] = $Request.Body.readReceiptsEnabledType
                }
                if ($null -ne $Request.Body.createCustomEmojis) {
                    $cmdParams['CreateCustomEmojis'] = [bool]$Request.Body.createCustomEmojis
                }
                if ($null -ne $Request.Body.deleteCustomEmojis) {
                    $cmdParams['DeleteCustomEmojis'] = [bool]$Request.Body.deleteCustomEmojis
                }
                if ($null -ne $Request.Body.allowSecurityEndUserReporting) {
                    $cmdParams['AllowSecurityEndUserReporting'] = [bool]$Request.Body.allowSecurityEndUserReporting
                }
                if ($null -ne $Request.Body.allowCommunicationComplianceEndUserReporting) {
                    $cmdParams['AllowCommunicationComplianceEndUserReporting'] = [bool]$Request.Body.allowCommunicationComplianceEndUserReporting
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsMessagingPolicy' -CmdParams $cmdParams
                    $Results.Add('Successfully updated messaging policy.')
                }
            }

            default {
                throw "Invalid section: $Section. Valid values are: federation, client, meeting, messaging."
            }
        }

        if ($Results.Count -eq 0) {
            throw 'No valid settings were provided to update.'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($Results -join ' ') -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = ($Results -join ' ')
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to update Teams settings: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to update Teams settings: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
