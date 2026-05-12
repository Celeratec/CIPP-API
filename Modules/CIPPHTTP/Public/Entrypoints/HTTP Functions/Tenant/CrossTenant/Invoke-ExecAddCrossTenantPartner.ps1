function Invoke-ExecAddCrossTenantPartner {
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
        if ([string]::IsNullOrWhiteSpace($Request.Body.partnerTenantId)) {
            throw 'Partner Tenant ID is required.'
        }

        # Build the partner configuration body
        $PartnerBody = @{
            tenantId = $Request.Body.partnerTenantId
        }

        # Add optional B2B Collaboration settings
        if ($null -ne $Request.Body.b2bCollaborationInbound) {
            $PartnerBody['b2bCollaborationInbound'] = $Request.Body.b2bCollaborationInbound
        }
        if ($null -ne $Request.Body.b2bCollaborationOutbound) {
            $PartnerBody['b2bCollaborationOutbound'] = $Request.Body.b2bCollaborationOutbound
        }

        # Add optional B2B Direct Connect settings
        if ($null -ne $Request.Body.b2bDirectConnectInbound) {
            $PartnerBody['b2bDirectConnectInbound'] = $Request.Body.b2bDirectConnectInbound
        }
        if ($null -ne $Request.Body.b2bDirectConnectOutbound) {
            $PartnerBody['b2bDirectConnectOutbound'] = $Request.Body.b2bDirectConnectOutbound
        }

        # Add optional inbound trust settings
        if ($null -ne $Request.Body.inboundTrust) {
            $PartnerBody['inboundTrust'] = $Request.Body.inboundTrust
        }

        # Add optional automatic user consent
        if ($null -ne $Request.Body.automaticUserConsentSettings) {
            $PartnerBody['automaticUserConsentSettings'] = $Request.Body.automaticUserConsentSettings
        }

        $PartnerJSON = ConvertTo-Json -Depth 20 -InputObject $PartnerBody -Compress
        $Result = New-GraphPostRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners' -Type POST -Body $PartnerJSON -ContentType 'application/json' -AsApp $true

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Successfully added cross-tenant partner configuration for tenant $($Request.Body.partnerTenantId)." -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results  = "Successfully added cross-tenant partner configuration for tenant $($Request.Body.partnerTenantId)."
            Metadata = @{ tenantId = $Result.tenantId }
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add cross-tenant partner: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to add cross-tenant partner: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
