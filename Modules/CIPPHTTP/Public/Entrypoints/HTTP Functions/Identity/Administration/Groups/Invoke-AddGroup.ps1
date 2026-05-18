function Invoke-AddGroup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint

    # Extract tenant filter - check for AllTenants first, then extract value
    $TenantInput = $Request.body.tenantFilter.value ?? $Request.body.tenantFilter
    $SelectedTenants = if ($TenantInput -eq 'AllTenants' -or 'AllTenants' -in $TenantInput) {
        (Get-Tenants).defaultDomainName
    } else {
        @($TenantInput)
    }

    $GroupObject = $Request.body
    $StatusCode = [HttpStatusCode]::OK

    if (-not $SelectedTenants -or $SelectedTenants.Count -eq 0) {
        $Results = 'No tenant specified for group creation'
        $StatusCode = [HttpStatusCode]::BadRequest
    } else {
        $Results = foreach ($tenant in $SelectedTenants) {
            try {
                # Use the centralized New-CIPPGroup function
                $Result = New-CIPPGroup -GroupObject $GroupObject -TenantFilter $tenant -APIName $APIName -ExecutingUser $Request.Headers.'x-ms-client-principal-name'

                if ($Result.Success) {
                    "Successfully created group $($GroupObject.displayName) for $($tenant)"
                } else {
                    throw $Result.Message
                }
            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                "Failed to create group. $($GroupObject.displayName) for $($tenant) $($ErrorMessage.NormalizedError)"
                $StatusCode = [HttpStatusCode]::InternalServerError
            }
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{'Results' = @($Results) }
        })
}
