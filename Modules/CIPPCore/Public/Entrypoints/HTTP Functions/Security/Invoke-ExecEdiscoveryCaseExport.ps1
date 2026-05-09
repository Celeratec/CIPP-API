function Invoke-ExecEdiscoveryCaseExport {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $CaseId = $Request.Body.caseId
    $SearchId = $Request.Body.searchId

    $Uri = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/searches/$SearchId/exportResult"

    try {
        $ExportBody = @{
            displayName       = $Request.Body.displayName ?? "Export-$SearchId-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            exportCriteria    = $Request.Body.exportCriteria ?? 'searchHits'
            exportLocation    = $Request.Body.exportLocation ?? 'originalLocation'
        }

        if ($Request.Body.exportFormat) {
            $ExportBody.exportFormat = $Request.Body.exportFormat
        }

        $RequestBody = $ExportBody | ConvertTo-Json -Compress
        New-GraphPostRequest -uri $Uri -tenantid $TenantFilter -body $RequestBody -type POST -AsApp $true

        $ResponseBody = "Export started for search '$SearchId'. Check the Exports tab for progress."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{ Results = $ResponseBody }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to export eDiscovery search results: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
