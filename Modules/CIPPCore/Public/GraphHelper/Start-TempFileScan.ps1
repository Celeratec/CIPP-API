function Start-TempFileScan {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Background worker that scans for temp files and stores results in cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$QueueId,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [string]$SiteId,
        [string]$UserId,
        $Filters
    )

    $QueueTask = @{
        QueueId = $QueueId
        Name    = 'Scanning for temp files'
        Status  = 'Running'
    }
    $TaskStatus = Set-CippQueueTask @QueueTask
    $QueueTask.TaskId = $TaskStatus.RowKey

    try {
        Update-CippQueueEntry -RowKey $QueueId -Status 'Running'

        Write-LogMessage -API 'Start-TempFileScan' -tenant $TenantFilter -message "Starting temp file scan (scope=$Scope, siteId=$SiteId, userId=$UserId, queueId=$QueueId)" -Sev Info

        $ScanResult = Get-CIPPTempFileScan -TenantFilter $TenantFilter -Scope $Scope -SiteId $SiteId -UserId $UserId -Filters $Filters

        $CacheTable = Get-CippTable -tablename 'CacheTempFileScan'
        $Entity = @{
            PartitionKey = $TenantFilter
            RowKey       = $QueueId
            Data         = [string](@{
                Results    = $ScanResult.Results
                TotalCount = $ScanResult.TotalCount
                TotalSize  = $ScanResult.TotalSize
            } | ConvertTo-Json -Depth 10 -Compress)
            CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null

        Write-LogMessage -API 'Start-TempFileScan' -tenant $TenantFilter -message "Temp file scan completed: $($ScanResult.TotalCount) files found (queueId=$QueueId)" -Sev Info

        Update-CippQueueEntry -RowKey $QueueId -Status 'Completed'
        $QueueTask.Status = 'Completed'
        Set-CippQueueTask @QueueTask
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'Start-TempFileScan' -tenant $TenantFilter -message "Temp file scan failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage

        try {
            $CacheTable = Get-CippTable -tablename 'CacheTempFileScan'
            $Entity = @{
                PartitionKey = $TenantFilter
                RowKey       = $QueueId
                Error        = $ErrorMessage.NormalizedError
                CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null
        } catch {
            Write-Warning "Failed to store temp file scan error: $_"
        }

        Update-CippQueueEntry -RowKey $QueueId -Status 'Failed'
        $QueueTask.Status = 'Failed'
        Set-CippQueueTask @QueueTask
    }
}
