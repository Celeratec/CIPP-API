function Invoke-ExecSearchFiles {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.TenantFilter
    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }

    $SearchQuery = $Request.Body.SearchQuery
    if (-not $SearchQuery) { $SearchQuery = $Request.Query.SearchQuery }

    $From = $Request.Body.From
    if (-not $From) { $From = $Request.Query.From }
    if (-not $From) { $From = 0 } else { $From = [int]$From }

    $Size = $Request.Body.Size
    if (-not $Size) { $Size = $Request.Query.Size }
    if (-not $Size) { $Size = 25 } else { $Size = [int]$Size }

    $FilterModifiedBy = $Request.Body.FilterModifiedBy
    $FilterDateFrom = $Request.Body.FilterDateFrom
    $FilterDateTo = $Request.Body.FilterDateTo
    $HasFilters = $FilterModifiedBy -or $FilterDateFrom -or $FilterDateTo

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    if (-not $SearchQuery -or $SearchQuery.Trim().Length -eq 0) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'SearchQuery is required' }
        })
    }

    try {
        $RootSite = New-GraphGetRequest `
            -uri 'https://graph.microsoft.com/v1.0/sites/root?$select=siteCollection' `
            -tenantid $TenantFilter `
            -asApp $true
        $Region = $RootSite.siteCollection.dataLocationCode
        if (-not $Region) { $Region = 'US' }

        $EffectiveQuery = $SearchQuery
        if ($FilterModifiedBy) {
            $EffectiveQuery = "$EffectiveQuery Editor:`"$FilterModifiedBy`""
        }

        $FetchSize = $Size
        $EffectiveFrom = $From
        if ($HasFilters) {
            $FetchSize = 200
            $EffectiveFrom = 0
        }

        $SearchRequest = @{
            entityTypes               = @('driveItem')
            query                     = @{
                queryString = $EffectiveQuery
            }
            from                      = $EffectiveFrom
            size                      = $FetchSize
            region                    = $Region
            sharePointOneDriveOptions = @{
                includeContent = 'privateContent,sharedContent'
            }
            fields                    = @(
                'name', 'webUrl', 'lastModifiedDateTime', 'lastModifiedBy',
                'createdBy', 'size', 'parentReference', 'file', 'folder',
                'id', 'createdDateTime'
            )
        }

        $SearchBody = @{ requests = @($SearchRequest) } | ConvertTo-Json -Depth 5

        try {
            $SearchResults = New-GraphPostRequest `
                -uri 'https://graph.microsoft.com/v1.0/search/query' `
                -tenantid $TenantFilter `
                -body $SearchBody `
                -type POST `
                -AsApp $true `
                -NoAuthCheck $true
        } catch {
            $RegionError = $_.Exception.Message
            if ($RegionError -match '(?i)region') {
                $FallbackRegion = $null
                if ($RegionError -match '(?i)valid regions?\s+(?:are|is)\s+(\w+)') {
                    $FallbackRegion = $Matches[1]
                }
                if ($FallbackRegion -and $FallbackRegion -ne $Region) {
                    $SearchRequest['region'] = $FallbackRegion
                    $SearchBody = @{ requests = @($SearchRequest) } | ConvertTo-Json -Depth 5
                    $SearchResults = New-GraphPostRequest `
                        -uri 'https://graph.microsoft.com/v1.0/search/query' `
                        -tenantid $TenantFilter `
                        -body $SearchBody `
                        -type POST `
                        -AsApp $true `
                        -NoAuthCheck $true
                } else {
                    throw
                }
            } else {
                throw
            }
        }

        $Hits = @()
        $TotalCount = 0
        $MoreResultsAvailable = $false

        if ($SearchResults -and $SearchResults.value) {
            foreach ($response in $SearchResults.value) {
                $TotalCount = $response.hitsContainers[0].total
                $MoreResultsAvailable = $response.hitsContainers[0].moreResultsAvailable

                foreach ($hit in $response.hitsContainers[0].hits) {
                    $resource = $hit.resource
                    $IsFolder = $null -ne $resource.folder
                    $SizeBytes = if ($resource.size) { $resource.size } else { 0 }
                    $SizeFormatted = if ($SizeBytes -ge 1GB) {
                        '{0:N2} GB' -f ($SizeBytes / 1GB)
                    } elseif ($SizeBytes -ge 1MB) {
                        '{0:N2} MB' -f ($SizeBytes / 1MB)
                    } elseif ($SizeBytes -ge 1KB) {
                        '{0:N1} KB' -f ($SizeBytes / 1KB)
                    } else {
                        "$SizeBytes B"
                    }

                    $SiteName = ''
                    $DriveName = ''
                    $FolderPath = ''
                    $SiteId = ''
                    $DriveId = ''
                    $ParentId = ''

                    if ($resource.parentReference) {
                        $DriveId = $resource.parentReference.driveId
                        $SiteId = $resource.parentReference.siteId
                        $ParentId = $resource.parentReference.id
                        if ($resource.parentReference.path) {
                            $FolderPath = $resource.parentReference.path -replace '^.*root:/?', '/'
                            if ($FolderPath -eq '/') { $FolderPath = '/' }
                        }
                        $DriveName = $resource.parentReference.name
                        $SiteName = $resource.parentReference.sharepointIds.siteUrl -replace 'https://[^/]+/sites/', '' -replace '/.*', ''
                    }

                    $FileExtension = $null
                    if (-not $IsFolder -and $resource.name -match '\.(\w+)$') {
                        $FileExtension = $Matches[1].ToLower()
                    }

                    $Hits += [PSCustomObject]@{
                        id             = $resource.id
                        name           = $resource.name
                        isFolder       = $IsFolder
                        type           = if ($IsFolder) { 'Folder' } else { 'File' }
                        sizeInBytes    = $SizeBytes
                        sizeFormatted  = if ($IsFolder) { "$($resource.folder.childCount) items" } else { $SizeFormatted }
                        fileExtension  = $FileExtension
                        webUrl         = $resource.webUrl
                        lastModified   = $resource.lastModifiedDateTime
                        lastModifiedBy = $resource.lastModifiedBy.user.displayName
                        createdBy      = $resource.createdBy.user.displayName
                        createdDate    = $resource.createdDateTime
                        siteName       = $SiteName
                        driveName      = $DriveName
                        driveId        = $DriveId
                        siteId         = $SiteId
                        parentId       = $ParentId
                        folderPath     = $FolderPath
                        summary        = $hit.summary
                        rank           = $hit.rank
                    }
                }
            }
        }

        $FilteredHits = $Hits
        if ($HasFilters -and $Hits.Count -gt 0) {
            $FilteredHits = @($Hits | Where-Object {
                $Pass = $true
                if ($FilterModifiedBy -and $Pass) {
                    $Pass = $_.lastModifiedBy -and $_.lastModifiedBy -like "*$FilterModifiedBy*"
                }
                if ($FilterDateFrom -and $Pass -and $_.lastModified) {
                    $ItemDate = [datetime]$_.lastModified
                    $FromDate = [datetime]$FilterDateFrom
                    $Pass = $ItemDate -ge $FromDate
                }
                if ($FilterDateTo -and $Pass -and $_.lastModified) {
                    $ItemDate = [datetime]$_.lastModified
                    $ToDate = ([datetime]$FilterDateTo).AddDays(1)
                    $Pass = $ItemDate -lt $ToDate
                }
                $Pass
            })
        }

        $Body = @{
            Results              = $FilteredHits
            TotalCount           = $TotalCount
            MoreResultsAvailable = $MoreResultsAvailable
            From                 = $From
            Size                 = $Size
        }
        if ($HasFilters) {
            $Body['FilteredCount'] = $FilteredHits.Count
        }

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $RawError = $_.Exception.Message
        if ($RawError -match '403' -or $RawError -match 'Forbidden' -or $RawError -match 'Authorization') {
            $Message = "File search failed with a 403 Forbidden error. The Files.Read.All application permission may not be granted for this tenant. Please run a CPV Refresh from CIPP Settings to push the required permissions, then try again. Raw error: $($ErrorMessage.NormalizedError)"
        } elseif ($RawError -match 'Region' -or $RawError -match 'region') {
            $Message = "File search failed due to a region configuration issue. The tenant's data location code '$Region' was not accepted by the Microsoft Search API. Raw error: $($ErrorMessage.NormalizedError)"
        } else {
            $Message = "File search failed. Error: $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = $Message }
    }

    return ([HttpResponseContext]@{
        StatusCode  = $StatusCode
        ContentType = 'application/json'
        Body        = $Body
    })
}
