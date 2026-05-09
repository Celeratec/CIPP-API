function Push-SchedulerAlert {
    <#
    .SYNOPSIS
        Process scheduled alert checks for a tenant
    .DESCRIPTION
        Reads alert configuration from SchedulerConfig table and runs
        each enabled Get-CIPPAlert* check for the specified tenant.
        This function bridges the legacy SchedulerConfig Alert type
        to the current Get-CIPPAlert* function pattern.
    .FUNCTIONALITY
        Entrypoint
    #>
    param (
        $Item
    )

    try {
        $Tenant = $Item.Tenant
        $TenantId = $Item.Tenantid

        Write-Information "Push-SchedulerAlert: Processing alerts for tenant $Tenant"

        $Table = Get-CIPPTable -TableName SchedulerConfig
        if ($Item.Tag -eq 'AllTenants') {
            $Filter = "RowKey eq 'AllTenants' and PartitionKey eq 'Alert'"
        } else {
            $Filter = "RowKey eq '{0}' and PartitionKey eq 'Alert'" -f $TenantId
        }
        $AlertConfig = Get-CIPPAzDataTableEntity @Table -Filter $Filter

        if (!$AlertConfig) {
            Write-Information "Push-SchedulerAlert: No alert configuration found for tenant $Tenant (Filter: $Filter)"
            return
        }

        $IgnoreList = @('ETag', 'PartitionKey', 'Timestamp', 'RowKey', 'tenantid', 'tenant', 'type')
        $AlertProperties = $AlertConfig | Select-Object * -ExcludeProperty $IgnoreList

        foreach ($alert in ($AlertProperties.psobject.members | Where-Object { $_.MemberType -EQ 'NoteProperty' -and $_.value -ne $false })) {
            $AlertName = $alert.Name
            $AlertValue = $alert.Value

            # Check for duplicate/recent runs using AlertLastRun table
            $RunCheckTable = Get-CIPPTable -TableName AlertLastRun
            $PartitionKey = (Get-Date -UFormat '%Y%m%d').ToString()
            $RunCheckFilter = "PartitionKey eq '{0}' and RowKey eq '{1}-Get-CIPPAlert{2}'" -f $PartitionKey, $Tenant, $AlertName
            $RecentRun = Get-CIPPAzDataTableEntity @RunCheckTable -Filter $RunCheckFilter

            if ($RecentRun) {
                Write-Information "Push-SchedulerAlert: Skipping $AlertName for $Tenant - already ran today"
                continue
            }

            # Call the corresponding Get-CIPPAlert function
            $FunctionName = "Get-CIPPAlert$AlertName"
            if (Get-Command -Name $FunctionName -ErrorAction SilentlyContinue) {
                try {
                    Write-Information "Push-SchedulerAlert: Running $FunctionName for $Tenant"
                    $InputValue = $null
                    if ($AlertValue -ne $true -and $AlertValue -ne 'true') {
                        try {
                            $InputValue = $AlertValue | ConvertFrom-Json -ErrorAction SilentlyContinue
                        } catch {
                            $InputValue = $AlertValue
                        }
                    }
                    & $FunctionName -TenantFilter $Tenant -InputValue $InputValue
                } catch {
                    $ErrorMessage = Get-CippException -Exception $_
                    Write-LogMessage -API 'SchedulerAlert' -tenant $Tenant -message "Failed to run alert $FunctionName for $Tenant : $($ErrorMessage.Message)" -Sev 'Error' -LogData $ErrorMessage
                    Write-Information "Push-SchedulerAlert: Error running $FunctionName for $Tenant - $($ErrorMessage.Message)"
                }
            } else {
                Write-Information "Push-SchedulerAlert: Alert function $FunctionName not found, skipping"
                Write-LogMessage -API 'SchedulerAlert' -tenant $Tenant -message "Alert function $FunctionName not found. This alert type may need to be reconfigured." -Sev 'Warning'
            }
        }

        Write-Information "Push-SchedulerAlert: Completed processing alerts for tenant $Tenant"
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'SchedulerAlert' -tenant $Item.Tenant -message "Exception processing alerts for $($Item.Tenant): $($ErrorMessage.Message)" -Sev 'Error' -LogData $ErrorMessage
        Write-Information "Push-SchedulerAlert: Exception - $($ErrorMessage.Message) at line $($ErrorMessage.LineNumber)"
    }
}
