function Invoke-ListEdiscoveryCaseSearches {
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
        $Uri = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/searches"
        $Searches = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true

        $GraphRequest = foreach ($Search in $Searches) {
            [PSCustomObject]@{
                id                   = $Search.id
                displayName          = $Search.displayName
                description          = $Search.description
                contentQuery         = $Search.contentQuery
                createdBy            = $Search.createdBy.user.displayName
                createdDate          = $Search.createdDateTime
                lastModified         = $Search.lastModifiedDateTime
                dataSourceScopes     = $Search.dataSourceScopes
                lastEstimateDate     = $Search.lastEstimateStatisticsOperation.createdDateTime
                estimatedItemCount   = $Search.lastEstimateStatisticsOperation.indexedItemCount
                estimatedSize        = $Search.lastEstimateStatisticsOperation.indexedItemsSize
                estimatedUnindexed   = $Search.lastEstimateStatisticsOperation.unindexedItemCount
                status               = if ($Search.lastEstimateStatisticsOperation.status) { $Search.lastEstimateStatisticsOperation.status } else { 'created' }
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
            Results = "Failed to retrieve searches for case '$CaseId': $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery searches: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
