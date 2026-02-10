function Invoke-ListDynamicsSecurityRoles {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Dynamics.SecurityRole.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.TenantFilter
    $DynamicsUrl = $Request.Query.DynamicsUrl

    try {
        $APIName = $Request.Params.CIPPEndpoint
        Write-LogMessage -headers $Request.Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

        if ([string]::IsNullOrEmpty($DynamicsUrl)) {
            throw 'DynamicsUrl query parameter is required. Select an environment first.'
        }

        $Select = 'name,roleid,ismanaged,createdon,modifiedon,isinherited,canbedeleted'
        $Expand = 'businessunitid($select=name,businessunitid)'
        $OrderBy = 'name asc'

        $Roles = New-DynamicsRequest -DynamicsUrl $DynamicsUrl -Entity 'roles' `
            -TenantFilter $TenantFilter -Select $Select -Expand $Expand -OrderBy $OrderBy -NoAuthCheck $false

        $Results = @($Roles | ForEach-Object {
            $role = $_
            [PSCustomObject]@{
                roleid       = $role.roleid
                name         = $role.name
                ismanaged    = $role.ismanaged
                isinherited  = $role.isinherited
                canbedeleted = if ($role.canbedeleted) { $role.canbedeleted.Value } else { $true }
                businessUnit = if ($role.businessunitid) { $role.businessunitid.name } else { '' }
                businessUnitId = if ($role.businessunitid) { $role.businessunitid.businessunitid } else { '' }
                createdon    = $role.createdon
                modifiedon   = $role.modifiedon
                roleType     = if ($role.ismanaged) { 'Managed' } else { 'Custom' }
            }
        })

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Results }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics security roles: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
