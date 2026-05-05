function Invoke-SetAuthMethod {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Administration.ReadWrite
    #>
    Param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers


    # Interact with query parameters or the body of the request.
    $State = if ($Request.Body.state -eq 'enabled') { $true } else { $false }
    $TenantFilter = $Request.Body.tenantFilter
    $AuthenticationMethodId = $Request.Body.Id
    $GroupIds = $Request.Body.GroupIds

    try {
        $Params = @{
            Tenant                 = $TenantFilter
            APIName                = $APIName
            AuthenticationMethodId = $AuthenticationMethodId
            Enabled                = $State
            Headers                = $Headers
        }
        if ($GroupIds) {
            $Params.GroupIds = @($GroupIds)
        }
        $Result = Set-CIPPAuthenticationPolicy @Params
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $Result = "Failed to update authentication method: $((Get-CippException -Exception $_).NormalizedError)"
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = [pscustomobject]@{'Results' = $Result }
        })
}
