function Get-CippServicePrincipalsByAppId {
    <#
    .SYNOPSIS
    Retrieves service principals for a specific set of appIds using a server-side filter.

    .DESCRIPTION
    Fetches only the requested service principals via $filter=appId in (...) instead of enumerating
    every service principal in the tenant, which can take 30+ seconds and multiple pages in tenants
    with thousands of enterprise applications. Graph's 'in' operator accepts at most 15 values per
    filter clause, so the appIds are requested in chunks of 15.

    .PARAMETER AppIds
    The application (client) IDs of the service principals to retrieve.

    .PARAMETER TenantFilter
    The tenant to query.

    .PARAMETER SkipTokenCache
    Skip the Graph token cache (used by permission-push flows that may run right after consent).

    .FUNCTIONALITY
    Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$AppIds,
        [Parameter(Mandatory)]
        [string]$TenantFilter,
        [switch]$SkipTokenCache
    )

    $AppIds = @($AppIds | Where-Object { $_ } | Sort-Object -Unique)
    $ServicePrincipals = for ($i = 0; $i -lt $AppIds.Count; $i += 15) {
        $Chunk = $AppIds[$i..([Math]::Min($i + 14, $AppIds.Count - 1))]
        $AppIdFilter = $Chunk -join "','"
        New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/servicePrincipals?`$filter=appId in ('$AppIdFilter')&`$select=id,appId,displayName&`$top=999" -tenantid $TenantFilter -NoAuthCheck $true -skipTokenCache $SkipTokenCache.IsPresent
    }
    return @($ServicePrincipals)
}
