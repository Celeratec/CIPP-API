function Test-CIPPTempFileMatch {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Returns the temp/junk match types for a single drive item.
    .DESCRIPTION
        Shared classifier used by both the delta-based and recursive temp file scanners so the
        matching rules stay in one place. Returns an array of match type names (empty when the
        item matches no enabled filter).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Item,

        [Parameter(Mandatory = $false)]
        $Filters
    )

    $MatchTypes = [System.Collections.Generic.List[string]]::new()
    if (-not $Item -or -not $Item.name) { return @() }

    if ($Filters.officeTemp -and $Item.name -match '^\~\$') {
        $MatchTypes.Add('officeTemp')
    }
    if ($Filters.tempFiles -and $Item.name -match '(?i)\.(TMP|temp)$') {
        $MatchTypes.Add('tempFiles')
    }
    if ($Filters.zeroByteFiles -and $Item.size -eq 0) {
        $MatchTypes.Add('zeroByteFiles')
    }
    if ($Filters.systemJunk -and $Item.name -in @('Thumbs.db', '.DS_Store', 'desktop.ini')) {
        $MatchTypes.Add('systemJunk')
    }
    if ($Filters.backupFiles -and $Item.name -match '(?i)\.(bak|old)$') {
        $MatchTypes.Add('backupFiles')
    }

    return @($MatchTypes)
}
