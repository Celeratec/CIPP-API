function Invoke-ExecRestoreBackup {
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
        if ($Request.Body.BackupName -like 'CIPPBackup_*') {
            # Use Get-CIPPBackup which already handles fetching from blob storage
            $Backup = Get-CIPPBackup -Type 'CIPP' -Name $Request.Body.BackupName
            if ($Backup) {
                $raw = $Backup.Backup
                $BackupData = $null

                # Get-CIPPBackup already fetches blob content, so raw should be JSON string
                try {
                    if ($raw -is [string]) {
                        $BackupData = $raw | ConvertFrom-Json -ErrorAction Stop
                    } else {
                        $BackupData = $raw | Select-Object * -ExcludeProperty ETag, Timestamp
                    }
                } catch {
                    throw "Failed to parse backup JSON: $($_.Exception.Message)"
                }

                $SelectedTypes = $Request.Body.SelectedTypes
                if ($SelectedTypes -and $SelectedTypes.Count -gt 0) {
                    $BackupData = $BackupData | Where-Object {
                        $item = $_
                        if ($item.table -eq 'templates') {
                            $typeKey = "templates:$($item.PartitionKey)"
                        } else {
                            $typeKey = $item.table
                        }
                        $SelectedTypes -contains $typeKey
                    }
                }
                $RestoredCount = 0
                $BackupData | ForEach-Object {
                    $Table = Get-CippTable -tablename $_.table
                    $ht2 = @{}
                    $_.psobject.properties | ForEach-Object { $ht2[$_.Name] = [string]$_.Value }
                    $Table.Entity = $ht2
                    Add-AzDataTableEntity @Table -Force
                    $RestoredCount++
                }
                Write-LogMessage -headers $Request.Headers -API $APINAME -message "Restored backup $($Request.Body.BackupName) - $RestoredCount rows restored" -Sev 'Info'
                $body = @{
                    'Results' = "Successfully restored $RestoredCount rows from backup."
                } | ConvertTo-Json -Compress
            } else {
                $StatusCode = [HttpStatusCode]::NotFound
                $body = @{
                    error = "Backup not found: $($Request.Body.BackupName)"
                } | ConvertTo-Json -Compress
            }
        } else {
            $RestoredCount = 0
            foreach ($line in ($Request.body | Select-Object * -ExcludeProperty ETag, Timestamp)) {
                $Table = Get-CippTable -tablename $line.table
                $ht2 = @{}
                $line.psobject.properties | ForEach-Object { $ht2[$_.Name] = [string]$_.Value }
                $Table.Entity = $ht2
                Add-AzDataTableEntity @Table -Force
                $RestoredCount++
            }
            Write-LogMessage -headers $Request.Headers -API $APINAME -message "Restored backup - $RestoredCount rows restored" -Sev 'Info'

            $body = @{
                'Results' = "Successfully restored $RestoredCount rows from backup."
            } | ConvertTo-Json -Compress
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Request.Headers -API $APINAME -message "Failed to restore backup: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $body = @{
            error   = "Backup restore failed: $($ErrorMessage.NormalizedError)"
            details = @{
                operation      = 'RestoreBackup'
                backupName     = $Request.Body.BackupName
                innerException = $_.Exception.Message
            }
        } | ConvertTo-Json -Depth 5 -Compress
    }

    return ([HttpResponseContext]@{
            StatusCode  = $StatusCode
            ContentType = 'application/json'
            Body        = $body
        })

}
