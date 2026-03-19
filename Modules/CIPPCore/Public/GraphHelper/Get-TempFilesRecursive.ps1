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
        [hashtable]$Filters = @{},

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

    $Results = [System.Collections.Generic.List[object]]::new()
    $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$FolderId/children?`$top=200"

    try {
        do {
            $Response = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
            $Items = if ($Response.value) { $Response.value } else { @($Response) | Where-Object { $_.id } }

            foreach ($Item in $Items) {
                if ($Item.folder) {
                    $SubResults = Get-TempFilesRecursive -TenantFilter $TenantFilter -DriveId $DriveId -Filters $Filters -FolderId $Item.id -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                    if ($SubResults) {
                        $Results.AddRange([object[]]@($SubResults))
                    }
                } elseif ($Item.file) {
                    $MatchTypes = [System.Collections.Generic.List[string]]::new()

                    if ($Filters.officeTemp -and $Item.name -match '^\~\$') {
                        $MatchTypes.Add('officeTemp')
                    }

                    if ($Filters.tempFiles -and $Item.name -match '\.(TMP|temp)$') {
                        $MatchTypes.Add('tempFiles')
                    }

                    if ($Filters.zeroByteFiles -and $Item.size -eq 0) {
                        $MatchTypes.Add('zeroByteFiles')
                    }

                    if ($Filters.systemJunk -and $Item.name -in @('Thumbs.db', '.DS_Store', 'desktop.ini')) {
                        $MatchTypes.Add('systemJunk')
                    }

                    if ($Filters.backupFiles -and $Item.name -match '\.(bak|old)$') {
                        $MatchTypes.Add('backupFiles')
                    }

                    if ($MatchTypes.Count -gt 0) {
                        $ParentPath = if ($Item.parentReference.path) {
                            $Item.parentReference.path -replace '/drive/root:', ''
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

            $Uri = $Response.'@odata.nextLink'
        } while ($Uri)

    } catch {
        Write-Host "Get-TempFilesRecursive: Failed to list folder $FolderId in drive $DriveId - $_"
    }

    return @($Results)
}
