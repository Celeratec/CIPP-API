
function Get-CippAlertSecureScore {
    <#
    .FUNCTIONALITY
        Entrypoint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Alias('input')]
        $InputValue,
        $TenantFilter
    )
    try {
        if (-not $InputValue -or -not $InputValue.ThresholdType -or -not $InputValue.InputValue) {
            Write-LogMessage -API 'Alerts' -tenant $TenantFilter -message "Secure Score alert skipped for $($TenantFilter): No threshold configuration provided" -sev Info
            return
        }
        $SecureScore = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/security/secureScores?$top=1' -tenantid $TenantFilter -noPagination $true
        if ($InputValue.ThresholdType.value -eq "absolute") {
            if ($SecureScore.currentScore -lt $InputValue.InputValue) {
                $SecureScoreResult = [PSCustomObject]@{
                    Message        = "Secure Score is below acceptable threshold"
                    Tenant         = $TenantFilter
                    CurrentScore   = $SecureScore.currentScore
                    MaxSecureScore = $SecureScore.maxScore
                }
            }
        } elseif ($InputValue.ThresholdType.value -eq "percent") {
            $PercentageScore = [math]::Round((($SecureScore.currentScore / $SecureScore.maxScore) * 100),2)
            if ($PercentageScore -lt $InputValue.InputValue) {
                $SecureScoreResult = [PSCustomObject]@{
                    Message                  = "Secure Score is below acceptable threshold"
                    Tenant                   = $TenantFilter
                    CurrentScore             = $SecureScore.currentScore
                    MaxScore                 = $SecureScore.maxScore
                    CurrentScorePercentage   = [math]::Round($PercentageScore,2)
                    ScoreThresholdPercentage = $InputValue.InputValue
                }
            }
        }
        if ($SecureScoreResult -and @($SecureScoreResult).Count -gt 0) {
            Write-AlertTrace -cmdletName $MyInvocation.MyCommand -tenantFilter $TenantFilter -data $SecureScoreResult -PartitionKey SecureScore
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'Alerts' -tenant $TenantFilter -message "Could not get Secure Score for $($TenantFilter): $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
    }
}
