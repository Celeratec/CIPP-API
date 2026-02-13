function Invoke-CIPPStandardCrossTenantTrustCompliant {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) CrossTenantTrustCompliant
    .SYNOPSIS
        (Label) Sets the Cross-tenant access setting to trust compliant devices
    .DESCRIPTION
        (Helptext) Sets the state of the Cross-tenant access setting to trust compliant devices from external organizations. This allows guest users to satisfy your device compliance Conditional Access policies using their home tenant's Intune compliance status.
        (DocsDescription) Sets the state of the Cross-tenant access setting to trust compliant devices from external organizations. When enabled, your Conditional Access policies that require compliant devices will accept device compliance claims from partner organizations managed through Intune.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Enables trusting device compliance status from partner organizations, allowing external collaborators with Intune-managed compliant devices to access company resources without additional device enrollment. This streamlines cross-organization collaboration while maintaining device security requirements.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Trust compliant devices from external tenants","name":"standards.CrossTenantTrustCompliant.state","options":[{"label":"Enabled","value":"true"},{"label":"Disabled","value":"false"}]}
        IMPACT
            Low Impact
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
        $CurrentPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default?$select=inboundTrust' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get CrossTenantTrustCompliant state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $state = $Settings.state.value ?? $Settings.state
    $WantedState = if ($state -eq 'true') { $true } else { $false }
    $StateMessage = if ($WantedState) { 'enabled' } else { 'disabled' }

    if (([string]::IsNullOrWhiteSpace($state) -or $state -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'CrossTenantTrustCompliant: Invalid state parameter set' -sev Error
        return
    }

    if ($Settings.remediate -eq $true) {
        if ($CurrentPolicy.inboundTrust.isCompliantDeviceAccepted -eq $WantedState) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant compliant device trust is already $StateMessage." -sev Info
        } else {
            try {
                $NewBody = $CurrentPolicy
                $NewBody.inboundTrust.isCompliantDeviceAccepted = $WantedState
                $NewBody = ConvertTo-Json -Depth 10 -InputObject $NewBody -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -Type PATCH -Body $NewBody -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set cross-tenant compliant device trust to $StateMessage." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set cross-tenant compliant device trust to $StateMessage. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($CurrentPolicy.inboundTrust.isCompliantDeviceAccepted -eq $WantedState) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant compliant device trust is $StateMessage." -sev Info
        } else {
            Write-StandardsAlert -message "Cross-tenant compliant device trust is not $StateMessage" -object $CurrentPolicy.inboundTrust -tenant $Tenant -standardName 'CrossTenantTrustCompliant' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant compliant device trust is not $StateMessage." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ isCompliantDeviceAccepted = $CurrentPolicy.inboundTrust.isCompliantDeviceAccepted }
        $ExpectedValue = @{ isCompliantDeviceAccepted = $WantedState }

        Set-CIPPStandardsCompareField -FieldName 'standards.CrossTenantTrustCompliant' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'CrossTenantTrustCompliant' -FieldValue $CurrentPolicy.inboundTrust.isCompliantDeviceAccepted -StoreAs bool -Tenant $Tenant
    }
}
