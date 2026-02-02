function Invoke-ExecRemoveRoleMember {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.Role.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.TenantFilter
    $RoleId = $Request.Body.RoleId
    $MemberId = $Request.Body.MemberId
    $RoleName = $Request.Body.RoleName
    $MemberName = $Request.Body.MemberName

    try {
        # Remove the member from the directory role
        $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/directoryRoles/$RoleId/members/$MemberId/`$ref" -tenantid $TenantFilter -type DELETE

        $Results = "Successfully removed $MemberName from the $RoleName role"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results = "Failed to remove member from role. $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Error'
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Results }
    }
}
