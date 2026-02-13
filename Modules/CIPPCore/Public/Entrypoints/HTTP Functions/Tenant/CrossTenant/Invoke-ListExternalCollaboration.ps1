function Invoke-ListExternalCollaboration {
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
        # Use bulk request to fetch authorization policy and external identities settings in parallel
        $Requests = @(
            @{
                id     = 'authorizationPolicy'
                url    = 'policies/authorizationPolicy'
                method = 'GET'
            }
        )

        $BulkResults = New-GraphBulkRequest -Requests $Requests -tenantid $TenantFilter -asapp $true
        $AuthPolicy = ($BulkResults | Where-Object { $_.id -eq 'authorizationPolicy' }).body

        # Map guest invite setting to human-readable labels
        $InviteSettingMap = @{
            'adminsAndGuestInviters'              = 'Only admins and users in the Guest Inviter role'
            'adminsGuestInvitersAndAllMembers'     = 'Member users and users assigned to specific admin roles'
            'everyone'                             = 'Anyone in the organization including guests'
            'none'                                 = 'No one in the organization'
        }

        # Map guest user role ID to human-readable labels
        $GuestRoleMap = @{
            'a0b1b346-4d3e-4e8b-98f8-753987be4970' = 'User (same access as members)'
            '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Guest User (default, limited access)'
            '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted Guest User (most restrictive)'
        }

        # Attempt to get B2B management policies (domain allow/deny lists)
        $DomainRestrictions = $null
        try {
            $B2BPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
            $B2BManagement = $B2BPolicy | Where-Object { $_.type -eq 6 }
            if ($B2BManagement) {
                $B2BDefinition = ($B2BManagement.definition | ConvertFrom-Json).B2BManagementPolicy
                $DomainRestrictions = [PSCustomObject]@{
                    InvitationsAllowedAndBlockedDomainsPolicy = $B2BDefinition.InvitationsAllowedAndBlockedDomainsPolicy
                }
            }
        } catch {
            # B2B management policy may not be available in all tenants
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not retrieve B2B management policy (non-critical): $($_.Exception.Message)" -Sev 'Debug'
        }

        $Result = [PSCustomObject]@{
            Tenant                                        = $TenantFilter
            allowInvitesFrom                              = $AuthPolicy.allowInvitesFrom
            allowInvitesFromLabel                         = $InviteSettingMap[$AuthPolicy.allowInvitesFrom] ?? $AuthPolicy.allowInvitesFrom
            guestUserRoleId                               = $AuthPolicy.guestUserRoleId
            guestUserRoleLabel                            = $GuestRoleMap[$AuthPolicy.guestUserRoleId] ?? 'Custom Role'
            allowedToSignUpEmailBasedSubscriptions         = $AuthPolicy.allowedToSignUpEmailBasedSubscriptions
            allowEmailVerifiedUsersToJoinOrganization     = $AuthPolicy.allowEmailVerifiedUsersToJoinOrganization
            blockMsnSignIn                                = $AuthPolicy.blockMsnSignIn
            domainRestrictions                            = $DomainRestrictions
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = $Result
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to retrieve external collaboration settings: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve external collaboration settings: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
