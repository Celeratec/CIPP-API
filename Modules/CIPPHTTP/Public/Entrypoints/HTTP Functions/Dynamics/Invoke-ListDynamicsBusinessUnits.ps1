function Invoke-ListDynamicsBusinessUnits {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Dynamics.BusinessUnit.Read
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

        $Select = 'name,businessunitid,isdisabled,createdon,modifiedon,websiteurl,divisionname,emailaddress,address1_city,address1_stateorprovince,address1_country'
        $Expand = 'parentbusinessunitid($select=name,businessunitid)'
        $OrderBy = 'name asc'

        $BusinessUnits = New-DynamicsRequest -DynamicsUrl $DynamicsUrl -Entity 'businessunits' `
            -TenantFilter $TenantFilter -Select $Select -Expand $Expand -OrderBy $OrderBy -NoAuthCheck $false

        $Results = @($BusinessUnits | ForEach-Object {
            $bu = $_
            [PSCustomObject]@{
                businessunitid   = $bu.businessunitid
                name             = $bu.name
                isdisabled       = $bu.isdisabled
                parentName       = if ($bu.parentbusinessunitid) { $bu.parentbusinessunitid.name } else { '(Root)' }
                parentId         = if ($bu.parentbusinessunitid) { $bu.parentbusinessunitid.businessunitid } else { '' }
                divisionname     = $bu.divisionname
                emailaddress     = $bu.emailaddress
                websiteurl       = $bu.websiteurl
                city             = $bu.address1_city
                stateOrProvince  = $bu.address1_stateorprovince
                country          = $bu.address1_country
                createdon        = $bu.createdon
                modifiedon       = $bu.modifiedon
                isRoot           = if ($null -eq $bu.parentbusinessunitid) { $true } else { $false }
            }
        })

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Results }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics business units: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
