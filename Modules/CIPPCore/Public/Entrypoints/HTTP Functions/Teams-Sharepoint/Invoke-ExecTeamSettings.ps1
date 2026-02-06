Function Invoke-ExecTeamSettings {
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
    $DisplayName = $Request.Body.DisplayName

    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }
    if (-not $TeamID) { $TeamID = $Request.Query.TeamID }

    $TeamLabel = if ($DisplayName) { $DisplayName } else { $TeamID }

    try {
        $PatchBody = @{}

        # Build patch body from provided settings
        if ($Request.Body.description) {
            $PatchBody['description'] = $Request.Body.description
        }

        if ($Request.Body.visibility) {
            $vis = $Request.Body.visibility
            if ($vis -is [hashtable] -or $vis -is [PSCustomObject]) {
                $vis = $vis.value
            }
            $PatchBody['visibility'] = $vis
        }

        # Member settings
        $MemberSettings = @{}
        $MemberSettingsFields = @(
            'allowCreateUpdateChannels', 'allowDeleteChannels', 'allowAddRemoveApps',
            'allowCreatePrivateChannels', 'allowCreateUpdateRemoveTabs', 'allowCreateUpdateRemoveConnectors'
        )
        foreach ($field in $MemberSettingsFields) {
            if ($null -ne $Request.Body.$field) {
                $val = $Request.Body.$field
                if ($val -is [string]) { $val = [System.Convert]::ToBoolean($val) }
                $MemberSettings[$field] = $val
            }
        }
        if ($MemberSettings.Count -gt 0) { $PatchBody['memberSettings'] = $MemberSettings }

        # Guest settings
        $GuestSettings = @{}
        $GuestFields = @('allowCreateUpdateChannels_guest', 'allowDeleteChannels_guest')
        $GuestFieldMap = @{
            'allowCreateUpdateChannels_guest' = 'allowCreateUpdateChannels'
            'allowDeleteChannels_guest'       = 'allowDeleteChannels'
        }
        foreach ($field in $GuestFields) {
            if ($null -ne $Request.Body.$field) {
                $val = $Request.Body.$field
                if ($val -is [string]) { $val = [System.Convert]::ToBoolean($val) }
                $GuestSettings[$GuestFieldMap[$field]] = $val
            }
        }
        if ($GuestSettings.Count -gt 0) { $PatchBody['guestSettings'] = $GuestSettings }

        # Messaging settings
        $MessagingSettings = @{}
        $MessagingFields = @(
            'allowUserEditMessages', 'allowUserDeleteMessages', 'allowOwnerDeleteMessages',
            'allowTeamMentions', 'allowChannelMentions'
        )
        foreach ($field in $MessagingFields) {
            if ($null -ne $Request.Body.$field) {
                $val = $Request.Body.$field
                if ($val -is [string]) { $val = [System.Convert]::ToBoolean($val) }
                $MessagingSettings[$field] = $val
            }
        }
        if ($MessagingSettings.Count -gt 0) { $PatchBody['messagingSettings'] = $MessagingSettings }

        # Fun settings
        $FunSettings = @{}
        $FunFields = @('allowGiphy', 'allowStickersAndMemes', 'allowCustomMemes')
        foreach ($field in $FunFields) {
            if ($null -ne $Request.Body.$field) {
                $val = $Request.Body.$field
                if ($val -is [string]) { $val = [System.Convert]::ToBoolean($val) }
                $FunSettings[$field] = $val
            }
        }
        if ($null -ne $Request.Body.giphyContentRating) {
            $gcr = $Request.Body.giphyContentRating
            if ($gcr -is [hashtable] -or $gcr -is [PSCustomObject]) { $gcr = $gcr.value }
            $FunSettings['giphyContentRating'] = $gcr
        }
        if ($FunSettings.Count -gt 0) { $PatchBody['funSettings'] = $FunSettings }

        if ($PatchBody.Count -eq 0) {
            throw 'No settings provided to update'
        }

        $Body = $PatchBody | ConvertTo-Json -Depth 5
        $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID" -tenantid $TenantFilter -type PATCH -body $Body

        $ChangedSettings = ($PatchBody.Keys -join ', ')
        $Message = "Successfully updated settings ($ChangedSettings) for team '$TeamLabel'"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to update settings for team '$TeamLabel'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
