function Invoke-GetCippAlerts {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Alerts = [System.Collections.Generic.List[object]]::new()
    $Table = Get-CippTable -tablename CippAlerts
    $PartitionKey = Get-Date -UFormat '%Y%m%d'
    $Filter = "PartitionKey eq '{0}'" -f $PartitionKey
    $Rows = Get-CIPPAzDataTableEntity @Table -Filter $Filter | Sort-Object TableTimestamp -Descending | Select-Object -First 10
    $Role = Get-CippAccessRole -Request $Request

    $CIPPVersion = $Request.Query.localversion
    $Version = Assert-CippVersion -CIPPVersion $CIPPVersion
    if ($Version.OutOfDateCIPP) {
        $Alerts.Add(@{
                title = 'Manage365 Frontend Behind Upstream'
                Alert = "Manage365 frontend reports v$($Version.LocalCIPPVersion) but upstream CIPP is v$($Version.RemoteCIPPVersion). After absorbing upstream changes, bump public/version.json and redeploy the Static Web App. See the README Upstream Integration section."
                link  = 'https://github.com/Celeratec/CIPP#upstream-integration'
                type  = 'warning'
            })
        Write-LogMessage -message "Manage365 frontend v$($Version.LocalCIPPVersion) is behind upstream CIPP v$($Version.RemoteCIPPVersion)" -API 'Updates' -tenant 'All Tenants' -sev Alert

    }
    if ($Version.OutOfDateCIPPAPI) {
        $Alerts.Add(@{
                title = 'Manage365 API Behind Upstream'
                Alert = "Manage365 API reports v$($Version.LocalCIPPAPIVersion) but upstream CIPP-API is v$($Version.RemoteCIPPAPIVersion). After absorbing upstream changes, bump version_latest.txt and redeploy all Function App slots."
                link  = 'https://github.com/Celeratec/CIPP#upstream-integration'
                type  = 'warning'
            })
        Write-LogMessage -message "Manage365 API v$($Version.LocalCIPPAPIVersion) is behind upstream CIPP-API v$($Version.RemoteCIPPAPIVersion)" -API 'Updates' -tenant 'All Tenants' -sev Alert
    }

    if ($env:ApplicationID -eq 'LongApplicationID' -or $null -eq $env:ApplicationID) {
        $Alerts.Add(@{
                title          = 'SAM Setup Incomplete'
                Alert          = 'You have not yet completed your setup. Please go to the Setup Wizard in Application Settings to connect CIPP to your tenants.'
                link           = '/cipp/setup'
                type           = 'warning'
                setupCompleted = $false
            })
    }
    if ($role -like '*superadmin*') {
        $SwaCreds = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Request.Headers.'x-ms-client-principal')) | ConvertFrom-Json)
        $Username = $SwaCreds.userDetails
        $SuperAdminIgnoreList = @('Clint@celeratec.cloud')
        if ($Username -notin $SuperAdminIgnoreList) {
            $Alerts.Add(@{
                    title = 'Superadmin Account Warning'
                    Alert = 'You are logged in under a superadmin account. This account should not be used for normal usage.'
                    link  = 'https://docs.cipp.app/setup/installation/owntenant'
                    type  = 'error'
                })
        }
    }
    $PSMinVersion = [Version]'7.4.0'
    if ($PSVersionTable.PSVersion -lt $PSMinVersion) {
        $Alerts.Add(@{
                title = 'PowerShell Version Out of Date'
                Alert = ('Your CIPP API is running PowerShell {0}. PowerShell 7.4 or later is required for full compatibility. Please update your Function App to use PowerShell 7.4. For hosted customers, please contact the helpdesk.' -f $PSVersionTable.PSVersion)
                link  = 'https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell#powershell-versions'
                type  = 'warning'
            })
        Write-LogMessage -message ('CIPP API is running PowerShell {0}. PowerShell 7.4 or later is required.' -f $PSVersionTable.PSVersion) -API 'Updates' -tenant 'All Tenants' -sev Alert
    }
    if (${env:CIPPNG} -ne 'true' -and !(![string]::IsNullOrEmpty($env:WEBSITE_RUN_FROM_PACKAGE) -or ![string]::IsNullOrEmpty($env:DEPLOYMENT_STORAGE_CONNECTION_STRING)) -and $env:AzureWebJobsStorage -ne 'UseDevelopmentStorage=true' -and $env:NonLocalHostAzurite -ne 'true') {
        $Alerts.Add(
            @{
                title = 'Function App in Write Mode'
                Alert = 'Your Function App is running in write mode. This will cause performance issues and increase cost. Please check this '
                link  = 'https://docs.cipp.app/setup/installation/runfrompackage'
                type  = 'warning'
            })
    }
    if ($Rows) { $Rows | ForEach-Object { $Alerts.Add($_) } }
    $Alerts = @($Alerts)

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Alerts
        })

}
