function Invoke-CIPPStandardB2BDirectConnectOutbound {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) B2BDirectConnectOutbound
    .SYNOPSIS
        (Label) Sets the default outbound B2B Direct Connect access policy
    .DESCRIPTION
        (Helptext) Controls whether your users can access external Teams shared channels through B2B Direct Connect by default. This applies to all external organizations without a partner-specific configuration.
        (DocsDescription) Controls whether your users can access external Teams shared channels through B2B Direct Connect by default. When blocked, users cannot join external shared channels unless a partner-specific override is configured.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Controls whether employees can join external Teams shared channels through B2B Direct Connect. Blocking outbound Direct Connect by default and only allowing specific partners prevents uncontrolled data sharing through external collaboration channels.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Default outbound B2B Direct Connect access","name":"standards.B2BDirectConnectOutbound.accessType","options":[{"label":"Allow (all users)","value":"allowed"},{"label":"Block (no users)","value":"blocked"}]}
        IMPACT
            Medium Impact
        ADDEDDATE
            2026-02-13
        POWERSHELLEQUIVALENT
            Update-MgPolicyCrossTenantAccessPolicyDefault
        RECOMMENDEDBY
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/list-standards
    #>

    param($Tenant, $Settings)

    try {
        $CurrentPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default?$select=b2bDirectConnectOutbound' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get B2B Direct Connect Outbound state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $WantedAccessType = $Settings.accessType.value ?? $Settings.accessType

    if (([string]::IsNullOrWhiteSpace($WantedAccessType) -or $WantedAccessType -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'B2BDirectConnectOutbound: Invalid accessType parameter set' -sev Error
        return
    }

    $CurrentAccessType = $CurrentPolicy.b2bDirectConnectOutbound.usersAndGroups.accessType
    $StateIsCorrect = ($CurrentAccessType -eq $WantedAccessType)

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Outbound is already set to $WantedAccessType." -sev Info
        } else {
            try {
                $Body = @{
                    b2bDirectConnectOutbound = @{
                        usersAndGroups = @{
                            accessType = $WantedAccessType
                            targets    = @(@{ target = 'AllUsers'; targetType = 'user' })
                        }
                        applications   = @{
                            accessType = $WantedAccessType
                            targets    = @(@{ target = 'AllApplications'; targetType = 'application' })
                        }
                    }
                } | ConvertTo-Json -Depth 10 -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -Type PATCH -Body $Body -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set B2B Direct Connect Outbound to $WantedAccessType." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set B2B Direct Connect Outbound to $WantedAccessType. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Outbound is set to $WantedAccessType." -sev Info
        } else {
            Write-StandardsAlert -message "B2B Direct Connect Outbound is not set to $WantedAccessType (currently: $CurrentAccessType)" -object $CurrentPolicy.b2bDirectConnectOutbound -tenant $Tenant -standardName 'B2BDirectConnectOutbound' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Outbound is not set to $WantedAccessType." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ accessType = $CurrentAccessType }
        $ExpectedValue = @{ accessType = $WantedAccessType }

        Set-CIPPStandardsCompareField -FieldName 'standards.B2BDirectConnectOutbound' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'B2BDirectConnectOutbound' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
