function Invoke-ExecApplyCrossTenantTemplate {
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

    try {
        $GUID = $Request.Body.GUID
        if ([string]::IsNullOrWhiteSpace($GUID)) {
            throw 'Template GUID is required.'
        }
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        # Retrieve the template
        $Table = Get-CippTable -tablename 'templates'
        $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CrossTenantTemplate' and RowKey eq '$GUID'"

        if (-not $Entity) {
            throw "Template with GUID $GUID not found."
        }

        $Template = $Entity.JSON | ConvertFrom-Json
        $Settings = $Template.settings
        $Results = [System.Collections.Generic.List[string]]::new()

        # Apply Cross-Tenant Access Policy defaults
        $CrossTenantPatch = @{}
        if ($null -ne $Settings.b2bCollaborationInbound) { $CrossTenantPatch['b2bCollaborationInbound'] = $Settings.b2bCollaborationInbound }
        if ($null -ne $Settings.b2bCollaborationOutbound) { $CrossTenantPatch['b2bCollaborationOutbound'] = $Settings.b2bCollaborationOutbound }
        if ($null -ne $Settings.b2bDirectConnectInbound) { $CrossTenantPatch['b2bDirectConnectInbound'] = $Settings.b2bDirectConnectInbound }
        if ($null -ne $Settings.b2bDirectConnectOutbound) { $CrossTenantPatch['b2bDirectConnectOutbound'] = $Settings.b2bDirectConnectOutbound }
        if ($null -ne $Settings.inboundTrust) { $CrossTenantPatch['inboundTrust'] = $Settings.inboundTrust }
        if ($null -ne $Settings.tenantRestrictions) { $CrossTenantPatch['tenantRestrictions'] = $Settings.tenantRestrictions }
        if ($null -ne $Settings.automaticUserConsentSettings) { $CrossTenantPatch['automaticUserConsentSettings'] = $Settings.automaticUserConsentSettings }

        if ($CrossTenantPatch.Count -gt 0) {
            try {
                $CrossTenantJSON = ConvertTo-Json -Depth 20 -InputObject $CrossTenantPatch -Compress
                $null = New-GraphPostRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -Type PATCH -Body $CrossTenantJSON -ContentType 'application/json' -AsApp $true
                $Results.Add('Cross-tenant access policy defaults applied.')
            } catch {
                $ErrorMsg = Get-NormalizedError -Message $_.Exception.Message
                $Results.Add("Failed to apply cross-tenant policy: $ErrorMsg")
            }
        }

        # Apply Authorization Policy settings (guest invite, guest role)
        $AuthPatch = @{}
        if ($null -ne $Settings.allowInvitesFrom) { $AuthPatch['allowInvitesFrom'] = $Settings.allowInvitesFrom }
        if ($null -ne $Settings.guestUserRoleId) { $AuthPatch['guestUserRoleId'] = $Settings.guestUserRoleId }
        if ($null -ne $Settings.allowedToSignUpEmailBasedSubscriptions) { $AuthPatch['allowedToSignUpEmailBasedSubscriptions'] = $Settings.allowedToSignUpEmailBasedSubscriptions }
        if ($null -ne $Settings.allowEmailVerifiedUsersToJoinOrganization) { $AuthPatch['allowEmailVerifiedUsersToJoinOrganization'] = $Settings.allowEmailVerifiedUsersToJoinOrganization }
        if ($null -ne $Settings.blockMsnSignIn) { $AuthPatch['blockMsnSignIn'] = $Settings.blockMsnSignIn }

        if ($AuthPatch.Count -gt 0) {
            try {
                $AuthJSON = ConvertTo-Json -Depth 10 -InputObject $AuthPatch -Compress
                $null = New-GraphPostRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -Type PATCH -Body $AuthJSON -ContentType 'application/json'
                $Results.Add('External collaboration settings applied.')
            } catch {
                $ErrorMsg = Get-NormalizedError -Message $_.Exception.Message
                $Results.Add("Failed to apply external collaboration settings: $ErrorMsg")
            }
        }

        # Apply domain restrictions if defined
        if ($null -ne $Settings.domainRestrictions) {
            try {
                $B2BPolicies = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/legacy/policies' -tenantid $TenantFilter -AsApp $true
                $B2BManagement = $B2BPolicies | Where-Object { $_.type -eq 6 }
                if ($B2BManagement) {
                    $ExistingDef = ($B2BManagement.definition | ConvertFrom-Json)
                    $ExistingDef.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy = $Settings.domainRestrictions.InvitationsAllowedAndBlockedDomainsPolicy
                    $UpdateBody = @{ definition = @(($ExistingDef | ConvertTo-Json -Depth 20 -Compress)) }
                    $UpdateJSON = ConvertTo-Json -Depth 20 -InputObject $UpdateBody -Compress
                    $null = New-GraphPostRequest -tenantid $TenantFilter -Uri "https://graph.microsoft.com/beta/legacy/policies/$($B2BManagement.id)" -Type PATCH -Body $UpdateJSON -ContentType 'application/json' -AsApp $true
                    $Results.Add('Domain restrictions applied.')
                }
            } catch {
                $ErrorMsg = Get-NormalizedError -Message $_.Exception.Message
                $Results.Add("Failed to apply domain restrictions: $ErrorMsg")
            }
        }

        $FinalMessage = "Template '$($Template.templateName)' applied to $TenantFilter. " + ($Results -join ' ')
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $FinalMessage -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = $FinalMessage
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to apply cross-tenant template: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to apply cross-tenant template: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
