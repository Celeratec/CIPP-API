function Invoke-ListImageOptimizerResults {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    .SYNOPSIS
        Poll for SharePoint Image Optimizer job results by QueueId.
    .DESCRIPTION
        Companion to Invoke-ExecSharePointImageOptimize. Returns Status 'Running' while the
        background worker is still processing, and the full optimizer result object once the
        job has completed (or an error message if it failed).
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
                    Body       = @{ Results = 'Optimizer job not found' }
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

        $CacheTable = Get-CippTable -tablename 'CacheImageOptimizer'
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
                        Body       = @{ Results = 'Image optimizer job failed' }
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
                    Body       = @{ Results = "Image optimizer job failed: $($Cached.Error)" }
                })
        }

        $Payload = $Cached.Data | ConvertFrom-Json -Depth 10
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Status   = 'Completed'
                    QueueId  = $QueueId
                    Mode     = $Payload.Mode
                    WhatIf   = $Payload.WhatIf
                    SiteUrl  = $Payload.SiteUrl
                    Library  = $Payload.Library
                    Folder   = $Payload.Folder
                    Summary  = $Payload.Summary
                    Results  = @($Payload.Results | Where-Object { $null -ne $_ })
                    Warnings = @($Payload.Warnings | Where-Object { $null -ne $_ })
                }
            })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to load image optimizer results: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = @{ Results = "Failed to load optimizer results: $($ErrorMessage.NormalizedError)" }
            })
    }
}
