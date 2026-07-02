function Get-CippQuarantinePagedResults {
    <#
    .SYNOPSIS
        Fetches one client page of quarantine results, scanning multiple EXO pages when post-filters are active.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)]$Query,
        [string]$NextLink,
        [int]$TargetPageSize = 100
    )

    $HasPostFilters = $Query.PostFilters.Count -gt 0
    $ExoPageSize = $Query.CmdParams.PageSize
    $StartExoPage = 1
    if ($NextLink -match '^\d+$') {
        $StartExoPage = [int]$NextLink
    }

    if (-not $HasPostFilters) {
        $Query.CmdParams.Page = $StartExoPage
        $RawResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantId -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
            Select-Object -ExcludeProperty *data.type*)
        $Filtered = @(Apply-CippQuarantinePostFilters -Messages $RawResults -PostFilters $Query.PostFilters)
        $HasMore = (@($RawResults).Count -eq $ExoPageSize -and $StartExoPage -lt 1000)

        return [PSCustomObject]@{
            Results  = $Filtered
            Metadata = [PSCustomObject]@{
                appliedFilters              = $Query.AppliedFilters
                page                        = $StartExoPage
                pageSize                    = $ExoPageSize
                nextLink                    = if ($HasMore) { [string]($StartExoPage + 1) } else { $null }
                HasPostFilters              = $false
                RawRowsScanned              = @($RawResults).Count
                FilteredRowsReturned        = $Filtered.Count
                PostFilterPaginationLimited = $false
            }
        }
    }

    $Collected = [System.Collections.Generic.List[object]]::new()
    $RawScanned = 0
    $ExoPage = $StartExoPage
    $MaxRawPagesPerRequest = 25
    $PagesFetched = 0
    $LastPageResultCount = 0
    $PostFilterLimited = $false

    while ($Collected.Count -lt $TargetPageSize -and $PagesFetched -lt $MaxRawPagesPerRequest -and $ExoPage -le 1000) {
        $Query.CmdParams.Page = $ExoPage
        $PageResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantId -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
            Select-Object -ExcludeProperty *data.type*)
        $LastPageResultCount = @($PageResults).Count
        $RawScanned += $LastPageResultCount
        $FilteredPage = @(Apply-CippQuarantinePostFilters -Messages $PageResults -PostFilters $Query.PostFilters)
        # Always keep every match from a scanned EXO page. The next request resumes
        # on the following EXO page, so truncating mid-page would silently drop the
        # remaining matches on this page. The client page may therefore run slightly
        # over TargetPageSize, which is preferable to losing rows.
        foreach ($item in $FilteredPage) {
            $Collected.Add($item)
        }
        $PagesFetched++
        $ExoPage++
        if ($LastPageResultCount -lt $ExoPageSize) { break }
    }

    # More EXO pages exist whenever the last scanned page was full. Surface that as
    # HasMore even when this client page came back short (e.g. the raw-page scan
    # limit was hit before enough matches were found), so the UI can keep paging.
    $MoreExoPagesExist = ($LastPageResultCount -eq $ExoPageSize -and $ExoPage -le 1000)
    $HasMore = $MoreExoPagesExist
    if ($MoreExoPagesExist -and $Collected.Count -lt $TargetPageSize) {
        $PostFilterLimited = $true
    }

    return [PSCustomObject]@{
        Results  = @($Collected)
        Metadata = [PSCustomObject]@{
            appliedFilters              = $Query.AppliedFilters
            page                        = $StartExoPage
            pageSize                    = $TargetPageSize
            nextLink                    = if ($HasMore) { [string]$ExoPage } else { $null }
            HasPostFilters              = $true
            RawRowsScanned              = $RawScanned
            FilteredRowsReturned        = $Collected.Count
            PostFilterPaginationLimited = $PostFilterLimited
        }
    }
}
