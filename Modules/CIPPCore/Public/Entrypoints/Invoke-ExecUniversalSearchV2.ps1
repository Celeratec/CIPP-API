function Invoke-ExecUniversalSearchV2 {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $SearchTerms = $Request.Query.searchTerms
    $Limit = if ($Request.Query.limit) { [int]$Request.Query.limit } else { 10 }
    $Type = if ($Request.Query.type) { $Request.Query.type } else { 'Users' }
    $TenantFilter = $Request.Query.tenantFilter

    $SearchParams = @{
        SearchTerms = $SearchTerms
        Limit       = $Limit
    }
    if ($TenantFilter) {
        $SearchParams.TenantFilter = $TenantFilter
    }

    switch ($Type) {
        'Users' {
            $Results = Search-CIPPDbData @SearchParams -Types 'Users' -Properties 'id', 'userPrincipalName', 'displayName'
        }
        'Groups' {
            $Results = Search-CIPPDbData @SearchParams -Types 'Groups' -Properties 'id', 'displayName', 'mail', 'mailEnabled', 'securityEnabled', 'groupTypes', 'description'
        }
        default {
            $Results = Search-CIPPDbData @SearchParams -Types 'Users' -Properties 'id', 'userPrincipalName', 'displayName'
        }
    }

    Write-Information "Results: $($Results | ConvertTo-Json -Depth 10)"

    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Results)
    }

}
