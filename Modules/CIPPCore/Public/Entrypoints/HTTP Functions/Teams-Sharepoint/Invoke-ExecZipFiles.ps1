function Invoke-ExecZipFiles {
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

    $Items = $Request.Body.Items
    $ZipFileName = $Request.Body.ZipFileName
    if (-not $ZipFileName) { $ZipFileName = "CIPP-Archive-$(Get-Date -Format 'yyyy-MM-dd').zip" }

    $DestinationUserId = $Request.Body.DestinationUserId
    $DestinationSiteId = $Request.Body.DestinationSiteId
    $DestinationFolderId = $Request.Body.DestinationFolderId
    $HasDestination = $DestinationUserId -or $DestinationSiteId

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::BadRequest
            ContentType = 'application/json'
            Body        = @{ Results = 'TenantFilter is required' }
        })
    }

    if (-not $Items -or $Items.Count -eq 0) {
        return ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::BadRequest
            ContentType = 'application/json'
            Body        = @{ Results = 'Items array is required and must not be empty' }
        })
    }

    $MaxItems = 100
    if ($Items.Count -gt $MaxItems) {
        return ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::BadRequest
            ContentType = 'application/json'
            Body        = @{ Results = "Too many items. Maximum is $MaxItems, received $($Items.Count)." }
        })
    }

    try {
        Add-Type -AssemblyName System.IO.Compression

        $MemStream = [System.IO.MemoryStream]::new()
        $ZipArchive = [System.IO.Compression.ZipArchive]::new($MemStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)

        $FileCount = 0
        $TotalBytes = [long]0
        $MaxTotalBytes = 500MB
        $Errors = [System.Collections.Generic.List[string]]::new()

        foreach ($Item in $Items) {
            $ItemDriveId = $Item.DriveId
            $ItemItemId = $Item.ItemId
            $ItemName = $Item.Name

            if (-not $ItemDriveId -or -not $ItemItemId) {
                $Errors.Add("Skipped item '$ItemName': missing DriveId or ItemId")
                continue
            }

            try {
                $GraphItem = New-GraphGetRequest `
                    -uri "https://graph.microsoft.com/v1.0/drives/$ItemDriveId/items/$ItemItemId" `
                    -tenantid $TenantFilter -asApp $true

                $DownloadUrl = $GraphItem.'@microsoft.graph.downloadUrl'
                if (-not $DownloadUrl) {
                    $Errors.Add("Skipped '$($GraphItem.name ?? $ItemName)': no download URL (may be a folder)")
                    continue
                }

                $FileName = $GraphItem.name ?? $ItemName
                $FileSize = [long]($GraphItem.size ?? 0)

                if (($TotalBytes + $FileSize) -gt $MaxTotalBytes) {
                    $Errors.Add("Skipped '$FileName': adding it would exceed the 500 MB limit")
                    continue
                }

                $FileBytes = Invoke-RestMethod -Uri $DownloadUrl -Method GET -ErrorAction Stop

                if ($FileBytes -is [string]) {
                    $FileBytes = [System.Text.Encoding]::UTF8.GetBytes($FileBytes)
                }

                $Entry = $ZipArchive.CreateEntry($FileName, [System.IO.Compression.CompressionLevel]::Fastest)
                $EntryStream = $Entry.Open()
                try {
                    $EntryStream.Write($FileBytes, 0, $FileBytes.Length)
                } finally {
                    $EntryStream.Close()
                }

                $FileCount++
                $TotalBytes += $FileBytes.Length
            } catch {
                $Errors.Add("Failed to download '$ItemName': $($_.Exception.Message)")
            }
        }

        $ZipArchive.Dispose()

        if ($FileCount -eq 0) {
            $MemStream.Dispose()
            $ErrDetail = if ($Errors.Count -gt 0) { " Errors: $($Errors -join '; ')" } else { '' }
            throw "No files could be added to the zip.$ErrDetail"
        }

        $ZipBytes = $MemStream.ToArray()
        $MemStream.Dispose()

        $SizeMB = [math]::Round($ZipBytes.Length / 1MB, 1)
        $Summary = "$FileCount file$(if ($FileCount -ne 1) { 's' }) ($SizeMB MB)"

        if ($HasDestination) {
            $DestDriveId = $null
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

            if (-not $DestDriveId) {
                throw 'Could not resolve destination drive'
            }

            $UploadPath = if ($DestinationFolderId) {
                "https://graph.microsoft.com/v1.0/drives/$DestDriveId/items/${DestinationFolderId}:/${ZipFileName}:/content"
            } else {
                "https://graph.microsoft.com/v1.0/drives/$DestDriveId/root:/${ZipFileName}:/content"
            }

            $Token = Get-GraphToken -tenantid $TenantFilter -AsApp $true
            $UploadHeaders = @{
                Authorization  = "Bearer $($Token.access_token)"
                'Content-Type' = 'application/zip'
            }
            $null = Invoke-RestMethod -Uri $UploadPath -Method PUT -Headers $UploadHeaders -Body $ZipBytes -ErrorAction Stop

            $Message = "Successfully saved '$ZipFileName' ($Summary) to the destination."
            if ($Errors.Count -gt 0) {
                $Message += " Warnings: $($Errors -join '; ')"
            }

            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info

            return ([HttpResponseContext]@{
                StatusCode  = [HttpStatusCode]::OK
                ContentType = 'application/json'
                Body        = @{ Results = $Message }
            })
        } else {
            $Base64 = [Convert]::ToBase64String($ZipBytes)

            $Message = "Zip created with $Summary"
            if ($Errors.Count -gt 0) {
                $Message += " (warnings: $($Errors -join '; '))"
            }

            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Zip download: $Summary" -Sev Info

            return ([HttpResponseContext]@{
                StatusCode  = [HttpStatusCode]::OK
                ContentType = 'application/json'
                Body        = @{
                    Results     = $Message
                    zipBase64   = $Base64
                    zipFileName = $ZipFileName
                }
            })
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to create zip. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage

        return ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::InternalServerError
            ContentType = 'application/json'
            Body        = @{ Results = $Message }
        })
    }
}
