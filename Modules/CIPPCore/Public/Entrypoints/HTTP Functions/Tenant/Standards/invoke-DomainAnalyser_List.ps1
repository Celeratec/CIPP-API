
using namespace System.Net

Function Invoke-DomainAnalyser_List {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.DomainAnalyser.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $DomainTable = Get-CIPPTable -Table 'Domains'

    # Get all the things - always filter by PartitionKey for performance
    if ($Request.Query.tenantFilter -ne 'AllTenants') {
        $DomainTable.Filter = "PartitionKey eq 'TenantDomains' and TenantId eq '{0}'" -f $Request.Query.tenantFilter
    } else {
        $DomainTable.Filter = "PartitionKey eq 'TenantDomains'"
    }

    try {
        # Extract json from table results
        $Results = foreach ($DomainAnalyserResult in (Get-CIPPAzDataTableEntity @DomainTable).DomainAnalyser) {
            try {
                if (![string]::IsNullOrEmpty($DomainAnalyserResult)) {
                    $Object = $DomainAnalyserResult | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $Object
                }
            } catch {}
        }
    } catch {
        $Results = @()
    }


    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @($Results)
        })
}
