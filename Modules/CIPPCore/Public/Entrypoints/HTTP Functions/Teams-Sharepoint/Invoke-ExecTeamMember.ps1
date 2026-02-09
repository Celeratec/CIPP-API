Function Invoke-ExecTeamMember {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.TenantFilter
    $TeamID = $Request.Body.TeamID
    $Action = $Request.Body.Action
    $DisplayName = $Request.Body.DisplayName

    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }
    if (-not $TeamID) { $TeamID = $Request.Query.TeamID }

    $TeamLabel = if ($DisplayName) { $DisplayName } else { $TeamID }

    try {
        switch ($Action) {
            'Add' {
                $UserID = $Request.Body.UserID
                # Support autocomplete/select field format: { value: "...", label: "..." }
                if ($UserID -is [hashtable] -or $UserID -is [PSCustomObject]) {
                    $UserID = $UserID.value
                } elseif ($UserID -is [System.Collections.IDictionary]) {
                    $UserID = $UserID['value']
                }
                $Role = $Request.Body.Role
                if (-not $Role) { $Role = 'member' }

                [string[]]$Roles = if ($Role -eq 'owner') { @('owner') } else { @() }

                $Body = @{
                    '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                    'roles'           = $Roles
                    'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$UserID')"
                } | ConvertTo-Json -Depth 5

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members" -tenantid $TenantFilter -type POST -body $Body
                $Message = "Successfully added user as $Role to team '$TeamLabel'"
            }
            'Remove' {
                $MembershipID = $Request.Body.MembershipID
                # Support autocomplete/select field format
                if ($MembershipID -is [hashtable] -or $MembershipID -is [PSCustomObject]) {
                    $MembershipID = $MembershipID.value
                } elseif ($MembershipID -is [System.Collections.IDictionary]) {
                    $MembershipID = $MembershipID['value']
                }

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members/$MembershipID" -tenantid $TenantFilter -type DELETE
                $Message = "Successfully removed member from team '$TeamLabel'"
            }
            'SetRole' {
                $MembershipID = $Request.Body.MembershipID
                if ($MembershipID -is [hashtable] -or $MembershipID -is [PSCustomObject]) {
                    $MembershipID = $MembershipID.value
                } elseif ($MembershipID -is [System.Collections.IDictionary]) {
                    $MembershipID = $MembershipID['value']
                }
                $Role = $Request.Body.Role
                if (-not $Role) { $Role = 'member' }

                [string[]]$Roles = if ($Role -eq 'owner') { @('owner') } else { @() }
                $Body = @{
                    '@odata.type' = '#microsoft.graph.aadUserConversationMember'
                    'roles'       = $Roles
                } | ConvertTo-Json -Depth 5

                $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members/$MembershipID" -tenantid $TenantFilter -type PATCH -body $Body
                $Message = "Successfully changed member role to '$Role' in team '$TeamLabel'"
            }
            default {
                throw "Unknown action: $Action. Supported actions: Add, Remove, SetRole"
            }
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to $Action member in team '$TeamLabel'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
