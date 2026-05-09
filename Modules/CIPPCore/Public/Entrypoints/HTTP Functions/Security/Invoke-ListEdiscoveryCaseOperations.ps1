function Invoke-ListEdiscoveryCaseOperations {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter
    $CaseId = $Request.Query.caseId

    try {
        $Uri = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/operations"
        $Operations = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true

        $GraphRequest = foreach ($Op in $Operations) {
            [PSCustomObject]@{
                id              = $Op.id
                displayName     = $Op.'@odata.type' -replace '#microsoft.graph.security.', ''
                action          = $Op.action
                status          = $Op.status
                percentProgress = $Op.percentProgress
                createdBy       = $Op.createdBy.user.displayName
                createdDate     = $Op.createdDateTime
                completedDate   = $Op.completedDateTime
                resultInfo      = $Op.resultInfo
                exportUrl       = $Op.exportFileMetadata.downloadUrl
                exportFileName  = $Op.exportFileMetadata.fileName
                exportFileSize  = $Op.exportFileMetadata.size
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = @($GraphRequest)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve operations for case '$CaseId': $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery operations: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
