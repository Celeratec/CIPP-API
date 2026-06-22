function Invoke-ExecSharePointImageVersionCleanup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    .SYNOPSIS
        Standalone version cleanup for one or more SharePoint drive items (destructive).
    .DESCRIPTION
        Deletes old versions of the supplied drive items, keeping the current version.
        Intended for use after a successful compression run when the admin wants to
        reclaim storage held by version history. WhatIf defaults to $true.

        This is a destructive operation; the caller (UI) must require explicit admin
        selection of a cleanup mode and a confirmation before calling with WhatIf=$false.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint

    $TenantFilter = $Request.Body.TenantFilter ?? $Request.Query.TenantFilter
    $DriveId = $Request.Body.DriveId
    $SiteId = $Request.Body.SiteId
    $SiteUrl = $Request.Body.SiteUrl
    $CleanupMode = $Request.Body.CleanupMode ?? 'recycle'
    $WhatIf = if ($null -eq $Request.Body.WhatIf) { $true } else { [bool]$Request.Body.WhatIf }

    # Accept a single file or an array of files. Each entry may be a string (DriveItemId)
    # or an object with DriveItemId/DriveId.
    $Files = @($Request.Body.Files | Where-Object { $_ })
    if ($Files.Count -eq 0) {
        if ($Request.Body.DriveItemId) { $Files = @($Request.Body.DriveItemId) }
    }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }
    if (-not $Files -or $Files.Count -eq 0) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'At least one file (Files[] or DriveItemId) is required' }
        })
    }
    if ($CleanupMode -notin @('recycle', 'permanent')) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = "Invalid CleanupMode '$CleanupMode'. Use recycle or permanent." }
        })
    }

    $Results = [System.Collections.Generic.List[object]]::new()
    $Warnings = [System.Collections.Generic.List[string]]::new()
    $TotalDeleted = 0
    $TotalErrors = 0

    try {
        foreach ($File in $Files) {
            $ItemId = if ($File -is [string]) { $File } else { ($File.DriveItemId ?? $File.id) }
            $ItemDriveId = if ($File -is [string]) { $DriveId } else { ($File.DriveId ?? $DriveId) }
            $FileName = if ($File -is [string]) { $ItemId } else { ($File.FileName ?? $File.name ?? $ItemId) }

            if (-not $ItemId -or -not $ItemDriveId) {
                $Results.Add([PSCustomObject]@{ FileName = $FileName; DriveItemId = $ItemId; VersionsDeleted = 0; Status = 'Failed'; Error = 'Missing DriveItemId or DriveId' })
                $TotalErrors++
                continue
            }

            $Cleanup = Remove-CIPPDriveItemVersion -TenantFilter $TenantFilter -DriveId $ItemDriveId -DriveItemId $ItemId -CleanupMode $CleanupMode -WhatIf $WhatIf
            foreach ($W in $Cleanup.Warnings) { if ($Warnings -notcontains $W) { $Warnings.Add($W) } }
            $TotalDeleted += $Cleanup.VersionsDeleted
            $Status = if ($Cleanup.Errors.Count -gt 0) { 'Failed' } elseif ($WhatIf) { 'WhatIf' } else { 'Versions cleaned' }
            if ($Cleanup.Errors.Count -gt 0) { $TotalErrors++ }
            $Results.Add([PSCustomObject]@{
                FileName           = $FileName
                DriveItemId        = $ItemId
                DriveId            = $ItemDriveId
                VersionCountBefore = $Cleanup.VersionCountBefore
                VersionsDeleted    = $Cleanup.VersionsDeleted
                Status             = $Status
                Error              = if ($Cleanup.Errors.Count -gt 0) { ($Cleanup.Errors -join '; ') } else { $null }
            })
        }

        $Sev = if ($WhatIf) { 'Info' } else { 'Warning' }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Version cleanup ($CleanupMode, WhatIf=$WhatIf): deleted $TotalDeleted versions across $($Files.Count) file(s), errors $TotalErrors." -Sev $Sev
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Version cleanup failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Version cleanup failed: $($ErrorMessage.NormalizedError)" }
        })
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{
            Results         = "Deleted $TotalDeleted version(s) across $($Files.Count) file(s)."
            WhatIf          = $WhatIf
            CleanupMode     = $CleanupMode
            VersionsDeleted = $TotalDeleted
            Errors          = $TotalErrors
            Warnings        = @($Warnings)
            Files           = @($Results)
        }
    })
}
