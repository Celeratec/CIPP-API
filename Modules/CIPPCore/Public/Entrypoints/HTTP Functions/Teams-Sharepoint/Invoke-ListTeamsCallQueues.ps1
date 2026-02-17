Function Invoke-ListTeamsCallQueues {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Voice.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $TenantFilter = $Request.Query.TenantFilter
    try {
        $CallQueues = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsCallQueue'
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $CallQueues = $ErrorMessage
    }
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @($CallQueues)
        })

}
