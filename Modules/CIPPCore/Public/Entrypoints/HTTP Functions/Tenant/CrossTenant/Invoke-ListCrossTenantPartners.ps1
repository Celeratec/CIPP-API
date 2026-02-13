function Invoke-ListCrossTenantPartners {
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
        # Get all partner cross-tenant configurations
        $Partners = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners' -tenantid $TenantFilter -AsApp $true

        $Results = foreach ($Partner in $Partners) {
            # Attempt to resolve the partner tenant name
            $PartnerName = 'Unknown'
            try {
                $TenantInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/tenantRelationships/findTenantInformationByTenantId(tenantId='$($Partner.tenantId)')" -tenantid $TenantFilter -AsApp $true
                $PartnerName = $TenantInfo.displayName
            } catch {
                # Tenant info lookup may fail for some tenants
            }

            [PSCustomObject]@{
                tenantId                     = $Partner.tenantId
                partnerName                  = $PartnerName
                isServiceProvider            = $Partner.isServiceProvider
                isInMultiTenantOrganization  = $Partner.isInMultiTenantOrganization
                b2bCollaborationInbound      = $Partner.b2bCollaborationInbound
                b2bCollaborationOutbound     = $Partner.b2bCollaborationOutbound
                b2bDirectConnectInbound      = $Partner.b2bDirectConnectInbound
                b2bDirectConnectOutbound     = $Partner.b2bDirectConnectOutbound
                inboundTrust                 = $Partner.inboundTrust
                automaticUserConsentSettings = $Partner.automaticUserConsentSettings
                identitySynchronization      = $Partner.identitySynchronization
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = @($Results)
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to list cross-tenant partners: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = [PSCustomObject]@{
            Results = "Failed to list cross-tenant partners: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
