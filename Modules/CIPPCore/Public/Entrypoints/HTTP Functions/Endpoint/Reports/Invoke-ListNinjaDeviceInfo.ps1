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
            $BySerial = @{}
        } else {
            $BySerial = @{}
            $Results = foreach ($Entity in $RawDevices) {
                try {
                    $Parsed = $Entity.RawDevice | ConvertFrom-Json -Depth 20 -ErrorAction SilentlyContinue
                    if ($Parsed -and $Parsed.NinjaDevice) {
                        $nd = $Parsed.NinjaDevice
                        $NinjaInfo = [PSCustomObject]@{
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
                        # Index by serial for fallback matching (NinjaOne stores serial as primary identifier)
                        $Serials = @()
                        if ($nd.biosSerialNumber) { $Serials += $nd.biosSerialNumber.Trim() }
                        if ($nd.serialNumber -and $nd.serialNumber -ne $nd.biosSerialNumber) { $Serials += $nd.serialNumber.Trim() }
                        foreach ($sn in $Serials) {
                            if ($sn -and -not $BySerial.ContainsKey($sn)) {
                                $BySerial[$sn] = $NinjaInfo
                            }
                        }
                        $NinjaInfo
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
        $BySerial = @{}
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = @($Results); BySerial = $BySerial }
        })
}
