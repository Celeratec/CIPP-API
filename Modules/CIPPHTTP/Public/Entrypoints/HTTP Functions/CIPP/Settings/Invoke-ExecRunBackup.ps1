Function Invoke-ExecRunBackup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.AppSettings.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $StatusCode = [HttpStatusCode]::OK

    try {
        $CSVfile = New-CIPPBackup -BackupType 'CIPP' -Headers $Request.Headers
        $body = [pscustomobject]@{
            'Results' = @{
                resultText = 'Created backup'
                state      = 'success'
            }
            backup    = $CSVfile.BackupData
        } | ConvertTo-Json -Depth 5 -Compress

        Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Created CIPP backup' -Sev 'Info'

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $StatusCode = [HttpStatusCode]::InternalServerError
        $body = @{
            error   = "Failed to create backup: $($ErrorMessage.NormalizedError)"
            details = @{
                operation      = 'CreateBackup'
                innerException = $_.Exception.Message
            }
        } | ConvertTo-Json -Depth 5 -Compress
        Write-LogMessage -headers $Request.Headers -API $APINAME -message "Failed to create CIPP backup: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }
    return ([HttpResponseContext]@{
            StatusCode  = $StatusCode
            ContentType = 'application/json'
            Body        = $body
        })

}
