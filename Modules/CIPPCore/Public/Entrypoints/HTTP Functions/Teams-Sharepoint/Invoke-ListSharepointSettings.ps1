Function Invoke-ListSharepointSettings {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Admin.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.tenantFilter

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        $GraphResult = New-GraphGetRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true

        $Body = @($GraphResult)
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to get SharePoint settings: $ErrorMessage" -Sev 'Error'
        $Body = @{ Results = "Failed to get SharePoint settings: $ErrorMessage" }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })

}
