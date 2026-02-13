function Invoke-EditExternalCollaboration {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter

    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        # Update authorization policy settings (guest invites, guest role, etc.)
        $AuthPatchBody = @{}

        if ($null -ne $Request.Body.allowInvitesFrom) {
            $AuthPatchBody['allowInvitesFrom'] = $Request.Body.allowInvitesFrom
        }
        if ($null -ne $Request.Body.guestUserRoleId) {
            $AuthPatchBody['guestUserRoleId'] = $Request.Body.guestUserRoleId
        }
        if ($null -ne $Request.Body.allowedToSignUpEmailBasedSubscriptions) {
            $AuthPatchBody['allowedToSignUpEmailBasedSubscriptions'] = [bool]$Request.Body.allowedToSignUpEmailBasedSubscriptions
        }
        if ($null -ne $Request.Body.allowEmailVerifiedUsersToJoinOrganization) {
            $AuthPatchBody['allowEmailVerifiedUsersToJoinOrganization'] = [bool]$Request.Body.allowEmailVerifiedUsersToJoinOrganization
        }
        if ($null -ne $Request.Body.blockMsnSignIn) {
            $AuthPatchBody['blockMsnSignIn'] = [bool]$Request.Body.blockMsnSignIn
        }

        if ($AuthPatchBody.Count -gt 0) {
            $AuthPatchJSON = ConvertTo-Json -Depth 10 -InputObject $AuthPatchBody -Compress
            $null = New-GraphPostRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy/authorizationPolicy' -Type PATCH -Body $AuthPatchJSON -ContentType 'application/json' -AsApp $true
            $Results.Add('Successfully updated authorization policy settings.')
        }

        # Update B2B domain allow/deny lists if provided
        if ($null -ne $Request.Body.domainRestrictions) {
            try {
                # Get existing B2B management policies
                $B2BPolicies = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
                $B2BManagement = $B2BPolicies | Where-Object { $_.type -eq 6 }

                if ($B2BManagement) {
                    $ExistingDef = ($B2BManagement.definition | ConvertFrom-Json)
                    $ExistingDef.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy = $Request.Body.domainRestrictions.InvitationsAllowedAndBlockedDomainsPolicy

                    $UpdateBody = @{
                        definition = @(($ExistingDef | ConvertTo-Json -Depth 20 -Compress))
                    }
                    $UpdateJSON = ConvertTo-Json -Depth 20 -InputObject $UpdateBody -Compress
                    $null = New-GraphPostRequest -tenantid $TenantFilter -Uri "https://graph.microsoft.com/beta/legacy/policies/$($B2BManagement.id)" -Type PATCH -Body $UpdateJSON -ContentType 'application/json' -AsApp $true
                    $Results.Add('Successfully updated domain allow/deny list.')
                }
            } catch {
                $DomainError = Get-NormalizedError -Message $_.Exception.Message
                $Results.Add("Warning: Failed to update domain restrictions: $DomainError")
            }
        }

        if ($Results.Count -eq 0) {
            throw 'No valid settings provided to update.'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($Results -join ' ') -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = ($Results -join ' ')
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to update external collaboration settings: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to update external collaboration settings: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
