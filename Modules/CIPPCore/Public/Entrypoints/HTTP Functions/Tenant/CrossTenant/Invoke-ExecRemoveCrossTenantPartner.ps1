function Invoke-ExecRemoveCrossTenantPartner {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter ?? $Request.Query.tenantFilter

    try {
        $PartnerTenantId = $Request.Body.partnerTenantId ?? $Request.Query.partnerTenantId
        if ([string]::IsNullOrWhiteSpace($PartnerTenantId)) {
            throw 'Partner Tenant ID is required.'
        }

        $null = New-GraphPostRequest -tenantid $TenantFilter -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners/$PartnerTenantId" -Type DELETE -AsApp $true

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Successfully removed cross-tenant partner configuration for $PartnerTenantId." -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = "Successfully removed cross-tenant partner configuration for $PartnerTenantId."
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to remove cross-tenant partner $($PartnerTenantId): $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to remove cross-tenant partner: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
