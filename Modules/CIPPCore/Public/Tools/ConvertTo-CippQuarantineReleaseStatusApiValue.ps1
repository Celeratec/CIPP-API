function ConvertTo-CippQuarantineReleaseStatusApiValue {
    [CmdletBinding()]
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) { return $null }
    switch ($Status.ToUpperInvariant()) {
        'NOTRELEASED' { return 'NotReleased' }
        'RELEASED' { return 'Released' }
        'REQUESTED' { return 'Requested' }
        'DENIED' { return 'Denied' }
        'ERROR' { return 'Error' }
        'APPROVED' { return 'Approved' }
        'PREPARINGTORELEASE' { return 'PreparingToRelease' }
        default { return $Status }
    }
}
