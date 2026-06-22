function Get-CIPPSharePointImageCandidate {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Recursively scans a SharePoint document library (drive) for large JPG/JPEG files.
    .DESCRIPTION
        Walks the drive folder tree (via Microsoft Graph, app-only) and returns JPG/JPEG
        files that are at or above the supplied minimum size threshold. Used by the
        SharePoint Image Optimizer audit and optimize endpoints.

        Only .jpg and .jpeg (case-insensitive) files are returned. The function reports
        the total number of files scanned so callers can build accurate summaries.

        Paging is handled by New-GraphGetRequest (follows @odata.nextLink). Folder
        recursion is bounded by MaxDepth. A MaxFiles cap can stop discovery early on very
        large libraries.
    .PARAMETER TenantFilter
        Tenant default domain / id.
    .PARAMETER DriveId
        The target document library drive id.
    .PARAMETER MinimumFileSizeMB
        Minimum size (in MB) for a JPG to be considered a candidate. Default 5.
    .PARAMETER FolderId
        Folder item id to scan from. Defaults to 'root'.
    .PARAMETER IncludeSubfolders
        Recurse into subfolders. Default $true.
    .PARAMETER MaxFiles
        Optional cap on the number of candidate files to return. 0 = no cap.
    .PARAMETER MaxDepth
        Maximum recursion depth. Default 20.
    .PARAMETER CurrentDepth
        Internal recursion counter. Do not set manually.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $false)]
        [double]$MinimumFileSizeMB = 5,

        [Parameter(Mandatory = $false)]
        [string]$FolderId = 'root',

        [Parameter(Mandatory = $false)]
        [bool]$IncludeSubfolders = $true,

        [Parameter(Mandatory = $false)]
        [int]$MaxFiles = 0,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 20,

        [Parameter(Mandatory = $false)]
        [int]$CurrentDepth = 0
    )

    $Candidates = [System.Collections.Generic.List[object]]::new()
    $FilesScanned = 0

    if ($CurrentDepth -ge $MaxDepth) {
        return [PSCustomObject]@{ Candidates = @(); FilesScanned = 0 }
    }

    $ThresholdBytes = [long]([math]::Round($MinimumFileSizeMB * 1MB))
    $Select = 'id,name,size,file,folder,parentReference,webUrl,lastModifiedDateTime,createdDateTime'
    $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$FolderId/children?`$top=200&`$select=$Select"

    try {
        $Items = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
        $Items = @($Items) | Where-Object { $_.id }

        foreach ($Item in $Items) {
            if ($MaxFiles -gt 0 -and $Candidates.Count -ge $MaxFiles) { break }

            if ($Item.folder) {
                if ($IncludeSubfolders) {
                    $Sub = Get-CIPPSharePointImageCandidate -TenantFilter $TenantFilter -DriveId $DriveId `
                        -MinimumFileSizeMB $MinimumFileSizeMB -FolderId $Item.id -IncludeSubfolders $IncludeSubfolders `
                        -MaxFiles $MaxFiles -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                    $FilesScanned += $Sub.FilesScanned
                    if ($Sub.Candidates) {
                        foreach ($Cand in $Sub.Candidates) {
                            if ($MaxFiles -gt 0 -and $Candidates.Count -ge $MaxFiles) { break }
                            $Candidates.Add($Cand)
                        }
                    }
                }
                continue
            }

            if (-not $Item.file) { continue }
            $FilesScanned++

            # Only .jpg / .jpeg, case-insensitive.
            if ($Item.name -notmatch '(?i)\.(jpe?g)$') { continue }
            $Extension = ($Matches[1]).ToLower()

            $SizeBytes = [long]($Item.size ?? 0)
            $ParentPath = if ($Item.parentReference.path) {
                $Item.parentReference.path -replace '^/drive/root:', '' -replace '^/drives/[^/]+/root:', ''
            } else { '' }
            $ServerRelative = if ($ParentPath) { "$ParentPath/$($Item.name)" } else { "/$($Item.name)" }

            $SkipReason = $null
            if ($SizeBytes -lt $ThresholdBytes) {
                $SkipReason = 'Skipped: below threshold'
            }

            $Candidates.Add([PSCustomObject]@{
                FileName             = $Item.name
                Extension            = $Extension
                DriveItemId          = $Item.id
                DriveId              = $DriveId
                ParentId             = $Item.parentReference.id
                ParentPath           = $ParentPath
                WebUrl               = $Item.webUrl
                ServerRelativePath   = $ServerRelative
                SizeBytes            = $SizeBytes
                LastModifiedDateTime = $Item.lastModifiedDateTime
                CreatedDateTime      = $Item.createdDateTime
                Eligible             = ($null -eq $SkipReason)
                SkipReason           = $SkipReason
            })
        }
    } catch {
        Write-Warning "Get-CIPPSharePointImageCandidate: failed to list folder $FolderId in drive $DriveId - $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Candidates   = @($Candidates)
        FilesScanned = $FilesScanned
    }
}
