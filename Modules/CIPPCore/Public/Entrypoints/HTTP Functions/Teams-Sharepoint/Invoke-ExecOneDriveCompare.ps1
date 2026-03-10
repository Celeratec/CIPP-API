function Invoke-ExecOneDriveCompare {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Body.TenantFilter
    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    $SourceDriveId = $Request.Body.SourceDriveId
    $SourceUserId = $Request.Body.SourceUserId
    $SourceSiteId = $Request.Body.SourceSiteId
    $SourceFolderId = $Request.Body.SourceFolderId

    $DestDriveId = $Request.Body.DestDriveId
    $DestUserId = $Request.Body.DestUserId
    $DestSiteId = $Request.Body.DestSiteId
    $DestFolderId = $Request.Body.DestFolderId

    $MaxDepth = $Request.Body.MaxDepth
    if (-not $MaxDepth) { $MaxDepth = 10 }

    try {
        # Resolve source drive
        if (-not $SourceDriveId) {
            if ($SourceUserId) {
                $SrcDrive = New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/users/$SourceUserId/drive?`$select=id" `
                    -tenantid $TenantFilter
                $SourceDriveId = $SrcDrive.id
            } elseif ($SourceSiteId) {
                $SrcDrives = New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/sites/$SourceSiteId/drives" `
                    -tenantid $TenantFilter
                $SourceDriveId = ($SrcDrives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
                if (-not $SourceDriveId) { $SourceDriveId = $SrcDrives[0].id }
            }
        }
        if (-not $SourceDriveId) {
            throw 'Source drive could not be resolved. Provide SourceDriveId, SourceUserId, or SourceSiteId.'
        }

        # Resolve destination drive
        if (-not $DestDriveId) {
            if ($DestUserId) {
                $DstDrive = New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/users/$DestUserId/drive?`$select=id" `
                    -tenantid $TenantFilter
                $DestDriveId = $DstDrive.id
            } elseif ($DestSiteId) {
                $DstDrives = New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/sites/$DestSiteId/drives" `
                    -tenantid $TenantFilter
                $DestDriveId = ($DstDrives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1).id
                if (-not $DestDriveId) { $DestDriveId = $DstDrives[0].id }
            }
        }
        if (-not $DestDriveId) {
            throw 'Destination drive could not be resolved. Provide DestDriveId, DestUserId, or DestSiteId.'
        }

        # Resolve source root if no folder specified
        if (-not $SourceFolderId) {
            $SrcRoot = New-GraphGetRequest -AsApp $true `
                -uri "https://graph.microsoft.com/v1.0/drives/$SourceDriveId/root?`$select=id" `
                -tenantid $TenantFilter
            $SourceFolderId = $SrcRoot.id
        }
        if (-not $DestFolderId) {
            $DstRoot = New-GraphGetRequest -AsApp $true `
                -uri "https://graph.microsoft.com/v1.0/drives/$DestDriveId/root?`$select=id" `
                -tenantid $TenantFilter
            $DestFolderId = $DstRoot.id
        }

        $DiffEntries = [System.Collections.Generic.List[object]]::new()
        $Counters = @{ match = 0 }

        function Get-FolderDiff {
            param(
                [string]$SrcDrive,
                [string]$SrcFolder,
                [string]$DstDrive,
                [string]$DstFolder,
                [string]$Tenant,
                [string]$PathPrefix,
                [int]$CurrentDepth,
                [int]$MaxDepth
            )

            if ($CurrentDepth -ge $MaxDepth) { return }

            try {
                $SrcItems = @(New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$SrcDrive/items/$SrcFolder/children?`$select=id,name,size,folder&`$top=200" `
                    -tenantid $Tenant -noPagination $true)
            } catch { $SrcItems = @() }

            try {
                $DstItems = @(New-GraphGetRequest -AsApp $true `
                    -uri "https://graph.microsoft.com/v1.0/drives/$DstDrive/items/$DstFolder/children?`$select=id,name,size,folder&`$top=200" `
                    -tenantid $Tenant -noPagination $true)
            } catch { $DstItems = @() }

            $SrcLookup = @{}
            foreach ($s in $SrcItems) { $SrcLookup[$s.name] = $s }

            $DstLookup = @{}
            foreach ($d in $DstItems) { $DstLookup[$d.name] = $d }

            $AllNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($s in $SrcItems) { $null = $AllNames.Add($s.name) }
            foreach ($d in $DstItems) { $null = $AllNames.Add($d.name) }

            foreach ($ItemName in ($AllNames | Sort-Object)) {
                $Src = $SrcLookup[$ItemName]
                $Dst = $DstLookup[$ItemName]
                $ItemPath = if ($PathPrefix) { "$PathPrefix/$ItemName" } else { $ItemName }
                $SrcIsFolder = ($null -ne $Src) -and ($null -ne $Src.folder)
                $DstIsFolder = ($null -ne $Dst) -and ($null -ne $Dst.folder)

                if ($Src -and -not $Dst) {
                    $DiffEntries.Add([PSCustomObject]@{
                        path         = $ItemPath
                        name         = $ItemName
                        type         = if ($SrcIsFolder) { 'folder' } else { 'file' }
                        status       = 'source_only'
                        sourceId     = $Src.id
                        sourceSize   = [long]($Src.size ?? 0)
                        destId       = $null
                        destSize     = $null
                        sourceDriveId = $SrcDrive
                        destDriveId  = $DstDrive
                        destParentId = $DstFolder
                    })
                } elseif ($Dst -and -not $Src) {
                    $DiffEntries.Add([PSCustomObject]@{
                        path         = $ItemPath
                        name         = $ItemName
                        type         = if ($DstIsFolder) { 'folder' } else { 'file' }
                        status       = 'dest_only'
                        sourceId     = $null
                        sourceSize   = $null
                        destId       = $Dst.id
                        destSize     = [long]($Dst.size ?? 0)
                        sourceDriveId = $SrcDrive
                        destDriveId  = $DstDrive
                        sourceParentId = $SrcFolder
                    })
                } elseif ($SrcIsFolder -and $DstIsFolder) {
                    Get-FolderDiff `
                        -SrcDrive $SrcDrive -SrcFolder $Src.id `
                        -DstDrive $DstDrive -DstFolder $Dst.id `
                        -Tenant $Tenant -PathPrefix $ItemPath `
                        -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
                } elseif (-not $SrcIsFolder -and -not $DstIsFolder) {
                    $SrcSize = [long]($Src.size ?? 0)
                    $DstSize = [long]($Dst.size ?? 0)
                    if ($SrcSize -ne $DstSize) {
                        $DiffEntries.Add([PSCustomObject]@{
                            path         = $ItemPath
                            name         = $ItemName
                            type         = 'file'
                            status       = 'size_differs'
                            sourceId     = $Src.id
                            sourceSize   = $SrcSize
                            destId       = $Dst.id
                            destSize     = $DstSize
                            sourceDriveId = $SrcDrive
                            destDriveId  = $DstDrive
                        })
                    } else {
                        $Counters.match++
                    }
                }
            }
        }

        Get-FolderDiff `
            -SrcDrive $SourceDriveId -SrcFolder $SourceFolderId `
            -DstDrive $DestDriveId -DstFolder $DestFolderId `
            -Tenant $TenantFilter -PathPrefix '' `
            -CurrentDepth 0 -MaxDepth $MaxDepth

        $Body = @{
            Results        = @($DiffEntries)
            SourceDriveId  = $SourceDriveId
            DestDriveId    = $DestDriveId
            SourceFolderId = $SourceFolderId
            DestFolderId   = $DestFolderId
            MatchCount     = $Counters.match
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $Body = @{ Results = "Comparison failed: $ErrorMessage" }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
