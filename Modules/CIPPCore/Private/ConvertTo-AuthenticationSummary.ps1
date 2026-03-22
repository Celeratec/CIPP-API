function ConvertTo-AuthenticationSummary {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$DetailEntries
    )

    $Summary = [PSCustomObject]@{
        SPF      = [PSCustomObject]@{ result = 'Unknown'; detail = '' }
        DKIM     = [PSCustomObject]@{ result = 'Unknown'; detail = '' }
        DMARC    = [PSCustomObject]@{ result = 'Unknown'; detail = '' }
        CompAuth = [PSCustomObject]@{ result = 'Unknown' }
    }

    if (-not $DetailEntries) { return $Summary }

    $AllDetails = $DetailEntries -join ';'

    try {
        if ($AllDetails -match 'spf\s+(pass|fail|softfail|temperror|permerror|none)\s*(?:\(([^)]+)\))?') {
            $Summary.SPF.result = $Matches[1]
            if ($Matches[2]) { $Summary.SPF.detail = $Matches[2] }
        } elseif ($AllDetails -match 'SPF=(\w+)') {
            $Summary.SPF.result = $Matches[1]
        }

        if ($AllDetails -match 'dkim\s+(pass|fail|none)\s*(?:\(([^)]+)\))?') {
            $Summary.DKIM.result = $Matches[1]
            if ($Matches[2]) { $Summary.DKIM.detail = $Matches[2] }
        } elseif ($AllDetails -match 'DKIM=(\w+)') {
            $Summary.DKIM.result = $Matches[1]
        }

        if ($AllDetails -match 'dmarc\s+(pass|fail|bestguesspass|none)\s*(?:action=(\w+))?') {
            $Summary.DMARC.result = $Matches[1]
            if ($Matches[2]) { $Summary.DMARC.detail = "action=$($Matches[2])" }
        } elseif ($AllDetails -match 'DMARC=(\w+)') {
            $Summary.DMARC.result = $Matches[1]
        }

        if ($AllDetails -match 'compauth=(\w+)') {
            $Summary.CompAuth.result = $Matches[1]
        }
    } catch {
        Write-Warning "Failed to parse authentication summary: $($_.Exception.Message)"
    }

    return $Summary
}
