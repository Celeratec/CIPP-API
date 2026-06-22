function Invoke-ExecSharePointImageOptimize {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    .SYNOPSIS
        Queue a SharePoint Image Optimizer job (audit / compress / compress + cleanup).
    .DESCRIPTION
        Scanning and compressing a document library can take far longer than the ~230s
        Azure HTTP gateway window, so the work is queued for background processing and the
        caller polls Invoke-ListImageOptimizerResults (by QueueId) for status and results.

        The Mode and WhatIf flags control how destructive the run is:
          - Mode 'Audit'              : read-only discovery.
          - Mode 'Compress'           : re-encodes and (when WhatIf=$false) replaces files.
          - Mode 'CompressAndCleanup' : as above, then removes old versions per
                                        VersionCleanupMode.
        WhatIf defaults to $true; while true NO file is modified and NO version is deleted.
        Version cleanup runs ONLY when VersionCleanupMode is not 'none'.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint

    $TenantFilter = $Request.Body.TenantFilter ?? $Request.Query.TenantFilter
    $SiteId = $Request.Body.SiteId
    $SiteUrl = $Request.Body.SiteUrl
    $DriveId = $Request.Body.DriveId
    $LibraryName = $Request.Body.LibraryName
    $FolderId = $Request.Body.FolderId
    $FolderPath = $Request.Body.FolderPath
    $Mode = $Request.Body.Mode ?? 'Audit'
    $MinimumFileSizeMB = [double]($Request.Body.MinimumFileSizeMB ?? 5)
    $JpegQuality = [int]($Request.Body.JpegQuality ?? 82)
    $MinimumSavingsPercent = [double]($Request.Body.MinimumSavingsPercent ?? 15)
    $VersionCleanupMode = $Request.Body.VersionCleanupMode ?? 'none'
    $MaxFiles = [int]($Request.Body.MaxFiles ?? 0)

    # Defaults that must fail safe.
    $StripMetadata = if ($null -eq $Request.Body.StripMetadata) { $true } else { [bool]$Request.Body.StripMetadata }
    $WhatIf = if ($null -eq $Request.Body.WhatIf) { $true } else { [bool]$Request.Body.WhatIf }
    $IncludeSubfolders = if ($null -eq $Request.Body.IncludeSubfolders) { $true } else { [bool]$Request.Body.IncludeSubfolders }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'TenantFilter is required' }
            })
    }
    if (-not $DriveId -and -not $SiteId -and -not $SiteUrl) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'DriveId, SiteId, or SiteUrl is required' }
            })
    }
    if ($Mode -notin @('Audit', 'Compress', 'CompressAndCleanup')) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = "Invalid Mode '$Mode'. Use Audit, Compress, or CompressAndCleanup." }
            })
    }
    # Guard: cleanup mode only meaningful with the cleanup job.
    if ($Mode -ne 'CompressAndCleanup') { $VersionCleanupMode = 'none' }

    try {
        $TargetLabel = $LibraryName
        if ($FolderPath) { $TargetLabel = "$LibraryName/$($FolderPath.Trim('/'))" }
        $QueueReference = "ImageOptimizer-$TenantFilter-$SiteId-$DriveId-$FolderId-$Mode"
        $Queue = New-CippQueueEntry -Name "Image Optimizer - $Mode$(if ($TargetLabel) { " ($TargetLabel)" })" -Link '/teams-share/sharepoint/image-optimizer' -Reference $QueueReference -TotalTasks 1

        $Queued = Add-CippQueueMessage -Cmdlet 'Start-CIPPSharePointImageOptimizer' -Parameters @{
            QueueId               = $Queue.RowKey
            TenantFilter          = $TenantFilter
            SiteId                = $SiteId
            SiteUrl               = $SiteUrl
            DriveId               = $DriveId
            LibraryName           = $LibraryName
            FolderId              = $FolderId
            FolderPath            = $FolderPath
            Mode                  = $Mode
            MinimumFileSizeMB     = $MinimumFileSizeMB
            JpegQuality           = $JpegQuality
            StripMetadata         = $StripMetadata
            MinimumSavingsPercent = $MinimumSavingsPercent
            WhatIf                = $WhatIf
            VersionCleanupMode    = $VersionCleanupMode
            MaxFiles              = $MaxFiles
            IncludeSubfolders     = $IncludeSubfolders
        }

        if (-not $Queued) {
            throw 'Failed to queue the image optimizer job'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Queued image optimizer (mode=$Mode, whatIf=$WhatIf, queueId=$($Queue.RowKey))" -Sev Info

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Queued       = $true
            QueueId      = $Queue.RowKey
            Mode         = $Mode
            QueueMessage = 'Job queued. Results will be available when it completes.'
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Image optimizer queue failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to start image optimizer: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
