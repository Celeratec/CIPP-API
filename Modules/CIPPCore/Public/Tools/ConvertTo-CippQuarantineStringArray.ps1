function ConvertTo-CippQuarantineStringArray {
    <#
    .SYNOPSIS
        Converts scalar, comma-separated, or JSON array inputs into string arrays.
    #>
    [CmdletBinding()]
    param($InputObject)

    if ($null -eq $InputObject -or $InputObject -eq '') { return @() }
    if ($InputObject -is [array]) {
        return @(
            $InputObject |
                ForEach-Object { Get-CippQuarantineInputValue $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
    if ($InputObject -is [string] -and $InputObject.Trim().StartsWith('[')) {
        try {
            return @($InputObject | ConvertFrom-Json | ForEach-Object { [string]$_ } | Where-Object { $_ })
        } catch {
            # fall through to comma split
        }
    }
    return @(
        ($InputObject -split '[,;]') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}
