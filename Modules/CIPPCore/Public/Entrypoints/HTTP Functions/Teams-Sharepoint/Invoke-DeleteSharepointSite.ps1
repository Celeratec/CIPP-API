function Invoke-DeleteSharepointSite {
    <#
    .FUNCTIONALITY
     Entrypoint
    .ROLE
     Sharepoint.Site.ReadWrite
     #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $SiteId = $Request.Body.SiteId
    $DisplayName = $Request.Body.DisplayName

    try {
        if (-not $SiteId) {
            throw "SiteId is required"
        }
        if (-not $TenantFilter) {
            throw "TenantFilter is required"
        }
        if ($SiteId -notmatch '^(\{)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(\})?$') {
            throw "SiteId must be a valid GUID"
        }

        # Offload deletion to background activity so the main app stays responsive and long-running deletes don't time out.
        $QueueLabel = if ($DisplayName) { $DisplayName } else { $SiteId }
        $Queue = New-CippQueueEntry -Name "Delete SharePoint Site - $QueueLabel" -TotalTasks 1
        $InputObject = [PSCustomObject]@{
            Batch            = @(
                [PSCustomObject]@{
                    FunctionName = 'ExecDeleteSharepointSite'
                    TenantFilter = $TenantFilter
                    SiteId       = $SiteId
                    Headers      = $Headers
                    APIName      = $APIName
                    QueueId      = $Queue.RowKey
                }
            )
            OrchestratorName = "DeleteSharepointSite_$SiteId"
            SkipLog          = $true
        }
        $null = Start-NewOrchestration -FunctionName CIPPOrchestrator -InputObject ($InputObject | ConvertTo-Json -Depth 10)

        $Results = "Deletion of the SharePoint site has been queued. For large sites this may take several minutes. You can continue using the app; the site will be removed in the background."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results = $Results
                Queued  = $true
                QueueId = $Queue.RowKey
            }
        })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = $ErrorMessage.NormalizedError
        $Results = "Failed to queue SharePoint site deletion for ID $SiteId. Error: $ErrorText"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ 'Results' = $Results }
        })
    }
}
