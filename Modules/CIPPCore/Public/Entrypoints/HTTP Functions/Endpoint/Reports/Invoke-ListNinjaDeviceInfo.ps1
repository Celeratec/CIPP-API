Function Invoke-ListNinjaDeviceInfo {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Endpoint.Device.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.TenantFilter
    try {
        # Resolve tenant to get customerId (used as PartitionKey in NinjaOne cache)
        $Tenant = Get-Tenants -TenantFilter $TenantFilter
        if (-not $Tenant.customerId) {
            throw "Could not resolve tenant '$TenantFilter'"
        }

        $DeviceTable = Get-CippTable -tablename 'CacheNinjaOneParsedDevices'
        $DeviceFilter = "PartitionKey eq '$($Tenant.customerId)'"
        $RawDevices = Get-CIPPAzDataTableEntity @DeviceTable -Filter $DeviceFilter

        if (($RawDevices | Measure-Object).Count -eq 0) {
            # No NinjaOne data cached for this tenant
            $Results = @()
        } else {
            $Results = foreach ($Entity in $RawDevices) {
                try {
                    $Parsed = $Entity.RawDevice | ConvertFrom-Json -Depth 100 -ErrorAction SilentlyContinue
                    if ($Parsed -and $Parsed.NinjaDevice) {
                        $nd = $Parsed.NinjaDevice
                        [PSCustomObject]@{
                            azureADDeviceId   = $Entity.RowKey
                            ninjaDeviceId     = $nd.id
                            ninjaSystemName   = $nd.systemName
                            ninjaLastContact  = $nd.lastContact
                            ninjaOffline      = $nd.offline
                            ninjaNodeClass    = $nd.nodeClass
                            ninjaCpuName      = $nd.cpuName
                            ninjaCpuCores     = $nd.cpuCores
                            ninjaTotalRamGB   = $nd.totalRamGB
                            ninjaOsName       = $nd.osName
                            ninjaOsBuild      = $nd.osBuild
                            ninjaOsArch       = $nd.osArchitecture
                            ninjaLastBootTime = $nd.lastBootTime
                            ninjaDomain       = $nd.domain
                            ninjaManufacturer = $nd.manufacturer
                            ninjaModel        = $nd.model
                        }
                    }
                } catch {
                    # Skip unparseable entries
                }
            }
            if (-not $Results) { $Results = @() }
        }

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $Results = $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = @($Results) }
        })
}
