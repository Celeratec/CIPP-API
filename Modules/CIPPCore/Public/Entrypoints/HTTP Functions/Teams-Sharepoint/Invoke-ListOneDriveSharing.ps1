function Invoke-ListOneDriveSharing {
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
            $DriveId = ($Drives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
            if (-not $DriveId) {
                $DriveId = $Drives[0].id
            }
        }

        # Search for all items and check for the shared facet
        $SearchUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/root/search(q='*')?`$select=id,name,size,webUrl,shared,lastModifiedDateTime,createdBy,file,folder&`$top=999"
        $AllItems = New-GraphGetRequest `
            -uri $SearchUri `
            -tenantid $TenantFilter `
            -asApp $true

        # Filter to only items that have the shared facet
        $SharedItems = $AllItems | Where-Object { $null -ne $_.shared }

        # For each shared item, get its permissions to show who it's shared with
        $GraphRequest = foreach ($Item in $SharedItems) {
            $PermUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$($Item.id)/permissions"
            try {
                $Permissions = New-GraphGetRequest `
                    -uri $PermUri `
                    -tenantid $TenantFilter `
                    -asApp $true
            } catch {
                $Permissions = @()
            }

            # Build a list of who it's shared with
            $SharedWithList = foreach ($Perm in $Permissions) {
                if ($Perm.link) {
                    $LinkType = $Perm.link.type
                    $LinkScope = $Perm.link.scope
                    "$LinkScope $LinkType link"
                } elseif ($Perm.grantedToV2) {
                    if ($Perm.grantedToV2.user) {
                        $Perm.grantedToV2.user.displayName
                    } elseif ($Perm.grantedToV2.group) {
                        $Perm.grantedToV2.group.displayName
                    }
                } elseif ($Perm.grantedTo) {
                    if ($Perm.grantedTo.user) {
                        $Perm.grantedTo.user.displayName
                    }
                }
            }

            $IsFolder = $null -ne $Item.folder

            [PSCustomObject]@{
                id              = $Item.id
                name            = $Item.name
                type            = if ($IsFolder) { 'Folder' } else { 'File' }
                webUrl          = $Item.webUrl
                sharedDateTime  = $Item.shared.sharedDateTime
                sharedBy        = $Item.shared.owner.user.displayName
                sharedWith      = ($SharedWithList | Select-Object -Unique) -join ', '
                permissionCount = ($Permissions | Measure-Object).Count
                lastModified    = $Item.lastModifiedDateTime
                driveId         = $DriveId
            }
        }

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $GraphRequest = @()
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @($GraphRequest)
    })
}
