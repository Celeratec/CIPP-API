function Invoke-ListCrossTenantPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.tenantFilter

    try {
        # Retrieve the full default cross-tenant access policy
        $DefaultPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -tenantid $TenantFilter -AsApp $true

        # Build a structured response
        $Result = [PSCustomObject]@{
            Tenant                       = $TenantFilter
            b2bCollaborationInbound      = $DefaultPolicy.b2bCollaborationInbound
            b2bCollaborationOutbound     = $DefaultPolicy.b2bCollaborationOutbound
            b2bDirectConnectInbound      = $DefaultPolicy.b2bDirectConnectInbound
            b2bDirectConnectOutbound     = $DefaultPolicy.b2bDirectConnectOutbound
            inboundTrust                 = $DefaultPolicy.inboundTrust
            tenantRestrictions           = $DefaultPolicy.tenantRestrictions
            automaticUserConsentSettings = $DefaultPolicy.automaticUserConsentSettings
            isServiceDefault             = $DefaultPolicy.isServiceDefault
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = $Result
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to retrieve cross-tenant access policy: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve cross-tenant access policy: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
