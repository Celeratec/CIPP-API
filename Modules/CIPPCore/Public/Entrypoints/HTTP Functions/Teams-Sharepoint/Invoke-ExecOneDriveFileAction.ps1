function Invoke-ExecOneDriveFileAction {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.TenantFilter
    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }

    $DriveId = $Request.Body.DriveId
    $ItemId = $Request.Body.ItemId
    $Action = $Request.Body.Action
    $UserId = $Request.Body.UserId
    $SiteId = $Request.Body.SiteId
    $ItemName = $Request.Body.ItemName

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    # Resolve DriveId from UserId or SiteId if not directly provided
    if (-not $DriveId) {
        try {
            if ($UserId) {
                $UserDrive = New-GraphGetRequest `
                    -uri "https://graph.microsoft.com/v1.0/users/$UserId/drive?`$select=id" `
                    -tenantid $TenantFilter -asApp $true
                $DriveId = $UserDrive.id
            } elseif ($SiteId) {
                $Drives = New-GraphGetRequest `
                    -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives" `
                    -tenantid $TenantFilter -asApp $true
                $DriveId = ($Drives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
                if (-not $DriveId) { $DriveId = $Drives[0].id }
            }
        } catch {
            $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Forbidden
                Body       = @{ Results = "Failed to resolve drive: $ErrorMessage" }
            })
        }
    }

    if (-not $DriveId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'DriveId, UserId, or SiteId is required to identify the drive' }
        })
    }

    # Ensure ItemId is a clean string (not an object, not whitespace-padded)
    if ($ItemId -and $ItemId -isnot [string]) {
        $ItemId = [string]$ItemId
    }
    if ($ItemId) { $ItemId = $ItemId.Trim() }

    $ItemLabel = if ($ItemName) { $ItemName } else { $ItemId }

    try {
        switch ($Action) {
            'Rename' {
                $NewName = $Request.Body.NewName
                if (-not $NewName) { throw 'NewName is required for Rename action' }
                if (-not $ItemId) { throw 'ItemId is required for Rename action' }

                $Body = @{ name = $NewName } | ConvertTo-Json
                $null = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId" `
                    -tenantid $TenantFilter -type PATCH -body $Body
                $Message = "Successfully renamed '$ItemLabel' to '$NewName'"
            }

            'Move' {
                $DestinationFolderId = $Request.Body.DestinationFolderId
                if (-not $DestinationFolderId) { throw 'DestinationFolderId is required for Move action' }
                if (-not $ItemId) { throw 'ItemId is required for Move action' }

                # Support autocomplete field format
                if ($DestinationFolderId -is [hashtable] -or $DestinationFolderId -is [PSCustomObject]) {
                    $DestinationFolderId = $DestinationFolderId.value
                }

                $Body = @{
                    parentReference = @{
                        id = $DestinationFolderId
                    }
                } | ConvertTo-Json -Depth 3
                $null = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId" `
                    -tenantid $TenantFilter -type PATCH -body $Body
                $Message = "Successfully moved '$ItemLabel' to the selected folder"
            }

            'Copy' {
                $DestinationFolderId = $Request.Body.DestinationFolderId
                $CopyName = $Request.Body.CopyName
                if (-not $ItemId) { throw 'ItemId is required for Copy action' }

                $CopyBody = @{}
                if ($CopyName) {
                    $CopyBody['name'] = $CopyName
                }
                if ($DestinationFolderId) {
                    if ($DestinationFolderId -is [hashtable] -or $DestinationFolderId -is [PSCustomObject]) {
                        $DestinationFolderId = $DestinationFolderId.value
                    }
                    $CopyBody['parentReference'] = @{
                        driveId = $DriveId
                        id      = $DestinationFolderId
                    }
                }

                if ($CopyBody.Count -eq 0) {
                    # Default: copy in same location with " - Copy" suffix
                    $OriginalName = $ItemLabel
                    if ($OriginalName -match '^(.+)(\.[^.]+)$') {
                        $CopyBody['name'] = "$($Matches[1]) - Copy$($Matches[2])"
                    } else {
                        $CopyBody['name'] = "$OriginalName - Copy"
                    }
                }

                $Body = $CopyBody | ConvertTo-Json -Depth 3
                $null = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/copy" `
                    -tenantid $TenantFilter -type POST -body $Body

                $CopyLabel = if ($CopyName) { $CopyName } elseif ($CopyBody['name']) { $CopyBody['name'] } else { $ItemLabel }
                $Message = "Copy of '$ItemLabel' started as '$CopyLabel'. This may take a moment to complete."
            }

            'Delete' {
                if (-not $ItemId) { throw 'ItemId is required for Delete action' }

                $null = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId" `
                    -tenantid $TenantFilter -type DELETE -body '{}'
                $Message = "Successfully deleted '$ItemLabel'. It has been moved to the OneDrive recycle bin."
            }

            'Download' {
                if (-not $ItemId) { throw 'ItemId is required for Download action' }

                # Get the item metadata - the @microsoft.graph.downloadUrl annotation
                # is returned automatically and must NOT be included in $select
                $Item = New-GraphGetRequest `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId" `
                    -tenantid $TenantFilter -asApp $true

                $DownloadUrl = $Item.'@microsoft.graph.downloadUrl'
                if (-not $DownloadUrl) {
                    throw "Could not obtain download URL for '$ItemLabel'. This may be a folder or a restricted item."
                }

                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{
                        Results     = "Download link generated for '$($Item.name)'. The link is valid for a short time."
                        downloadUrl = $DownloadUrl
                        fileName    = $Item.name
                    }
                })
            }

            'CreateFolder' {
                $FolderName = $Request.Body.FolderName
                $ParentId = $Request.Body.ParentId
                if (-not $FolderName) { throw 'FolderName is required for CreateFolder action' }

                # If no ParentId, create at root
                $ParentPath = if ($ParentId) {
                    "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ParentId/children"
                } else {
                    "https://graph.microsoft.com/v1.0/drives/$DriveId/root/children"
                }

                $Body = @{
                    name                              = $FolderName
                    folder                            = @{}
                    '@microsoft.graph.conflictBehavior' = 'rename'
                } | ConvertTo-Json -Depth 3

                $null = New-GraphPostRequest -AsApp $true `
                    -uri $ParentPath `
                    -tenantid $TenantFilter -type POST -body $Body
                $Message = "Successfully created folder '$FolderName'"
            }

            default {
                throw "Unknown action: $Action. Supported actions: Rename, Move, Copy, Delete, Download, CreateFolder"
            }
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to $Action '$ItemLabel'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
