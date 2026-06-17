function Push-ListMailQuarantineAllTenants {
    <#
    .FUNCTIONALITY
        Entrypoint
    #>
    param($Item)

    $Tenant = Get-Tenants -TenantFilter $Item.customerId
    $domainName = $Tenant.defaultDomainName
    $Table = Get-CIPPTable -TableName cacheQuarantineMessages
    Write-Host "PowerShell queue trigger function processed work item: $($Tenant.defaultDomainName)"

    try {
        $Query = Build-CIPPQuarantineQueryParams -QueryInput @{
            days     = 30
            pageSize = 1000
        } -ApplyDefaultDateRange

        $AllMessages = [System.Collections.Generic.List[object]]::new()
        $Page = 1
        $MaxPages = 5
        do {
            $Query.CmdParams.Page = $Page
            $quarantineMessages = @(Invoke-CippQuarantineExoRequest -TenantId $domainName -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
                Select-Object -ExcludeProperty *data.type*)
            if ($quarantineMessages) { $AllMessages.AddRange($quarantineMessages) }
            $Page++
        } while ($quarantineMessages.Count -eq $Query.CmdParams.PageSize -and $Page -le $MaxPages)

        foreach ($message in $AllMessages) {
            $messageData = @{
                QuarantineMessage = [string]($message | ConvertTo-Json -Depth 10 -Compress)
                RowKey            = [string](New-Guid).Guid
                PartitionKey      = 'QuarantineMessage'
                Tenant            = [string]$domainName
            }
            Add-CIPPAzDataTableEntity @Table -Entity $messageData -Force | Out-Null
        }
    } catch {
        $errorData = ConvertTo-Json -InputObject @{
            Identity         = $null
            ReceivedTime     = (Get-Date).ToString('s')
            SenderAddress    = 'CIPP Error'
            RecipientAddress = 'N/A'
            Subject          = "Could not connect to Tenant: $($_.Exception.Message)"
            Size             = 0
            Type             = 'Error'
            QuarantineReason = 'ConnectionError'
        }
        $messageData = @{
            QuarantineMessage = [string]$errorData
            RowKey            = [string]$domainName
            PartitionKey      = 'QuarantineMessage'
            Tenant            = [string]$domainName
        }
        Add-CIPPAzDataTableEntity @Table -Entity $messageData -Force | Out-Null
    }
}
