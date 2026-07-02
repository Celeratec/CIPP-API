function Get-CippQuarantineInputValue {
    <#
    .SYNOPSIS
        Normalizes autocomplete/form values from CIPP frontend payloads.
    #>
    [CmdletBinding()]
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) {
        $First = $Value | Select-Object -First 1
        if ($null -ne $First -and $null -ne $First.value) { return [string]$First.value }
        return [string]$First
    }
    if ($null -ne $Value.value) { return [string]$Value.value }
    return [string]$Value
}
