function Invoke-CippQuarantineExoRequest {
    <#
    .SYNOPSIS
        Wraps New-ExoRequest with retry/backoff for transient quarantine API failures.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)][string]$Cmdlet,
        [hashtable]$CmdParams,
        [int]$MaxAttempts = 3
    )

    $Attempt = 0
    $DelaySeconds = 2
    while ($true) {
        $Attempt++
        try {
            return New-ExoRequest -tenantid $TenantId -cmdlet $Cmdlet -cmdParams $CmdParams
        } catch {
            $Message = $_.Exception.Message
            $IsTransient = $Message -match '429|503|throttl|temporar|busy|timeout|Too many requests'
            # EXO's admin API intermittently returns CommandNotFoundException for
            # cmdlets that exist (same backend flake documented for
            # Release-QuarantineMessage chaining in ExecQuarantineManagement).
            # Retry once before treating it as a real RBAC/licensing failure.
            $IsCmdletMissing = $Message -match 'is not recognized'
            if ($IsCmdletMissing -and $Attempt -lt 2) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }
            if (-not $IsTransient -or $Attempt -ge $MaxAttempts) {
                throw
            }
            Start-Sleep -Seconds $DelaySeconds
            $DelaySeconds = [Math]::Min($DelaySeconds * 2, 30)
        }
    }
}
