function Get-TempFilesRecursive {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Recursively scans a SharePoint/OneDrive drive for temporary and junk files
    .DESCRIPTION
        Traverses a drive's folder structure and identifies files matching various
        temp file patterns (Office temp files, .TMP files, zero-byte files, system junk, etc.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $false)]
        $Filters,

        [Parameter(Mandatory = $false)]
        [string]$FolderId = 'root',

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 10,

        [Parameter(Mandatory = $false)]
        [int]$CurrentDepth = 0
    )

    if ($CurrentDepth -ge $MaxDepth) {
        return @()
    }

    if (-not $Filters) {
        $Filters = [PSCustomObject]@{
            officeTemp     = $true
            tempFiles      = $true
            zeroByteFiles  = $true
            systemJunk     = $true
            backupFiles    = $false
        }
    }

    $HasFilters = $Filters.officeTemp -or $Filters.tempFiles -or $Filters.zeroByteFiles -or $Filters.systemJunk -or $Filters.backupFiles
    if (-not $HasFilters) {
        return @()
    }

    $Results = [System.Collections.Generic.List[object]]::new()
    $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$FolderId/children?`$top=200&`$select=id,name,size,folder,file,parentReference,webUrl,lastModifiedDateTime"

    try {
        $Response = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
        $Items = @($Response) | ForEach-Object { $_ } | Where-Object { $_.id }

        foreach ($Item in $Items) {
            if ($Item.folder) {
                $SubResults = Get-TempFilesRecursive -TenantFilter $TenantFilter -DriveId $DriveId -Filters $Filters -FolderId $Item.id -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                if ($SubResults) {
                    $Results.AddRange([object[]]@($SubResults))
                }
            } elseif ($Item.file) {
                $MatchTypes = @(Test-CIPPTempFileMatch -Item $Item -Filters $Filters)

                if ($MatchTypes.Count -gt 0) {
                    $ParentPath = if ($Item.parentReference.path) {
                        # Graph returns either /drive/root: or /drives/{driveId}/root: depending on the endpoint.
                        $Item.parentReference.path -replace '^/drive/root:', '' -replace '^/drives/[^/]+/root:', ''
                    } else { '' }

                    $Results.Add(@{
                        id                   = $Item.id
                        driveId              = $DriveId
                        name                 = $Item.name
                        path                 = if ($ParentPath) { "$ParentPath/$($Item.name)" } else { "/$($Item.name)" }
                        size                 = $Item.size
                        type                 = $MatchTypes[0]
                        matchTypes           = @($MatchTypes)
                        lastModifiedDateTime = $Item.lastModifiedDateTime
                        webUrl               = $Item.webUrl
                    })
                }
            }
        }
    } catch {
        Write-Warning "Get-TempFilesRecursive: Failed to list folder $FolderId in drive $DriveId - $_"
    }

    return @($Results)
}
