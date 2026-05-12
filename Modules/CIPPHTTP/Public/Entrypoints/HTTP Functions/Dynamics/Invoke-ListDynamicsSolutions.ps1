function Invoke-ListDynamicsSolutions {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Dynamics.Solution.Read
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

        $Select = 'friendlyname,uniquename,version,ismanaged,isvisible,installedon,modifiedon,createdon,description'
        $Expand = 'publisherid($select=friendlyname,uniquename)'
        $Filter = 'isvisible eq true'
        $OrderBy = 'friendlyname asc'

        $Solutions = New-DynamicsRequest -DynamicsUrl $DynamicsUrl -Entity 'solutions' `
            -TenantFilter $TenantFilter -Select $Select -Expand $Expand -Filter $Filter -OrderBy $OrderBy -NoAuthCheck $false

        $Results = @($Solutions | ForEach-Object {
            $sol = $_
            [PSCustomObject]@{
                solutionid      = $sol.solutionid
                friendlyname    = $sol.friendlyname
                uniquename      = $sol.uniquename
                version         = $sol.version
                ismanaged       = $sol.ismanaged
                publisher       = if ($sol.publisherid) { $sol.publisherid.friendlyname } else { '' }
                publisherUnique = if ($sol.publisherid) { $sol.publisherid.uniquename } else { '' }
                description     = $sol.description
                installedon     = $sol.installedon
                createdon       = $sol.createdon
                modifiedon      = $sol.modifiedon
                solutionType    = if ($sol.ismanaged) { 'Managed' } else { 'Unmanaged' }
            }
        })

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Results }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to list Dynamics solutions: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
