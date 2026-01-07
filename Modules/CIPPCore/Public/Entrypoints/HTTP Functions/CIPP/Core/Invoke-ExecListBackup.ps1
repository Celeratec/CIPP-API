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
        $NameOnly = $Request.Query.NameOnly
        $BackupName = $Request.Query.BackupName

        $CippBackupParams = @{}
        if ($Type) { $CippBackupParams.Type = $Type }
        if ($TenantFilter) { $CippBackupParams.TenantFilter = $TenantFilter }
        if ($BackupName) { $CippBackupParams.Name = $BackupName }

        $Result = Get-CIPPBackup @CippBackupParams

        if ($NameOnly) {
            $Processed = foreach ($item in $Result) {
                $properties = $item.PSObject.Properties | Where-Object { $_.Name -notin @('TenantFilter', 'ETag', 'PartitionKey', 'RowKey', 'Timestamp', 'OriginalEntityId', 'SplitOverProps', 'PartIndex') -and $_.Value }

                if ($Type -eq 'Scheduled') {
                    # Extract tenant filter from RowKey (format: TenantFilter_timestamp)
                    $extractedTenant = if ($item.RowKey -match '^([^_]+)_') { $matches[1] } else { $null }
                    [PSCustomObject]@{
                        TenantFilter = $extractedTenant
                        BackupName   = $item.RowKey
                        Timestamp    = $item.Timestamp
                        Items        = $properties.Name
                    }
                } else {
                    [PSCustomObject]@{
                        BackupName = $item.RowKey
                        Timestamp  = $item.Timestamp
                    }
                }
            }
            $Result = $Processed | Sort-Object Timestamp -Descending
        }

        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @($Result)
            })
    } catch {
        Write-LogMessage -API 'ExecListBackup' -message "Failed to list backups: $($_.Exception.Message)" -Sev 'Error' -LogData (Get-CippException -Exception $_)
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = @{ error = "Failed to list backups: $($_.Exception.Message)" }
            })
    }
}
