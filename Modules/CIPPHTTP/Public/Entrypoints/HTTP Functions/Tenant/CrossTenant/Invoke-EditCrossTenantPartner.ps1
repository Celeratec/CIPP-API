function Invoke-EditCrossTenantPartner {
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
    $TenantFilter = $Request.Body.tenantFilter

    try {
        $PartnerTenantId = $Request.Body.partnerTenantId
        if ([string]::IsNullOrWhiteSpace($PartnerTenantId)) {
            throw 'Partner Tenant ID is required.'
        }

        # Build the patch body - only include fields that were submitted
        $PatchBody = @{}

        if ($null -ne $Request.Body.b2bCollaborationInbound) {
            $PatchBody['b2bCollaborationInbound'] = $Request.Body.b2bCollaborationInbound
        }
        if ($null -ne $Request.Body.b2bCollaborationOutbound) {
            $PatchBody['b2bCollaborationOutbound'] = $Request.Body.b2bCollaborationOutbound
        }
        if ($null -ne $Request.Body.b2bDirectConnectInbound) {
            $PatchBody['b2bDirectConnectInbound'] = $Request.Body.b2bDirectConnectInbound
        }
        if ($null -ne $Request.Body.b2bDirectConnectOutbound) {
            $PatchBody['b2bDirectConnectOutbound'] = $Request.Body.b2bDirectConnectOutbound
        }
        if ($null -ne $Request.Body.inboundTrust) {
            $PatchBody['inboundTrust'] = $Request.Body.inboundTrust
        }
        if ($null -ne $Request.Body.automaticUserConsentSettings) {
            $PatchBody['automaticUserConsentSettings'] = $Request.Body.automaticUserConsentSettings
        }

        if ($PatchBody.Count -eq 0) {
            throw 'No valid partner policy fields provided to update.'
        }

        $PatchJSON = ConvertTo-Json -Depth 20 -InputObject $PatchBody -Compress
        $null = New-GraphPostRequest -tenantid $TenantFilter -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners/$PartnerTenantId" -Type PATCH -Body $PatchJSON -ContentType 'application/json' -AsApp $true

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Successfully updated cross-tenant partner configuration for $PartnerTenantId." -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = "Successfully updated cross-tenant partner configuration for $PartnerTenantId."
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to update cross-tenant partner $($PartnerTenantId): $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to update cross-tenant partner: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
