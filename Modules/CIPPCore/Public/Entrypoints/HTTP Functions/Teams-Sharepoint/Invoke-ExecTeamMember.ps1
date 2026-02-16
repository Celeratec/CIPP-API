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

                # Add member via the M365 Group membership API (Team ID = Group ID).
                # This is more reliable than the Teams conversation member API,
                # especially for guest users whose objects may still be propagating.
                $null = Add-CIPPGroupMember -GroupType 'Team' -GroupID $TeamID -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
                $Message = "Successfully added user as $Role to team '$TeamLabel'"

                # If adding as owner, also set the owner role via Teams API
                if ($Role -eq 'owner') {
                    try {
                        # Look up the membership ID to promote to owner
                        $TeamMembers = New-GraphGetRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members" -tenantid $TenantFilter
                        $NewMember = $TeamMembers | Where-Object { $_.userId -eq $UserID }
                        if ($NewMember) {
                            [string[]]$OwnerRoles = @('owner')
                            $RoleBody = @{
                                '@odata.type' = '#microsoft.graph.aadUserConversationMember'
                                'roles'       = $OwnerRoles
                            } | ConvertTo-Json -Depth 5
                            $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$TeamID/members/$($NewMember.id)" -tenantid $TenantFilter -type PATCH -body $RoleBody
                            $Message = "Successfully added user as owner to team '$TeamLabel'"
                        }
                    } catch {
                        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Added member but failed to set owner role: $($_.Exception.Message)" -Sev 'Warning'
                        $Message = "Added user to team '$TeamLabel' as member (owner role promotion failed - you can promote them from the team members list)"
                    }
                }
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
