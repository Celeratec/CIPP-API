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

    # Cross-drive destination parameters
    $DestinationDriveId = $Request.Body.DestinationDriveId
    $DestinationUserId = $Request.Body.DestinationUserId
    $DestinationSiteId = $Request.Body.DestinationSiteId

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

            'CrossCopy' {
                if (-not $ItemId) { throw 'ItemId is required for CrossCopy action' }

                # Resolve destination drive
                $DestDriveId = $DestinationDriveId
                if (-not $DestDriveId) {
                    if ($DestinationUserId) {
                        $DestUserDrive = New-GraphGetRequest `
                            -uri "https://graph.microsoft.com/v1.0/users/$DestinationUserId/drive?`$select=id" `
                            -tenantid $TenantFilter -asApp $true
                        $DestDriveId = $DestUserDrive.id
                    } elseif ($DestinationSiteId) {
                        $DestDrives = New-GraphGetRequest `
                            -uri "https://graph.microsoft.com/v1.0/sites/$DestinationSiteId/drives" `
                            -tenantid $TenantFilter -asApp $true
                        $DestDriveId = ($DestDrives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
                        if (-not $DestDriveId) { $DestDriveId = $DestDrives[0].id }
                    }
                }
                if (-not $DestDriveId) { throw 'DestinationDriveId, DestinationUserId, or DestinationSiteId is required for CrossCopy' }

                $DestinationFolderId = $Request.Body.DestinationFolderId
                if ($DestinationFolderId -is [hashtable] -or $DestinationFolderId -is [PSCustomObject]) {
                    $DestinationFolderId = $DestinationFolderId.value
                }

                # Build the parent reference for the destination drive
                $CopyBody = @{
                    parentReference = @{
                        driveId = $DestDriveId
                    }
                }
                if ($DestinationFolderId) {
                    $CopyBody['parentReference']['id'] = $DestinationFolderId
                } else {
                    # Resolve root folder id of destination drive
                    $DestRoot = New-GraphGetRequest `
                        -uri "https://graph.microsoft.com/v1.0/drives/$DestDriveId/root?`$select=id" `
                        -tenantid $TenantFilter -asApp $true
                    $CopyBody['parentReference']['id'] = $DestRoot.id
                }

                $Body = $CopyBody | ConvertTo-Json -Depth 3
                $null = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/copy" `
                    -tenantid $TenantFilter -type POST -body $Body
                $Message = "Cross-drive copy of '$ItemLabel' has been initiated. This may take a moment to complete."
            }

            'CrossMove' {
                if (-not $ItemId) { throw 'ItemId is required for CrossMove action' }

                # Resolve destination drive
                $DestDriveId = $DestinationDriveId
                if (-not $DestDriveId) {
                    if ($DestinationUserId) {
                        $DestUserDrive = New-GraphGetRequest `
                            -uri "https://graph.microsoft.com/v1.0/users/$DestinationUserId/drive?`$select=id" `
                            -tenantid $TenantFilter -asApp $true
                        $DestDriveId = $DestUserDrive.id
                    } elseif ($DestinationSiteId) {
                        $DestDrives = New-GraphGetRequest `
                            -uri "https://graph.microsoft.com/v1.0/sites/$DestinationSiteId/drives" `
                            -tenantid $TenantFilter -asApp $true
                        $DestDriveId = ($DestDrives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
                        if (-not $DestDriveId) { $DestDriveId = $DestDrives[0].id }
                    }
                }
                if (-not $DestDriveId) { throw 'DestinationDriveId, DestinationUserId, or DestinationSiteId is required for CrossMove' }

                $DestinationFolderId = $Request.Body.DestinationFolderId
                if ($DestinationFolderId -is [hashtable] -or $DestinationFolderId -is [PSCustomObject]) {
                    $DestinationFolderId = $DestinationFolderId.value
                }

                # Build the parent reference for the destination drive
                $CopyBody = @{
                    parentReference = @{
                        driveId = $DestDriveId
                    }
                }
                if ($DestinationFolderId) {
                    $CopyBody['parentReference']['id'] = $DestinationFolderId
                } else {
                    $DestRoot = New-GraphGetRequest `
                        -uri "https://graph.microsoft.com/v1.0/drives/$DestDriveId/root?`$select=id" `
                        -tenantid $TenantFilter -asApp $true
                    $CopyBody['parentReference']['id'] = $DestRoot.id
                }

                # Step 1: Copy to destination drive
                $Body = $CopyBody | ConvertTo-Json -Depth 3
                $CopyResponse = New-GraphPostRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/copy" `
                    -tenantid $TenantFilter -type POST -body $Body

                # Step 2: Poll the copy monitor URL until complete, then delete source
                # The Graph copy API returns a Location header with a monitor URL.
                # We attempt to wait for completion before deleting the source.
                $MonitorUrl = $null
                if ($CopyResponse -and $CopyResponse.'Location') {
                    $MonitorUrl = $CopyResponse.'Location'
                }

                $CopyComplete = $false
                if ($MonitorUrl) {
                    for ($i = 0; $i -lt 30; $i++) {
                        Start-Sleep -Seconds 2
                        try {
                            $Status = Invoke-RestMethod -Uri $MonitorUrl -Method GET -ErrorAction Stop
                            if ($Status.status -eq 'completed') {
                                $CopyComplete = $true
                                break
                            } elseif ($Status.status -eq 'failed') {
                                throw "Copy operation failed: $($Status.error.message)"
                            }
                        } catch {
                            # If we can't reach the monitor URL, wait and retry
                            if ($_.Exception.Message -match 'Copy operation failed') { throw }
                        }
                    }
                } else {
                    # No monitor URL - wait a fixed period for small files
                    Start-Sleep -Seconds 5
                    $CopyComplete = $true
                }

                if ($CopyComplete) {
                    # Delete the source item
                    $null = New-GraphPostRequest -AsApp $true `
                        -uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId" `
                        -tenantid $TenantFilter -type DELETE -body '{}'
                    $Message = "Successfully moved '$ItemLabel' to the destination. The source has been removed."
                } else {
                    $Message = "Copy of '$ItemLabel' was initiated but is still in progress. The source item was NOT deleted. Please verify the copy completed and remove the source manually if needed."
                }
            }

            default {
                throw "Unknown action: $Action. Supported actions: Rename, Move, Copy, Delete, Download, CreateFolder, CrossCopy, CrossMove"
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
