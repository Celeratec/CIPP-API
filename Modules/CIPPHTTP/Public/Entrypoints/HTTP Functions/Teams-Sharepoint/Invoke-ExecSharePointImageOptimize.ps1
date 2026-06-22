function Invoke-ExecSharePointImageOptimize {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    .SYNOPSIS
        Combined SharePoint Image Optimizer job (audit / compress / compress + cleanup).
    .DESCRIPTION
        Runs the Image Optimizer engine and returns the unified result object. The Mode
        and WhatIf flags control how destructive the run is:
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
    $Mode = $Request.Body.Mode ?? 'Audit'
    $MinimumFileSizeMB = [double]($Request.Body.MinimumFileSizeMB ?? 5)
    $JpegQuality = [int]($Request.Body.JpegQuality ?? 82)
    $MinimumSavingsPercent = [double]($Request.Body.MinimumSavingsPercent ?? 15)
    $VersionCleanupMode = $Request.Body.VersionCleanupMode ?? 'none'
    $MaxFiles = [int]($Request.Body.MaxFiles ?? 0)
    $FileIds = @($Request.Body.FileIds | Where-Object { $_ })

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
        $Result = Invoke-CIPPSharePointImageOptimizer -TenantFilter $TenantFilter -SiteId $SiteId -SiteUrl $SiteUrl `
            -DriveId $DriveId -LibraryName $LibraryName -Mode $Mode `
            -MinimumFileSizeMB $MinimumFileSizeMB -JpegQuality $JpegQuality -StripMetadata $StripMetadata `
            -MinimumSavingsPercent $MinimumSavingsPercent -WhatIf $WhatIf -VersionCleanupMode $VersionCleanupMode `
            -MaxFiles $MaxFiles -FileIds $FileIds -IncludeSubfolders $IncludeSubfolders

        $S = $Result.Summary
        $LogMsg = "Image Optimizer ($Mode, WhatIf=$WhatIf): scanned $($S.FilesScanned), eligible $($S.EligibleFiles), compressed $($S.FilesCompressed), skipped $($S.FilesSkipped), versions deleted $($S.VersionsDeleted), errors $($S.Errors)."
        $Sev = if ($WhatIf -or $Mode -eq 'Audit') { 'Info' } else { 'Warning' }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $LogMsg -Sev $Sev
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Image Optimizer run failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Image Optimizer run failed: $($ErrorMessage.NormalizedError)" }
        })
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Result
    })
}
