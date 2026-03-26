function Invoke-ListDynamicsEnvironments {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Dynamics.Environment.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.TenantFilter

    try {
        $APIName = $Request.Params.CIPPEndpoint
        Write-LogMessage -headers $Request.Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

        # Use the Power Platform BAP API to list environments
        $Scope = 'https://api.bap.microsoft.com/.default'
        $Token = Get-GraphToken -Tenantid $TenantFilter -scope $Scope

        $Headers = @{
            Authorization = $Token.Authorization
            'User-Agent'  = "CIPP/$($global:CippVersion ?? '1.0')"
        }

        $Uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2020-10-01&$expand=properties.capacity,properties.addons'

        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method GET -ContentType 'application/json'

        $Environments = @($Response.value | ForEach-Object {
            $env = $_
            $props = $env.properties
            [PSCustomObject]@{
                id               = $env.id
                name             = $env.name
                displayName      = $props.displayName
                environmentType  = $props.environmentType
                state            = $props.states.management.id
                region           = $props.azureRegion
                url              = if ($props.linkedEnvironmentMetadata.instanceUrl) { $props.linkedEnvironmentMetadata.instanceUrl } else { '' }
                apiUrl           = if ($props.linkedEnvironmentMetadata.instanceApiUrl) { $props.linkedEnvironmentMetadata.instanceApiUrl } else { '' }
                domainName       = if ($props.linkedEnvironmentMetadata.domainName) { $props.linkedEnvironmentMetadata.domainName } else { '' }
                version          = if ($props.linkedEnvironmentMetadata.version) { $props.linkedEnvironmentMetadata.version } else { '' }
                securityGroupId  = if ($props.linkedEnvironmentMetadata.securityGroupId) { $props.linkedEnvironmentMetadata.securityGroupId } else { '' }
                orgId            = if ($props.linkedEnvironmentMetadata.resourceId) { $props.linkedEnvironmentMetadata.resourceId } else { '' }
                createdTime      = $props.createdTime
                lastModifiedTime = if ($props.lastModifiedTime) { $props.lastModifiedTime } else { '' }
                capacityUsed     = if ($props.capacity) { $props.capacity } else { $null }
                isDefault        = if ($props.isDefault) { $props.isDefault } else { $false }
            }
        })

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Environments }
    } catch {
        $RawError = $_.Exception.Message
        $ErrorMessage = Get-NormalizedError -Message $RawError
        if ([string]::IsNullOrWhiteSpace($ErrorMessage)) {
            $ErrorMessage = $RawError
        }

        if ($RawError -like '*AADSTS65001*') {
            $ErrorMessage = @(
                "Power Platform API consent error for tenant $TenantFilter (AADSTS65001)."
                'This error occurs when the token for api.bap.microsoft.com cannot be acquired.'
                'Most common cause: The GDAP relationship does not include the Power Platform Administrator or Dynamics 365 Administrator role.'
                'Even if CPV shows ''All delegated permissions exist for Power Platform API'', the GDAP relationship must also grant an admin role for Power Platform access.'
                'Remediation steps:'
                '1) Verify the GDAP relationship includes Power Platform Administrator or Dynamics 365 Administrator role - this is the most common fix'
                '2) If GDAP roles are correct, re-run CPV Refresh for this tenant and check for failures related to the Power Platform API service principal'
                '3) Verify the tenant has active Power Platform or Dynamics 365 licenses'
                '4) If the issue persists, check Azure AD > Enterprise Applications in the client tenant for the CIPP app and confirm the Power Platform API (8578e004-a5c6-46e7-913e-12f58912df43) delegated consent is listed'
            ) -join ' '
        } elseif ($RawError -like '*AADSTS*' -or $RawError -like '*Could not get token*') {
            $ErrorMessage = "Failed to acquire Power Platform token for $TenantFilter. $ErrorMessage. Ensure the GDAP relationship includes the Power Platform Administrator or Dynamics 365 Administrator role."
        } elseif ($ErrorMessage -like '*Forbidden*' -or $ErrorMessage -like '*403*' -or $ErrorMessage -like '*Unauthorized*' -or $ErrorMessage -like '*401*') {
            $ErrorMessage = "Access denied to Power Platform Admin API for $TenantFilter. Verify the tenant has Dynamics 365 / Power Platform licenses and that the GDAP relationship includes the required admin roles."
        }
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics environments: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
