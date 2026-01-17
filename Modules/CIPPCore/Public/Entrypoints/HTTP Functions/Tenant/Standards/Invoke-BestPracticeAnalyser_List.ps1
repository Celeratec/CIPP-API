Function Invoke-BestPracticeAnalyser_List {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.BestPracticeAnalyser.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Tenants = Get-Tenants
    $Table = get-cipptable 'cachebpa'
    
    # Build OData filter for allowed tenants instead of loading all data
    $TenantIds = @($Tenants.customerId | Where-Object { $_ })
    if ($TenantIds.Count -gt 0) {
        # Build filter: RowKey eq 'id1' or RowKey eq 'id2' ...
        # OData has limits, so for large tenant counts we may need to chunk
        if ($TenantIds.Count -le 50) {
            $FilterParts = $TenantIds | ForEach-Object { "RowKey eq '$_'" }
            $Filter = $FilterParts -join ' or '
            $Results = Get-CIPPAzDataTableEntity @Table -Filter $Filter
        } else {
            # For large tenant counts, fall back to full scan + filter (rare case)
            $Results = Get-CIPPAzDataTableEntity @Table | Where-Object { $_.RowKey -in $TenantIds }
        }
    } else {
        $Results = @()
    }
    
    # Process UnusedLicenseList JSON
    $Results = @($Results | ForEach-Object {
        $_.UnusedLicenseList = @(ConvertFrom-Json -ErrorAction SilentlyContinue -InputObject $_.UnusedLicenseList)
        $_
    })

    if (!$Results -or $Results.Count -eq 0) {
        $Results = @{
            Tenant = 'The BPA has not yet run.'
        }
    }
    
    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @($Results)
        })

}
