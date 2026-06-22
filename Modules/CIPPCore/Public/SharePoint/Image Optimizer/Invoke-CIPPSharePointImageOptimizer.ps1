function Invoke-CIPPSharePointImageOptimizer {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Core engine for the SharePoint Image Optimizer (audit / compress / version cleanup).
    .DESCRIPTION
        Resolves the target document library, discovers large JPG/JPEG files, and -
        depending on Mode - compresses them server-side and optionally removes old file
        versions to reclaim storage. Returns the standard Image Optimizer result object.

        This function is conservative by design:
          - WhatIf defaults to $true. When $true, NO file is overwritten and NO version
            is deleted.
          - A compressed file is uploaded ONLY when it is smaller than the original by at
            least MinimumSavingsPercent.
          - A file larger than the original after compression is never uploaded.
          - Version cleanup runs only when explicitly requested (VersionCleanupMode other
            than 'none') AND compression succeeded, and never deletes the current version.
          - Errors are captured per file; one failure never aborts the batch.
    .PARAMETER Mode
        Audit | Compress | CompressAndCleanup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [string]$SiteId,

        [Parameter(Mandatory = $false)]
        [string]$SiteUrl,

        [Parameter(Mandatory = $false)]
        [string]$DriveId,

        [Parameter(Mandatory = $false)]
        [string]$LibraryName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Audit', 'Compress', 'CompressAndCleanup')]
        [string]$Mode = 'Audit',

        [Parameter(Mandatory = $false)]
        [double]$MinimumFileSizeMB = 5,

        [Parameter(Mandatory = $false)]
        [int]$JpegQuality = 82,

        [Parameter(Mandatory = $false)]
        [bool]$StripMetadata = $true,

        [Parameter(Mandatory = $false)]
        [double]$MinimumSavingsPercent = 15,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet('none', 'recycle', 'permanent')]
        [string]$VersionCleanupMode = 'none',

        [Parameter(Mandatory = $false)]
        [int]$MaxFiles = 0,

        [Parameter(Mandatory = $false)]
        [string[]]$FileIds = @(),

        [Parameter(Mandatory = $false)]
        [bool]$IncludeSubfolders = $true
    )

    # Hard safety cap to avoid runaway batches / throttling on huge libraries.
    $HardCap = 500
    if ($MaxFiles -le 0 -or $MaxFiles -gt $HardCap) { $EffectiveMax = $HardCap } else { $EffectiveMax = $MaxFiles }

    if ($JpegQuality -lt 60) { $JpegQuality = 60 }
    if ($JpegQuality -gt 95) { $JpegQuality = 95 }

    $Warnings = [System.Collections.Generic.List[string]]::new()
    $Results = [System.Collections.Generic.List[object]]::new()

    $Output = [PSCustomObject]@{
        Tenant  = $TenantFilter
        SiteUrl = $SiteUrl
        SiteId  = $SiteId
        Library = $LibraryName
        DriveId = $DriveId
        Mode    = $Mode
        WhatIf  = $WhatIf
        Summary = [PSCustomObject]@{
            FilesScanned          = 0
            EligibleFiles         = 0
            FilesCompressed       = 0
            FilesSkipped          = 0
            OriginalBytes         = [long]0
            CompressedBytes       = [long]0
            EstimatedSavingsBytes = [long]0
            VersionsDeleted       = 0
            Errors                = 0
        }
        Results  = @()
        Warnings = @()
    }

    # --- Resolve site id from URL if needed --------------------------------
    if (-not $SiteId -and $SiteUrl) {
        try {
            $Uri = [System.Uri]$SiteUrl
            $Hostname = $Uri.Host
            $RelPath = $Uri.AbsolutePath.TrimStart('/')
            $SiteLookup = if ($RelPath) {
                New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/${Hostname}:/$RelPath" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
            } else {
                New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$Hostname" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
            }
            $SiteId = $SiteLookup.id
            $Output.SiteId = $SiteId
        } catch {
            $Warnings.Add("Could not resolve site from URL '$SiteUrl': $($_.Exception.Message)")
        }
    }

    # --- Resolve drive id ---------------------------------------------------
    if (-not $DriveId) {
        if (-not $SiteId) {
            $Warnings.Add('No DriveId could be resolved: provide DriveId, or SiteId/SiteUrl with an optional LibraryName.')
            $Output.Warnings = @($Warnings)
            return $Output
        }
        try {
            $Drives = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives?`$select=id,name,driveType" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
            $Drives = @($Drives) | Where-Object { $_.id }
            if ($LibraryName) {
                $Drive = $Drives | Where-Object { $_.name -eq $LibraryName } | Select-Object -First 1
                if (-not $Drive) {
                    $Warnings.Add("Library '$LibraryName' not found on the site. Available: $(( $Drives.name ) -join ', ').")
                }
            }
            if (-not $Drive) {
                $Drive = $Drives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1
            }
            if (-not $Drive) { $Drive = $Drives | Select-Object -First 1 }
            if ($Drive) {
                $DriveId = $Drive.id
                $Output.DriveId = $DriveId
                if (-not $Output.Library) { $Output.Library = $Drive.name }
            }
        } catch {
            $Warnings.Add("Failed to resolve drives for site: $($_.Exception.Message)")
        }
    }

    if (-not $DriveId) {
        $Output.Warnings = @($Warnings)
        return $Output
    }

    # --- Audit (discover candidates) ---------------------------------------
    $Audit = Get-CIPPSharePointImageCandidate -TenantFilter $TenantFilter -DriveId $DriveId `
        -MinimumFileSizeMB $MinimumFileSizeMB -IncludeSubfolders $IncludeSubfolders -MaxFiles 0
    $Candidates = @($Audit.Candidates)
    $Output.Summary.FilesScanned = $Audit.FilesScanned

    # Filter to specifically requested files if provided (ignore null/empty entries).
    $RequestedIds = @($FileIds | Where-Object { $_ })
    if ($RequestedIds.Count -gt 0) {
        $Candidates = @($Candidates | Where-Object { $RequestedIds -contains $_.DriveItemId })
    }

    $Eligible = @($Candidates | Where-Object { $_.Eligible })
    $Output.Summary.EligibleFiles = $Eligible.Count

    # --- Audit-only mode: report and return --------------------------------
    if ($Mode -eq 'Audit') {
        foreach ($Cand in $Candidates) {
            $Status = if ($Cand.Eligible) { 'Found' } else { $Cand.SkipReason }
            $Output.Summary.OriginalBytes += $Cand.SizeBytes
            if (-not $Cand.Eligible) { $Output.Summary.FilesSkipped++ }
            $Results.Add((New-ImageOptimizerResultRow -Candidate $Cand -SiteUrl $Output.SiteUrl -Library $Output.Library -Status $Status))
        }
        $Output.Results = @($Results)
        $Output.Warnings = @($Warnings)
        return $Output
    }

    # --- Compress / CompressAndCleanup -------------------------------------
    $Processed = 0
    foreach ($Cand in $Candidates) {
        if (-not $Cand.Eligible) {
            $Output.Summary.FilesSkipped++
            $Output.Summary.OriginalBytes += $Cand.SizeBytes
            $Results.Add((New-ImageOptimizerResultRow -Candidate $Cand -SiteUrl $Output.SiteUrl -Library $Output.Library -Status $Cand.SkipReason))
            continue
        }

        if ($Processed -ge $EffectiveMax) {
            $Warnings.Add("Reached the maximum of $EffectiveMax files for this run; remaining eligible files were not processed.")
            break
        }
        $Processed++

        $Row = New-ImageOptimizerResultRow -Candidate $Cand -SiteUrl $Output.SiteUrl -Library $Output.Library -Status 'Found'
        $Output.Summary.OriginalBytes += $Cand.SizeBytes

        try {
            # 1. Get the drive item + download URL.
            $Item = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$($Cand.DriveItemId)?`$select=id,name,size,@microsoft.graph.downloadUrl,file" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
            $DownloadUrl = $Item.'@microsoft.graph.downloadUrl'
            if (-not $DownloadUrl) {
                $Row.Status = 'Skipped: locked'
                $Row.Error = 'No download URL available (file may be checked out, locked, or inaccessible).'
                $Output.Summary.FilesSkipped++
                $Results.Add($Row)
                continue
            }

            # Download to a temp file so binary JPEG bytes are never coerced to text.
            $TempFile = [System.IO.Path]::GetTempFileName()
            try {
                $null = Invoke-CIPPImageHttpWithRetry -ScriptBlock {
                    Invoke-WebRequest -Uri $DownloadUrl -Method GET -OutFile $TempFile -UseBasicParsing -ErrorAction Stop
                }
                $OriginalBytes = [System.IO.File]::ReadAllBytes($TempFile)
            } finally {
                if (Test-Path -LiteralPath $TempFile) { Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue }
            }

            # 2. Compress in memory.
            $Compress = Compress-CIPPImage -ImageBytes $OriginalBytes -Quality $JpegQuality -StripMetadata $StripMetadata
            if ($Compress.Warning) { $Warnings.Add("$($Cand.FileName): $($Compress.Warning)") }
            if (-not $Compress.Success) {
                $Row.Status = 'Failed'
                $Row.Error = $Compress.Error
                $Output.Summary.Errors++
                $Results.Add($Row)
                continue
            }

            $Row.Engine = $Compress.Engine
            $NewBytes = $Compress.CompressedBytes
            $OrigLen = [long]$OriginalBytes.Length
            $SavingsBytes = $OrigLen - $NewBytes
            $SavingsPercent = if ($OrigLen -gt 0) { [math]::Round((($SavingsBytes / $OrigLen) * 100), 1) } else { 0 }

            $Row.OriginalBytes = $OrigLen
            $Row.CompressedBytes = $NewBytes
            $Row.SavingsBytes = $SavingsBytes
            $Row.SavingsPercent = $SavingsPercent

            # 3. Rule 7/8: never upload if larger; respect minimum savings.
            if ($NewBytes -ge $OrigLen -or $SavingsPercent -lt $MinimumSavingsPercent) {
                $Row.Status = 'Skipped: compression savings too small'
                $Row.CompressedBytes = 0
                $Row.SavingsBytes = 0
                $Row.SavingsPercent = 0
                $Output.Summary.FilesSkipped++
                $Results.Add($Row)
                continue
            }

            # 4. Upload over the original (only when not WhatIf).
            if ($WhatIf) {
                $Row.Status = 'Compressed'
                $Output.Summary.FilesCompressed++
                $Output.Summary.CompressedBytes += $NewBytes
                $Output.Summary.EstimatedSavingsBytes += $SavingsBytes
                $Results.Add($Row)
                continue
            }

            try {
                $Token = Get-GraphToken -tenantid $TenantFilter -AsApp $true
                $UploadHeaders = @{
                    Authorization  = "Bearer $($Token.access_token)"
                    'Content-Type' = 'image/jpeg'
                }
                $UploadUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$($Cand.DriveItemId)/content"
                $null = Invoke-CIPPImageHttpWithRetry -ScriptBlock {
                    Invoke-RestMethod -Uri $UploadUri -Method PUT -Headers $UploadHeaders -Body $Compress.Data -ErrorAction Stop
                }
            } catch {
                $Classified = Get-ImageOptimizerUploadError -Exception $_
                $Row.Status = $Classified.Status
                $Row.Error = $Classified.Message
                if ($Classified.Status -eq 'Skipped: locked') {
                    $Output.Summary.FilesSkipped++
                } else {
                    $Output.Summary.Errors++
                }
                $Results.Add($Row)
                continue
            }

            $Output.Summary.FilesCompressed++
            $Output.Summary.CompressedBytes += $NewBytes
            $Output.Summary.EstimatedSavingsBytes += $SavingsBytes
            $Row.Status = 'Compressed'

            # 5. Optional version cleanup (only after a real, successful upload).
            if ($Mode -eq 'CompressAndCleanup' -and $VersionCleanupMode -ne 'none') {
                $Cleanup = Remove-CIPPDriveItemVersion -TenantFilter $TenantFilter -DriveId $DriveId -DriveItemId $Cand.DriveItemId -CleanupMode $VersionCleanupMode -WhatIf $false
                $Row.VersionCountBefore = $Cleanup.VersionCountBefore
                $Row.VersionsDeleted = $Cleanup.VersionsDeleted
                $Output.Summary.VersionsDeleted += $Cleanup.VersionsDeleted
                foreach ($W in $Cleanup.Warnings) { if ($Warnings -notcontains $W) { $Warnings.Add($W) } }
                if ($Cleanup.Errors.Count -gt 0) {
                    $Row.Status = 'Compressed, version cleanup failed'
                    $Row.Error = ($Cleanup.Errors -join '; ')
                    $Output.Summary.Errors++
                } else {
                    $Row.Status = 'Compressed and versions cleaned'
                }
            }

            $Results.Add($Row)
        } catch {
            $Row.Status = 'Failed'
            $Row.Error = $_.Exception.Message
            $Output.Summary.Errors++
            $Results.Add($Row)
        }
    }

    $Output.Results = @($Results)
    $Output.Warnings = @($Warnings)
    return $Output
}

function New-ImageOptimizerResultRow {
    [CmdletBinding()]
    param($Candidate, $SiteUrl, $Library, [string]$Status)
    [PSCustomObject]@{
        FileName             = $Candidate.FileName
        WebUrl               = $Candidate.WebUrl
        DriveItemId          = $Candidate.DriveItemId
        DriveId              = $Candidate.DriveId
        Site                 = $SiteUrl
        Library              = $Library
        ServerRelativePath   = $Candidate.ServerRelativePath
        LastModifiedDateTime = $Candidate.LastModifiedDateTime
        OriginalBytes        = [long]$Candidate.SizeBytes
        CompressedBytes      = [long]0
        SavingsBytes         = [long]0
        SavingsPercent       = 0
        VersionCountBefore   = 0
        VersionsDeleted      = 0
        Engine               = $null
        Status               = $Status
        Error                = $null
    }
}

function Invoke-CIPPImageHttpWithRetry {
    <#
    .SYNOPSIS
        Runs a script block with simple exponential backoff for 429/503 throttling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 4
    )
    $Attempt = 0
    while ($true) {
        try {
            return & $ScriptBlock
        } catch {
            $Attempt++
            $StatusCode = $null
            try { $StatusCode = [int]$_.Exception.Response.StatusCode } catch {}
            $IsThrottle = ($StatusCode -eq 429 -or $StatusCode -eq 503 -or $_.Exception.Message -match '(?i)too many requests|temporarily unavailable')
            if (-not $IsThrottle -or $Attempt -ge $MaxRetries) {
                throw
            }
            $RetryAfter = $null
            try { $RetryAfter = [int]$_.Exception.Response.Headers['Retry-After'] } catch {}
            $Delay = if ($RetryAfter -and $RetryAfter -gt 0) { $RetryAfter } else { [math]::Pow(2, $Attempt) }
            Start-Sleep -Seconds $Delay
        }
    }
}

function Get-ImageOptimizerUploadError {
    [CmdletBinding()]
    param($Exception)
    $Message = $Exception.Exception.Message
    $StatusCode = $null
    try { $StatusCode = [int]$Exception.Exception.Response.StatusCode } catch {}
    if ($StatusCode -eq 423 -or $Message -match '(?i)locked|checked out|check out') {
        return [PSCustomObject]@{ Status = 'Skipped: locked'; Message = "File is locked or checked out: $Message" }
    }
    if ($Message -match '(?i)retention|hold|read-?only|cannot be modified') {
        return [PSCustomObject]@{ Status = 'Skipped: locked'; Message = "File blocked by retention/hold or is read-only: $Message" }
    }
    return [PSCustomObject]@{ Status = 'Failed'; Message = "Upload failed: $Message" }
}
