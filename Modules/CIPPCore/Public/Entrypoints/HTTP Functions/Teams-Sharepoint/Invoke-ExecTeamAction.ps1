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
                if (-not $ChannelID) { throw 'ChannelID is required' }

                $ChannelMembers = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$ChannelID/members" -tenantid $TenantFilter -AsApp $true
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

                [string[]]$Roles = if ($ChannelRole -eq 'owner') { @('owner') } else { @() }

                $MemberBody = @{
                    '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                    'roles'           = $Roles
                    'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$UserID')"
                } | ConvertTo-Json -Depth 5

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$ChannelID/members" -tenantid $TenantFilter -type POST -body $MemberBody
                $Message = "Successfully added $ChannelRole to channel '$ChannelLabel' in team '$TeamLabel'"
            }
            'RemoveChannelMember' {
                $ChannelID = $Request.Body.ChannelID
                $ChannelName = $Request.Body.ChannelName
                $MembershipID = $Request.Body.MembershipID
                $MemberName = $Request.Body.MemberName
                if (-not $ChannelID) { throw 'ChannelID is required' }
                if (-not $MembershipID) { throw 'MembershipID is required' }
                $ChannelLabel = if ($ChannelName) { $ChannelName } else { $ChannelID }
                $MemberLabel = if ($MemberName) { $MemberName } else { $MembershipID }

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$ChannelID/members/$MembershipID" -tenantid $TenantFilter -type DELETE
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
        $Message = "Failed to $Action team '$TeamLabel'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
