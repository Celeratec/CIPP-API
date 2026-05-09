function Invoke-ExecListBackup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Backup.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    try {
        $Type = $Request.Query.Type
        $TenantFilter = $Request.Query.tenantFilter
        $NameOnly = $Request.Query.NameOnly -eq 'true'
        $BackupName = $Request.Query.BackupName

        $CippBackupParams = @{}
        if ($Type) { $CippBackupParams.Type = $Type }
        if ($TenantFilter) { $CippBackupParams.TenantFilter = $TenantFilter }
        if ($BackupName) { $CippBackupParams.Name = $BackupName }
        if ($NameOnly) { $CippBackupParams.NameOnly = $NameOnly }

        $Result = Get-CIPPBackup @CippBackupParams

        if ($NameOnly) {
            try {
                $Processed = foreach ($item in $Result) {
                    $properties = $item.PSObject.Properties | Where-Object { $_.Name -notin @('TenantFilter', 'ETag', 'PartitionKey', 'RowKey', 'Timestamp', 'OriginalEntityId', 'SplitOverProps', 'PartIndex') -and $_.Value }

                    if ($Type -eq 'Scheduled') {
                        $extractedTenant = if ($item.RowKey -match '^([^_]+)_') { $matches[1] } else { $null }
                        [PSCustomObject]@{
                            TenantFilter = $extractedTenant
                            BackupName   = $item.RowKey
                            Timestamp    = $item.Timestamp
                            Items        = $properties.Name
                        }
                    } else {
                        # Prefer stored indicator (BackupIsBlob) to avoid reading Backup field
                        $isBlob = $false
                        if ($null -ne $item.PSObject.Properties['BackupIsBlob']) {
                            try { $isBlob = [bool]$item.BackupIsBlob } catch { $isBlob = $false }
                        } else {
                            # Fallback heuristic for legacy rows if property missing
                            if ($null -ne $item.PSObject.Properties['Backup']) {
                                $b = $item.Backup
                                if ($b -is [string] -and ($b -like 'https://*' -or $b -like 'http://*')) { $isBlob = $true }
                            }
                        }
                        [PSCustomObject]@{
                            BackupName = $item.RowKey
                            Timestamp  = $item.Timestamp
                            Source     = if ($isBlob) { 'blob' } else { 'table' }
                        }
                    }
                }
                $Result = $Processed | Sort-Object Timestamp -Descending
            } catch {
                Write-Warning "Error processing backup entries: $_"
                Write-Information $_.InvocationInfo.PositionMessage
            }
        }

        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @($Result)
            })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'ExecListBackup' -message "Failed to list backups: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        return ([HttpResponseContext]@{
                StatusCode  = [HttpStatusCode]::InternalServerError
                ContentType = 'application/json'
                Body        = @{
                    error   = "Failed to list backups: $($ErrorMessage.NormalizedError)"
                    details = @{
                        operation      = 'ListBackups'
                        type           = $Type ?? 'CIPP'
                        innerException = $_.Exception.Message
                    }
                } | ConvertTo-Json -Depth 5 -Compress
            })
    }
}
