function Start-CIPPSharePointImageOptimizer {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Background worker that runs the SharePoint Image Optimizer and caches the result.
    .DESCRIPTION
        Invoked from the CIPP queue (Add-CippQueueMessage -Cmdlet 'Start-CIPPSharePointImageOptimizer').
        Long-running scans/compression cannot complete inside the ~230s HTTP gateway window,
        so the work is offloaded here and the result is written to the CacheImageOptimizer
        table for the polling endpoint (Invoke-ListImageOptimizerResults) to return.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$QueueId,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [string]$SiteId,
        [string]$SiteUrl,
        [string]$DriveId,
        [string]$LibraryName,
        [string]$FolderId,
        [string]$FolderPath,
        [string]$Mode = 'Audit',
        [double]$MinimumFileSizeMB = 5,
        [int]$JpegQuality = 82,
        [bool]$StripMetadata = $true,
        [double]$MinimumSavingsPercent = 15,
        [bool]$WhatIf = $true,
        [string]$VersionCleanupMode = 'none',
        [int]$MaxFiles = 0,
        [bool]$IncludeSubfolders = $true
    )

    $QueueTask = @{
        QueueId = $QueueId
        Name    = "Optimizing images ($Mode)"
        Status  = 'Running'
    }
    $TaskStatus = Set-CippQueueTask @QueueTask
    $QueueTask.TaskId = $TaskStatus.RowKey

    try {
        Update-CippQueueEntry -RowKey $QueueId -Status 'Running'

        Write-LogMessage -API 'Start-CIPPSharePointImageOptimizer' -tenant $TenantFilter -message "Starting image optimizer (mode=$Mode, whatIf=$WhatIf, siteId=$SiteId, driveId=$DriveId, folderId=$FolderId, queueId=$QueueId)" -Sev Info

        $Result = Invoke-CIPPSharePointImageOptimizer -TenantFilter $TenantFilter -SiteId $SiteId -SiteUrl $SiteUrl `
            -DriveId $DriveId -LibraryName $LibraryName -FolderId $FolderId -FolderPath $FolderPath -Mode $Mode `
            -MinimumFileSizeMB $MinimumFileSizeMB -JpegQuality $JpegQuality -StripMetadata $StripMetadata `
            -MinimumSavingsPercent $MinimumSavingsPercent -WhatIf $WhatIf -VersionCleanupMode $VersionCleanupMode `
            -MaxFiles $MaxFiles -IncludeSubfolders $IncludeSubfolders

        $CacheTable = Get-CippTable -tablename 'CacheImageOptimizer'
        $Entity = @{
            PartitionKey = $TenantFilter
            RowKey       = $QueueId
            Data         = [string]($Result | ConvertTo-Json -Depth 10 -Compress)
            CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null

        $S = $Result.Summary
        $Sev = if ($WhatIf -or $Mode -eq 'Audit') { 'Info' } else { 'Warning' }
        Write-LogMessage -API 'Start-CIPPSharePointImageOptimizer' -tenant $TenantFilter -message "Image optimizer completed ($Mode, WhatIf=$WhatIf): scanned $($S.FilesScanned), eligible $($S.EligibleFiles), compressed $($S.FilesCompressed), skipped $($S.FilesSkipped), versions deleted $($S.VersionsDeleted), errors $($S.Errors) (queueId=$QueueId)" -Sev $Sev

        Update-CippQueueEntry -RowKey $QueueId -Status 'Completed'
        $QueueTask.Status = 'Completed'
        Set-CippQueueTask @QueueTask
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'Start-CIPPSharePointImageOptimizer' -tenant $TenantFilter -message "Image optimizer failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage

        try {
            $CacheTable = Get-CippTable -tablename 'CacheImageOptimizer'
            $Entity = @{
                PartitionKey = $TenantFilter
                RowKey       = $QueueId
                Error        = $ErrorMessage.NormalizedError
                CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null
        } catch {
            Write-Warning "Failed to store image optimizer error: $_"
        }

        Update-CippQueueEntry -RowKey $QueueId -Status 'Failed'
        $QueueTask.Status = 'Failed'
        Set-CippQueueTask @QueueTask
    }
}
