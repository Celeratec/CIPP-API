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
                if (-not $ChannelName) { throw 'ChannelName is required' }
                if (-not $ChannelType) { $ChannelType = 'standard' }

                $ChannelBody = @{
                    displayName    = $ChannelName
                    description    = $ChannelDescription
                    membershipType = $ChannelType
                } | ConvertTo-Json -Depth 5

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/channels" -tenantid $TenantFilter -type POST -body $ChannelBody
                $Message = "Successfully created channel '$ChannelName' in team '$TeamLabel'"
            }
            default {
                throw "Unknown action: $Action. Supported actions: Archive, Unarchive, Clone, CreateChannel"
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
