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
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics environments: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
