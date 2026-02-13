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

        # Resolve partner tenant names via bulk request using the CIPP service tenant
        $TenantLookup = @{}
        if ($Partners.Count -gt 0) {
            try {
                $ReverseLookupRequests = $Partners | ForEach-Object {
                    @{
                        id     = $_.tenantId
                        url    = "tenantRelationships/findTenantInformationByTenantId(tenantId='$($_.tenantId)')"
                        method = 'GET'
                    }
                }
                $LookupResults = New-GraphBulkRequest -Requests @($ReverseLookupRequests) -tenantid $env:TenantID -NoAuthCheck $true -asapp $true
                foreach ($Result in $LookupResults) {
                    if ($Result.body.displayName) {
                        $TenantLookup[$Result.id] = $Result.body.displayName
                    }
                }
            } catch {
                Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not resolve partner tenant names: $($_.Exception.Message)" -Sev 'Debug'
            }
        }

        $Results = foreach ($Partner in $Partners) {
            [PSCustomObject]@{
                tenantId                     = $Partner.tenantId
                partnerName                  = $TenantLookup[$Partner.tenantId] ?? 'Unknown'
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
