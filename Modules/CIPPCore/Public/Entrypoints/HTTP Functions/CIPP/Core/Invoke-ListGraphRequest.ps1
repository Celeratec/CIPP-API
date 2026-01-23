
function Invoke-ListGraphRequest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $Message = 'Accessed this API | Endpoint: {0}' -f $Request.Query.Endpoint
    Write-LogMessage -headers $Headers -API $APIName -message $Message -Sev 'Debug'

    $CippLink = ([System.Uri]$TriggerMetadata.Headers.Referer).PathAndQuery

    # Simple backend cache for common list endpoints (5 min TTL)
    $CacheAllowlist = @('users', 'groups', 'devices', 'servicePrincipals', 'applications')
    $CacheTtlMinutes = 5
    $CacheKey = $null
    $CacheTable = $null

    function Get-CacheKey {
        param(
            [string]$TenantFilter,
            [string]$Endpoint,
            [hashtable]$Parameters
        )
        $raw = @{
            TenantFilter = $TenantFilter
            Endpoint     = $Endpoint
            Parameters   = $Parameters
        } | ConvertTo-Json -Depth 5 -Compress
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
        $hash = $sha.ComputeHash($bytes)
        return ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
    }

    $Parameters = @{}
    if ($Request.Query.'$filter') {
        $Parameters.'$filter' = $Request.Query.'$filter'
    }

    if (!$Request.Query.'$filter' -and $Request.Query.graphFilter) {
        $Parameters.'$filter' = $Request.Query.graphFilter
    }

    if ($Request.Query.'$select') {
        $Parameters.'$select' = $Request.Query.'$select'
    }

    if ($Request.Query.'$expand') {
        $Parameters.'$expand' = $Request.Query.'$expand'
    }

    if ($Request.Query.expand) {
        $Parameters.'expand' = $Request.Query.expand
    }

    if ($Request.Query.'$top') {
        $Parameters.'$top' = $Request.Query.'$top'
    }

    if ($Request.Query.'$count') {
        $Parameters.'$count' = ([string]([System.Boolean]$Request.Query.'$count')).ToLower()
    }


    if ($Request.Query.'$orderby') {
        $Parameters.'$orderby' = $Request.Query.'$orderby'
    }

    if ($Request.Query.'$search') {
        $Parameters.'$search' = $Request.Query.'$search'
    }

    if ($Request.Query.'$format') {
        $Parameters.'$format' = $Request.Query.'$format'
    }

    $GraphRequestParams = @{
        Endpoint   = $Request.Query.Endpoint
        Parameters = $Parameters
        CippLink   = $CippLink
    }

    if ($Request.Query.TenantFilter) {
        $GraphRequestParams.TenantFilter = $Request.Query.TenantFilter
    }

    if ($Request.Query.QueueId) {
        $GraphRequestParams.QueueId = $Request.Query.QueueId
    }

    if ($Request.Query.Version) {
        $GraphRequestParams.Version = $Request.Query.Version
    }

    if ($Request.Query.NoPagination) {
        $GraphRequestParams.NoPagination = [System.Boolean]$Request.Query.NoPagination
    }

    if ($Request.Query.manualPagination) {
        $GraphRequestParams.ManualPagination = [System.Boolean]$Request.Query.manualPagination
    }

    if ($Request.Query.nextLink) {
        $GraphRequestParams.nextLink = $Request.Query.nextLink
    }

    if ($Request.Query.CountOnly) {
        $GraphRequestParams.CountOnly = [System.Boolean]$Request.Query.CountOnly
    }

    if ($Request.Query.QueueNameOverride) {
        $GraphRequestParams.QueueNameOverride = [string]$Request.Query.QueueNameOverride
    }

    if ($Request.Query.ReverseTenantLookup) {
        $GraphRequestParams.ReverseTenantLookup = [System.Boolean]$Request.Query.ReverseTenantLookup
    }

    if ($Request.Query.ReverseTenantLookupProperty) {
        $GraphRequestParams.ReverseTenantLookupProperty = $Request.Query.ReverseTenantLookupProperty
    }

    if ($Request.Query.SkipCache) {
        $GraphRequestParams.SkipCache = [System.Boolean]$Request.Query.SkipCache
    }

    # Backend cache: only for allowlisted endpoints and simple list queries
    $ShouldUseBackendCache = $false
    if ($Request.Query.TenantFilter -and $CacheAllowlist -contains $Request.Query.Endpoint) {
        if (-not $Request.Query.nextLink `
            -and -not $Request.Query.QueueId `
            -and -not $Request.Query.ManualPagination `
            -and -not $Request.Query.NoPagination `
            -and -not $Request.Query.CountOnly `
            -and -not $Request.Query.ListProperties `
            -and -not $Request.Query.ReverseTenantLookup `
            -and -not $Request.Query.SkipCache) {
            $ShouldUseBackendCache = $true
        }
    }

    if ($Request.Query.ListProperties) {
        $GraphRequestParams.NoPagination = $true
        $GraphRequestParams.Parameters.'$select' = ''
        if ($Request.Query.TenantFilter -eq 'AllTenants') {
            $GraphRequestParams.TenantFilter = (Get-Tenants | Select-Object -First 1).customerId
        }
    }

    if ($Request.Query.AsApp) {
        $GraphRequestParams.AsApp = $true
    }

    $Metadata = $GraphRequestParams

    try {
        # Try backend cache first
        if ($ShouldUseBackendCache) {
            try {
                $CacheTable = Get-CippTable -tablename 'CacheGraphRequest'
                $CacheKey = Get-CacheKey -TenantFilter $Request.Query.TenantFilter -Endpoint $Request.Query.Endpoint -Parameters $Parameters
                $CacheCutoff = (Get-Date).AddMinutes(-$CacheTtlMinutes).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                $CacheFilter = "PartitionKey eq '$($Request.Query.TenantFilter)' and RowKey eq '$CacheKey' and CachedAt ge '$CacheCutoff'"
                $Cached = Get-CIPPAzDataTableEntity @CacheTable -Filter $CacheFilter
                if ($Cached -and $Cached.Data) {
                    $CachedData = $Cached.Data | ConvertFrom-Json -Depth 10
                    return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::OK
                        Body       = $CachedData
                        Headers    = @{ 'X-Cache' = 'HIT' }
                    })
                }
            } catch {
                Write-Information "GraphRequest cache lookup failed: $($_.Exception.Message)"
            }
        }

        $Results = Get-GraphRequestList @GraphRequestParams

        if ($script:LastGraphResponseHeaders) {
            $Metadata.GraphHeaders = $script:LastGraphResponseHeaders
        }

        if ($Results | Where-Object { $_.PSObject.Properties.Name -contains 'nextLink' }) {
            if (![string]::IsNullOrEmpty($Results.nextLink) -and $Request.Query.TenantFilter -ne 'AllTenants') {
                Write-Host "NextLink: $($Results.nextLink | Where-Object { $_ } | Select-Object -Last 1)"
                $Metadata['nextLink'] = $Results.nextLink | Where-Object { $_ } | Select-Object -Last 1
            }
            # Remove nextLink trailing object only if it’s the last item
            $Results = $Results | Where-Object { $_.PSObject.Properties.Name -notcontains 'nextLink' }
        }
        if ($Request.Query.ListProperties) {
            $Columns = ($Results | Select-Object -First 1).PSObject.Properties.Name
            $Results = $Columns | Where-Object { @('Tenant', 'CippStatus') -notcontains $_ }
        } else {
            if ($Results.Queued -eq $true) {
                $Metadata.Queued = $Results.Queued
                $Metadata.QueueMessage = $Results.QueueMessage
                $Metadata.QueueId = $Results.QueueId
                $Results = @()
            }
        }

        if ($Request.Headers.'x-ms-coldstart' -eq 1) {
            $Metadata.ColdStart = $true
        }

        $GraphRequestData = [PSCustomObject]@{
            Results  = @($Results)
            Metadata = $Metadata
        }
        $StatusCode = [HttpStatusCode]::OK

        # Store in backend cache
        if ($ShouldUseBackendCache -and $CacheTable -and $CacheKey) {
            try {
                $Entity = @{
                    PartitionKey = $Request.Query.TenantFilter
                    RowKey       = $CacheKey
                    Data         = [string]($GraphRequestData | ConvertTo-Json -Depth 10 -Compress)
                    CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }
                Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null
            } catch {
                Write-Information "GraphRequest cache write failed: $($_.Exception.Message)"
            }
        }
    } catch {
        $GraphRequestData = "Graph Error: $(Get-NormalizedError $_.Exception.Message) - Endpoint: $($Request.Query.Endpoint)"
        if ($Request.Query.IgnoreErrors) { $StatusCode = [HttpStatusCode]::OK }
        else { $StatusCode = [HttpStatusCode]::BadRequest }
    }

    if ($request.Query.Sort) {
        $GraphRequestData.Results = $GraphRequestData.Results | Sort-Object -Property $request.Query.Sort
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $GraphRequestData
        })
}
