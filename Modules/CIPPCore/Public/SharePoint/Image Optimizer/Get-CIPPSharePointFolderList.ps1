function Get-CIPPSharePointFolderList {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Lists folders within a SharePoint document library (drive) for folder pickers.
    .DESCRIPTION
        Walks the drive folder tree (Microsoft Graph, app-only) and returns folder items
        with their id and library-relative path. Recursion is bounded by MaxDepth and the
        total returned by MaxFolders to keep the picker responsive on large libraries.
    .PARAMETER TenantFilter
        Tenant default domain / id.
    .PARAMETER DriveId
        The target document library drive id.
    .PARAMETER FolderId
        Folder item id to list from. Defaults to 'root'.
    .PARAMETER MaxDepth
        Maximum recursion depth. Default 5.
    .PARAMETER MaxFolders
        Maximum number of folders to return. Default 1000.
    .PARAMETER ParentPath
        Internal: library-relative path of the current folder. Do not set manually.
    .PARAMETER CurrentDepth
        Internal recursion counter. Do not set manually.
    .PARAMETER Accumulator
        Internal collection used across recursion. Do not set manually.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $false)]
        [string]$FolderId = 'root',

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 5,

        [Parameter(Mandatory = $false)]
        [int]$MaxFolders = 1000,

        [Parameter(Mandatory = $false)]
        [string]$ParentPath = '',

        [Parameter(Mandatory = $false)]
        [int]$CurrentDepth = 0,

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.List[object]]$Accumulator
    )

    if (-not $Accumulator) { $Accumulator = [System.Collections.Generic.List[object]]::new() }
    if ($CurrentDepth -ge $MaxDepth -or $Accumulator.Count -ge $MaxFolders) {
        return $Accumulator
    }

    $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$FolderId/children?`$top=200&`$select=id,name,folder,webUrl,parentReference"
    try {
        $Items = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
        $Items = @($Items) | Where-Object { $_.id -and $_.folder }
        foreach ($Item in $Items) {
            if ($Accumulator.Count -ge $MaxFolders) { break }
            $Path = if ($ParentPath) { "$ParentPath/$($Item.name)" } else { $Item.name }
            $Accumulator.Add([PSCustomObject]@{
                    id          = $Item.id
                    name        = $Item.name
                    path        = $Path
                    webUrl      = $Item.webUrl
                    childCount  = [int]($Item.folder.childCount ?? 0)
                })
            $null = Get-CIPPSharePointFolderList -TenantFilter $TenantFilter -DriveId $DriveId -FolderId $Item.id `
                -MaxDepth $MaxDepth -MaxFolders $MaxFolders -ParentPath $Path -CurrentDepth ($CurrentDepth + 1) -Accumulator $Accumulator
        }
    } catch {
        Write-Warning "Get-CIPPSharePointFolderList: failed to list folder $FolderId in drive $DriveId - $($_.Exception.Message)"
    }

    return $Accumulator
}
