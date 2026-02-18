Function Invoke-ExecResetPass {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers



    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    $ID = $Request.Query.ID ?? $Request.Body.ID
    $DisplayName = $Request.Query.displayName ?? $Request.Body.displayName ?? $ID
    $MustChange = $Request.Query.MustChange ?? $Request.Body.MustChange
    $MustChange = [System.Convert]::ToBoolean($MustChange)
    $Password = $Request.Query.password ?? $Request.Body.password

    try {
        $ResetParams = @{
            UserID                         = $ID
            tenantFilter                   = $TenantFilter
            APIName                        = $APIName
            Headers                        = $Headers
            forceChangePasswordNextSignIn  = $MustChange
            DisplayName                    = $DisplayName
        }
        if ($Password) {
            $ResetParams['Password'] = $Password
        }
        $Result = Set-CIPPResetPassword @ResetParams
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $Result = $_.Exception.Message
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{'Results' = $Result }
        })

}
