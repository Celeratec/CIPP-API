function Invoke-ListTempFileScanResults {
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
    $QueueId = $Request.Query.queueId ?? $Request.Query.QueueId
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Query.TenantFilter

    if (-not $QueueId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'queueId is required' }
        })
    }

    try {
        $QueueData = Get-CIPPQueueData -QueueId $QueueId | Select-Object -First 1
        if (-not $QueueData) {
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NotFound
                Body       = @{ Results = 'Scan job not found' }
            })
        }

        if ($QueueData.Status -eq 'Running' -or $QueueData.Status -eq 'Queued') {
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Status  = 'Running'
                    QueueId = $QueueId
                }
            })
        }

        $CacheTable = Get-CippTable -tablename 'CacheTempFileScan'
        $SafeQueueId = ConvertTo-CIPPODataFilterValue -Value $QueueId -Type String
        $Filter = "RowKey eq '$SafeQueueId'"
        if ($TenantFilter) {
            $SafeTenant = ConvertTo-CIPPODataFilterValue -Value $TenantFilter -Type String
            $Filter = "PartitionKey eq '$SafeTenant' and RowKey eq '$SafeQueueId'"
        }
        $Cached = Get-CIPPAzDataTableEntity @CacheTable -Filter $Filter | Select-Object -First 1

        if (-not $Cached) {
            if ($QueueData.Status -match 'Failed') {
                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::InternalServerError
                    Body       = @{ Results = 'Temp file scan failed' }
                })
            }
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Status  = 'Running'
                    QueueId = $QueueId
                }
            })
        }

        if ($Cached.Error) {
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = @{ Results = "Failed to scan for temp files: $($Cached.Error)" }
            })
        }

        $Payload = $Cached.Data | ConvertFrom-Json -Depth 10
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Status     = 'Completed'
                QueueId    = $QueueId
                Results    = @($Payload.Results)
                TotalCount = $Payload.TotalCount
                TotalSize  = $Payload.TotalSize
            }
        })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to load temp file scan results: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Failed to load scan results: $($ErrorMessage.NormalizedError)" }
        })
    }
}
