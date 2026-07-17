function Invoke-ListLogs {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Table = Get-CIPPTable
    $TzId = if ($env:CIPP_TIMEZONE) { $env:CIPP_TIMEZONE } else { 'UTC' }
    $NextLink = $null

    $TemplatesTable = Get-CIPPTable -tablename 'templates'
    $Templates = Get-CIPPAzDataTableEntity @TemplatesTable

    $ReturnedLog = if ($Request.Query.ListLogs) {
        Get-AzDataTableEntity @Table -Property PartitionKey | Sort-Object -Unique PartitionKey | Select-Object PartitionKey | ForEach-Object {
            @{
                value = $_.PartitionKey
                label = $_.PartitionKey
            }
        }
    } elseif ($Request.Query.logentryid) {
        $AllowedTenants = Test-CIPPAccess -Request $Request -TenantList
        
        if ($Request.Query.datefilter) {
            # Use point query with both PartitionKey and RowKey (fast)
            $Filter = "PartitionKey eq '{0}' and RowKey eq '{1}'" -f $Request.Query.datefilter, $Request.Query.logentryid
            Write-Host "Getting single log entry with PartitionKey: $($Request.Query.datefilter), RowKey: $($Request.Query.logentryid)"
        } else {
            # Fallback to RowKey only (slow - requires table scan)
            $Filter = "RowKey eq '{0}'" -f $Request.Query.logentryid
            Write-Host "WARNING: Getting single log entry without PartitionKey (slow) for RowKey: $($Request.Query.logentryid)"
        }

        $Row = Get-AzDataTableEntity @Table -Filter $Filter

        if ($Row) {
            if ($AllowedTenants -notcontains 'AllTenants') {
                $TenantList = Get-Tenants -IncludeErrors | Where-Object { $_.customerId -in $AllowedTenants }
            }

            if ($AllowedTenants -contains 'AllTenants' -or ($AllowedTenants -notcontains 'AllTenants' -and ($TenantList.defaultDomainName -contains $Row.Tenant -or $Row.Tenant -eq 'CIPP' -or $TenantList.customerId -contains $Row.TenantId -or $TenantList.initialDomainName -contains $Row.Tenant)) ) {
                if ($Row.StandardTemplateId) {
                    $Standard = ($Templates | Where-Object { $_.RowKey -eq $Row.StandardTemplateId }).JSON | ConvertFrom-Json

                    $StandardInfo = @{
                        Template = $Standard.templateName
                        Standard = $Row.Standard
                    }

                    if ($Row.IntuneTemplateId) {
                        $IntuneTemplate = ($Templates | Where-Object { $_.RowKey -eq $Row.IntuneTemplateId }).JSON | ConvertFrom-Json
                        $StandardInfo.IntunePolicy = $IntuneTemplate.displayName
                    }
                    if ($Row.ConditionalAccessTemplateId) {
                        $ConditionalAccessTemplate = ($Templates | Where-Object { $_.RowKey -eq $Row.ConditionalAccessTemplateId }).JSON | ConvertFrom-Json
                        $StandardInfo.ConditionalAccessPolicy = $ConditionalAccessTemplate.displayName
                    }

                } else {
                    $StandardInfo = @{}
                }

                $LogData = if ($Row.LogData -and (Test-Json -Json $Row.LogData -ErrorAction SilentlyContinue)) {
                    $Row.LogData | ConvertFrom-Json
                } else { $Row.LogData }
                [PSCustomObject]@{
                    DateTime   = $Row.Timestamp
                    Tenant     = $Row.Tenant
                    API        = $Row.API
                    Message    = $Row.Message
                    User       = $Row.Username
                    Severity   = $Row.Severity
                    LogData    = $LogData
                    TenantID   = if ($Row.TenantID -ne $null) {
                        $Row.TenantID
                    } else {
                        'None'
                    }
                    AppId      = $Row.AppId
                    IP         = $Row.IP
                    RowKey     = $Row.RowKey
                    Standard   = $StandardInfo
                    DateFilter = $Row.PartitionKey
                }
            }
        }
    } else {
        if ($request.Query.Filter -eq 'True') {
            $LogLevel = if ($Request.Query.Severity) { ($Request.query.Severity).split(',') } else { 'Info', 'Warn', 'Warning', 'Error', 'Critical', 'Alert' }
            $PartitionKey = $Request.Query.DateFilter
            $username = $Request.Query.User ?? '*'
            $TenantFilter = $Request.Query.Tenant
            $ApiFilter = $Request.Query.API
            $StandardFilter = $Request.Query.StandardTemplateId
            $ScheduledTaskFilter = $Request.Query.ScheduledTaskId

            $StartDate = if ($Request.Query.StartDate ?? $Request.Query.DateFilter) { ConvertTo-CIPPODataFilterValue -Value ($Request.Query.StartDate ?? $Request.Query.DateFilter) -Type Date } else { $null }
            $EndDate = if ($Request.Query.EndDate ?? $Request.Query.DateFilter) { ConvertTo-CIPPODataFilterValue -Value ($Request.Query.EndDate ?? $Request.Query.DateFilter) -Type Date } else { $null }

            if ($StartDate -and $EndDate) {
                # Multi-day ranges are served in small day batches, newest first, so each
                # request finishes well under the Azure Static Web Apps ~45s backend limit
                # (a single scan of 30 daily partitions returns "Backend call failure").
                # The client follows Metadata.nextLink (yyyyMMdd of the next older day).
                $DaysPerPage = 3
                $Culture = [System.Globalization.CultureInfo]::InvariantCulture
                $RangeStart = [DateTime]::ParseExact(($StartDate -replace '\D', '').Substring(0, 8), 'yyyyMMdd', $Culture)
                $RangeEnd = [DateTime]::ParseExact(($EndDate -replace '\D', '').Substring(0, 8), 'yyyyMMdd', $Culture)

                $PageEnd = if ($Request.Query.nextLink) {
                    $SafeNextLink = ConvertTo-CIPPODataFilterValue -Value $Request.Query.nextLink -Type Date
                    [DateTime]::ParseExact(($SafeNextLink -replace '\D', '').Substring(0, 8), 'yyyyMMdd', $Culture)
                } else {
                    $RangeEnd
                }
                if ($PageEnd -gt $RangeEnd) { $PageEnd = $RangeEnd }

                $PageStart = $PageEnd.AddDays(-($DaysPerPage - 1))
                if ($PageStart -lt $RangeStart) { $PageStart = $RangeStart }

                $Filter = "PartitionKey ge '{0}' and PartitionKey le '{1}'" -f $PageStart.ToString('yyyyMMdd'), $PageEnd.ToString('yyyyMMdd')
                if ($PageStart -gt $RangeStart) {
                    $NextLink = $PageStart.AddDays(-1).ToString('yyyyMMdd')
                }
            } elseif ($StartDate) {
                $Filter = "PartitionKey eq '{0}'" -f $StartDate
            } else {
                $Filter = "PartitionKey eq '{0}'" -f [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, $TzId).ToString('yyyyMMdd')
            }
        } else {
            $LogLevel = 'Info', 'Warn', 'Warning', 'Error', 'Critical', 'Alert'
            $PartitionKey = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, $TzId).ToString('yyyyMMdd')
            $username = '*'
            $TenantFilter = $null
            $Filter = "PartitionKey eq '{0}'" -f $PartitionKey
        }
        $AllowedTenants = Test-CIPPAccess -Request $Request -TenantList
        Write-Host "Getting logs for filter: $Filter, LogLevel: $LogLevel, Username: $username"

        $Rows = Get-AzDataTableEntity @Table -Filter $Filter | Where-Object {
            $_.Severity -in $LogLevel -and
            $_.Username -like $username -and
            ([string]::IsNullOrEmpty($TenantFilter) -or $TenantFilter -eq 'AllTenants' -or $_.Tenant -like "*$TenantFilter*" -or $_.TenantID -eq $TenantFilter) -and
            ([string]::IsNullOrEmpty($ApiFilter) -or $_.API -match "$ApiFilter") -and
            ([string]::IsNullOrEmpty($StandardFilter) -or $_.StandardTemplateId -eq $StandardFilter) -and
            ([string]::IsNullOrEmpty($ScheduledTaskFilter) -or $_.ScheduledTaskId -eq $ScheduledTaskFilter)
        }

        if ($AllowedTenants -notcontains 'AllTenants') {
            $TenantList = Get-Tenants -IncludeErrors | Where-Object { $_.customerId -in $AllowedTenants }
        }

        foreach ($Row in $Rows) {
            if ($AllowedTenants -contains 'AllTenants' -or ($AllowedTenants -notcontains 'AllTenants' -and ($TenantList.defaultDomainName -contains $Row.Tenant -or $Row.Tenant -eq 'CIPP' -or $TenantList.customerId -contains $Row.TenantId)) ) {
                if ($StandardTaskFilter -and $Row.StandardTemplateId) {
                    $Standard = ($Templates | Where-Object { $_.RowKey -eq $Row.StandardTemplateId }).JSON | ConvertFrom-Json

                    $StandardInfo = @{
                        Template = $Standard.templateName
                        Standard = $Row.Standard
                    }

                    if ($Row.IntuneTemplateId) {
                        $IntuneTemplate = ($Templates | Where-Object { $_.RowKey -eq $Row.IntuneTemplateId }).JSON | ConvertFrom-Json
                        $StandardInfo.IntunePolicy = $IntuneTemplate.displayName
                    }
                    if ($Row.ConditionalAccessTemplateId) {
                        $ConditionalAccessTemplate = ($Templates | Where-Object { $_.RowKey -eq $Row.ConditionalAccessTemplateId }).JSON | ConvertFrom-Json
                        $StandardInfo.ConditionalAccessPolicy = $ConditionalAccessTemplate.displayName
                    }
                } else {
                    $StandardInfo = @{}
                }

                $LogData = if ($Row.LogData -and (Test-Json -Json $Row.LogData -ErrorAction SilentlyContinue)) {
                    $Row.LogData | ConvertFrom-Json
                } else { $Row.LogData }
                [PSCustomObject]@{
                    DateTime      = $Row.Timestamp
                    PartitionKey  = $Row.PartitionKey
                    Tenant        = $Row.Tenant
                    API           = $Row.API
                    Message       = $Row.Message
                    User          = $Row.Username
                    Severity      = $Row.Severity
                    LogData       = $LogData
                    TenantID      = if ($Row.TenantID -ne $null) {
                        $Row.TenantID
                    } else {
                        'None'
                    }
                    AppId         = $Row.AppId
                    IP            = $Row.IP
                    RowKey        = $Row.RowKey
                    StandardInfo  = $StandardInfo
                    DateFilter    = $Row.PartitionKey
                }
            }
        }
    }

    $Body = if ($Request.Query.ListLogs -or $Request.Query.logentryid) {
        @($ReturnedLog | Sort-Object -Property DateTime -Descending)
    } else {
        # List queries return a Results/Metadata envelope so the frontend table can
        # follow Metadata.nextLink across day-batched pages (same as ListGraphRequest).
        $Envelope = @{ Results = @($ReturnedLog | Sort-Object -Property DateTime -Descending) }
        if ($NextLink) { $Envelope.Metadata = @{ nextLink = $NextLink } }
        [PSCustomObject]$Envelope
    }

    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    }

}
