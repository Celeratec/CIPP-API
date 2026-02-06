function Invoke-ListOneDriveFiles {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $TenantFilter = $Request.Query.TenantFilter
    $SiteId = $Request.Query.SiteId
    $FolderId = $Request.Query.FolderId
    $DriveId = $Request.Query.DriveId

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'TenantFilter is required'
        })
    }

    if (-not $SiteId -and -not $DriveId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'SiteId or DriveId is required'
        })
    }

    try {
        # Get the drive ID if not provided
        if (-not $DriveId) {
            $Drives = New-GraphGetRequest `
                -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives" `
                -tenantid $TenantFilter `
                -asApp $true
            if (-not $Drives -or $Drives.Count -eq 0) {
                throw 'No drives found for this site'
            }
            # Pick the primary document library drive
            $DriveId = ($Drives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
            if (-not $DriveId) {
                $DriveId = $Drives[0].id
            }
        }

        # List items in root or specified folder
        $SelectFields = 'id,name,size,lastModifiedDateTime,createdBy,folder,file,webUrl,parentReference'
        if ($FolderId) {
            $ItemsUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$FolderId/children?`$select=$SelectFields&`$top=999"
        } else {
            $ItemsUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/root/children?`$select=$SelectFields&`$top=999"
        }

        $Items = New-GraphGetRequest `
            -uri $ItemsUri `
            -tenantid $TenantFilter `
            -asApp $true

        $GraphRequest = foreach ($Item in $Items) {
            $IsFolder = $null -ne $Item.folder
            $SizeBytes = if ($Item.size) { $Item.size } else { 0 }
            $SizeFormatted = if ($SizeBytes -ge 1GB) {
                '{0:N2} GB' -f ($SizeBytes / 1GB)
            } elseif ($SizeBytes -ge 1MB) {
                '{0:N2} MB' -f ($SizeBytes / 1MB)
            } elseif ($SizeBytes -ge 1KB) {
                '{0:N1} KB' -f ($SizeBytes / 1KB)
            } else {
                "$SizeBytes B"
            }

            [PSCustomObject]@{
                id               = $Item.id
                name             = $Item.name
                isFolder         = $IsFolder
                type             = if ($IsFolder) { 'Folder' } else { 'File' }
                sizeInBytes      = $SizeBytes
                sizeFormatted    = if ($IsFolder) { "$($Item.folder.childCount) items" } else { $SizeFormatted }
                childCount       = if ($IsFolder) { $Item.folder.childCount } else { $null }
                lastModified     = $Item.lastModifiedDateTime
                createdBy        = $Item.createdBy.user.displayName
                webUrl           = $Item.webUrl
                fileExtension    = if (-not $IsFolder -and $Item.name -match '\.(\w+)$') { $Matches[1].ToLower() } else { $null }
                parentId         = $Item.parentReference.id
                parentPath       = $Item.parentReference.path
                driveId          = $DriveId
            }
        }

        # Sort folders first, then files alphabetically
        $GraphRequest = @($GraphRequest | Sort-Object -Property @{Expression = { -not $_.isFolder }}, @{Expression = { $_.name }})

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $GraphRequest = $ErrorMessage
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @($GraphRequest)
    })
}
