function Push-GetApplicationQueue {
    param()
    $Table = Get-CippTable -tablename 'apps'
    Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'apps'" | Select-Object @{Name = 'Name'; Expression = { $_.RowKey } }, @{Name = 'FunctionName'; Expression = { 'UploadApplication' } }
}
