function Remove-CIPPDriveItemVersion {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Removes old versions of a SharePoint file, keeping the current version.
    .DESCRIPTION
        Reclaims storage held by SharePoint version history after a file has been replaced
        with a compressed copy. Used by the SharePoint Image Optimizer.

        IMPORTANT - why SharePoint REST and not Graph:
        Microsoft Graph officially supports list/get/download/restore of driveItem
        versions but does NOT officially support deleting a specific version. The reliable,
        supported mechanism is the SharePoint REST file versions API:
            {siteUrl}/_api/web/GetFileById('{uniqueId}')/versions/recycleAll()
            {siteUrl}/_api/web/GetFileById('{uniqueId}')/versions/deleteAll()
        SharePoint REST `_api/web/*` is DELEGATED-ONLY (no -AsApp); see the
        sharepoint-api-auth rule. The required delegated permission (AllSites.FullControl
        on the SharePoint Online resource) is already in SAMManifest.json.

        Safety rules:
          - The current / latest version is NEVER removed (recycleAll/deleteAll only act
            on previous versions).
          - Nothing is removed when WhatIf is $true.
          - Failures (retention hold, retention label, permission) are captured, not thrown.

        Cleanup modes:
          - none      : no-op.
          - recycle   : recycleAll() - previous versions go to the recycle bin (recoverable
                        until the recycle bin is purged or retention expires).
          - permanent : deleteAll() - previous versions are permanently removed and storage
                        is reclaimed immediately (not recoverable).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $true)]
        [string]$DriveItemId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('none', 'recycle', 'permanent')]
        [string]$CleanupMode = 'none',

        [Parameter(Mandatory = $false)]
        [bool]$WhatIf = $true
    )

    $Result = [PSCustomObject]@{
        VersionCountBefore = 0
        VersionsDeleted    = 0
        WhatIf             = $WhatIf
        CleanupMode        = $CleanupMode
        Warnings           = [System.Collections.Generic.List[string]]::new()
        Errors             = [System.Collections.Generic.List[string]]::new()
    }

    if ($CleanupMode -eq 'none') {
        return $Result
    }

    # 1. Version count via Graph (this read IS supported by Graph).
    $CountKnown = $false
    try {
        $Versions = New-GraphGetRequest `
            -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$DriveItemId/versions?`$select=id,lastModifiedDateTime,size" `
            -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
        $Versions = @($Versions) | Where-Object { $_.id }
        $Result.VersionCountBefore = $Versions.Count
        $CountKnown = $true
    } catch {
        $Result.Warnings.Add("Could not read version count: $($_.Exception.Message)")
    }

    if ($CountKnown -and $Result.VersionCountBefore -le 1) {
        # Only the current version exists (or none); nothing to clean up.
        return $Result
    }
    $OldVersionEstimate = if ($Result.VersionCountBefore -gt 1) { $Result.VersionCountBefore - 1 } else { 0 }

    # 2. Resolve the file's SharePoint identifiers (site URL + unique id).
    $SiteUrl = $null
    $UniqueId = $null
    try {
        $Item = New-GraphGetRequest `
            -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$DriveItemId?`$select=id,name,webUrl,sharepointIds" `
            -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
        $SiteUrl = $Item.sharepointIds.siteUrl
        $UniqueId = $Item.sharepointIds.listItemUniqueId
    } catch {
        $Result.Errors.Add("Could not resolve SharePoint identifiers for version cleanup: $($_.Exception.Message)")
        return $Result
    }

    if (-not $SiteUrl -or -not $UniqueId) {
        $Result.Errors.Add('SharePoint site URL or file unique id was unavailable; cannot clean up versions.')
        return $Result
    }

    # 3. WhatIf: report estimate, do nothing.
    if ($WhatIf) {
        $Result.VersionsDeleted = $OldVersionEstimate
        if ($CleanupMode -eq 'permanent') {
            $Result.Warnings.Add('Permanent version deletion (deleteAll) reclaims storage immediately and is not recoverable.')
        }
        return $Result
    }

    # 4. Execute via SharePoint REST (delegated, no -AsApp).
    try {
        $SharePointInfo = Get-SharePointAdminLink -Public $false -TenantFilter $TenantFilter
        $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
        $Operation = if ($CleanupMode -eq 'permanent') { 'deleteAll' } else { 'recycleAll' }
        $Uri = "$SiteUrl/_api/web/GetFileById('$UniqueId')/versions/$Operation()"
        $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }

        $null = New-GraphPOSTRequest -scope $SPScope -tenantid $TenantFilter -Uri $Uri -Type POST `
            -Body '' -ContentType 'application/json;odata=verbose' -AddedHeaders $SPHeaders

        $Result.VersionsDeleted = $OldVersionEstimate
        if (-not $CountKnown) {
            $Result.Warnings.Add('Version count was unavailable before cleanup; old versions were removed but the deleted count could not be determined.')
        }
        if ($CleanupMode -eq 'permanent') {
            $Result.Warnings.Add('Permanent version deletion (deleteAll) was used; removed versions are not recoverable.')
        } else {
            $Result.Warnings.Add('Versions were sent to the recycle bin (recycleAll); storage is reclaimed once the recycle bin is purged or its retention expires.')
        }
    } catch {
        $Result.Errors.Add("Version cleanup failed: $($_.Exception.Message)")
    }

    return $Result
}
