function Invoke-ListDynamicsUsers {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Dynamics.User.Read
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

        $Select = 'fullname,domainname,internalemailaddress,isdisabled,accessmode,createdon,modifiedon,azureactivedirectoryobjectid,applicationid,title,address1_telephone1'
        $Expand = 'systemuserroles_association($select=name,roleid),businessunitid($select=name,businessunitid)'
        $Filter = "isdisabled eq false and accessmode ne 3 and accessmode ne 5"

        $Users = New-DynamicsRequest -DynamicsUrl $DynamicsUrl -Entity 'systemusers' `
            -TenantFilter $TenantFilter -Select $Select -Expand $Expand -Filter $Filter -NoAuthCheck $false

        $Results = @($Users | ForEach-Object {
            $user = $_
            [PSCustomObject]@{
                systemuserid     = $user.systemuserid
                fullname         = $user.fullname
                domainname       = $user.domainname
                email            = $user.internalemailaddress
                isdisabled       = $user.isdisabled
                accessmode       = switch ($user.accessmode) {
                    0 { 'Read-Write' }
                    1 { 'Administrative' }
                    2 { 'Read' }
                    3 { 'Support User' }
                    4 { 'Non-Interactive' }
                    5 { 'Delegated Admin' }
                    default { "Unknown ($($user.accessmode))" }
                }
                accessmodeRaw    = $user.accessmode
                businessUnit     = if ($user.businessunitid) { $user.businessunitid.name } else { '' }
                businessUnitId   = if ($user.businessunitid) { $user.businessunitid.businessunitid } else { '' }
                title            = $user.title
                phone            = $user.address1_telephone1
                securityRoles    = @($user.systemuserroles_association | ForEach-Object {
                    [PSCustomObject]@{
                        name   = $_.name
                        roleid = $_.roleid
                    }
                })
                securityRoleList = ($user.systemuserroles_association | ForEach-Object { $_.name }) -join ', '
                createdon        = $user.createdon
                modifiedon       = $user.modifiedon
                azureAdObjectId  = $user.azureactivedirectoryobjectid
            }
        })

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Results }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics users: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
