function Get-CIPPDriveTempFile {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Enumerates a SharePoint/OneDrive drive for temp/junk files using Graph delta.
    .DESCRIPTION
        Uses the drive `root/delta` endpoint to enumerate every item in the drive as a flat,
        paginated stream instead of walking the folder tree one folder at a time. This turns a
        latency-bound recursion (one request per folder, serially) into a small number of large
        pages, so very large drives can be scanned within the queue worker's execution window.

        New-GraphGetRequest follows `@odata.nextLink` automatically and stops at the trailing
        `@odata.deltaLink`, so a single call returns the whole drive. Folders, deleted items, and
        items that match no enabled filter are ignored.
    .PARAMETER TenantFilter
        Tenant default domain / id.
    .PARAMETER DriveId
        The target drive id (document library or OneDrive).
    .PARAMETER Filters
        Object describing which temp/junk categories to match (see Test-CIPPTempFileMatch).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $false)]
        $Filters
    )

    if (-not $Filters) {
        $Filters = [PSCustomObject]@{
            officeTemp    = $true
            tempFiles     = $true
            zeroByteFiles = $true
            systemJunk    = $true
            backupFiles   = $false
        }
    }

    $HasFilters = $Filters.officeTemp -or $Filters.tempFiles -or $Filters.zeroByteFiles -or $Filters.systemJunk -or $Filters.backupFiles
    if (-not $HasFilters) {
        return @()
    }

    $Results = [System.Collections.Generic.List[object]]::new()
    $Select = 'id,name,size,folder,file,parentReference,webUrl,lastModifiedDateTime,deleted'
    $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/root/delta?`$select=$Select&`$top=2000"

    $Items = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
    foreach ($Item in @($Items)) {
        if (-not $Item.id -or $Item.deleted -or -not $Item.file) { continue }

        $MatchTypes = Test-CIPPTempFileMatch -Item $Item -Filters $Filters
        if ($MatchTypes.Count -eq 0) { continue }

        $ParentPath = if ($Item.parentReference.path) {
            $Item.parentReference.path -replace '^/drives/[^/]+/root:', '' -replace '^/drive/root:', ''
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

    return @($Results)
}
