function Invoke-CIPPStandardCrossTenantTrustHybridJoin {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) CrossTenantTrustHybridJoin
    .SYNOPSIS
        (Label) Sets the Cross-tenant access setting to trust hybrid Azure AD joined devices
    .DESCRIPTION
        (Helptext) Sets the state of the Cross-tenant access setting to trust Microsoft Entra hybrid joined devices from external organizations. This allows guest users to satisfy your Conditional Access policies that require hybrid joined devices using their home tenant's device status.
        (DocsDescription) Sets the state of the Cross-tenant access setting to trust Microsoft Entra hybrid joined devices from external organizations. When enabled, your Conditional Access policies that require hybrid Azure AD joined devices will accept claims from partner organizations.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Enables trusting hybrid Azure AD joined device claims from partner organizations, allowing external collaborators with domain-joined devices to access company resources without additional requirements. This supports cross-organization collaboration for enterprises using hybrid identity.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Trust hybrid Azure AD joined devices from external tenants","name":"standards.CrossTenantTrustHybridJoin.state","options":[{"label":"Enabled","value":"true"},{"label":"Disabled","value":"false"}]}
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
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get CrossTenantTrustHybridJoin state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $state = $Settings.state.value ?? $Settings.state
    $WantedState = if ($state -eq 'true') { $true } else { $false }
    $StateMessage = if ($WantedState) { 'enabled' } else { 'disabled' }

    if (([string]::IsNullOrWhiteSpace($state) -or $state -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'CrossTenantTrustHybridJoin: Invalid state parameter set' -sev Error
        return
    }

    if ($Settings.remediate -eq $true) {
        if ($CurrentPolicy.inboundTrust.isHybridAzureADJoinedDeviceAccepted -eq $WantedState) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant hybrid join trust is already $StateMessage." -sev Info
        } else {
            try {
                $NewBody = $CurrentPolicy
                $NewBody.inboundTrust.isHybridAzureADJoinedDeviceAccepted = $WantedState
                $NewBody = ConvertTo-Json -Depth 10 -InputObject $NewBody -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -Type PATCH -Body $NewBody -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set cross-tenant hybrid join trust to $StateMessage." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set cross-tenant hybrid join trust to $StateMessage. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($CurrentPolicy.inboundTrust.isHybridAzureADJoinedDeviceAccepted -eq $WantedState) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant hybrid join trust is $StateMessage." -sev Info
        } else {
            Write-StandardsAlert -message "Cross-tenant hybrid join trust is not $StateMessage" -object $CurrentPolicy.inboundTrust -tenant $Tenant -standardName 'CrossTenantTrustHybridJoin' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Cross-tenant hybrid join trust is not $StateMessage." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ isHybridAzureADJoinedDeviceAccepted = $CurrentPolicy.inboundTrust.isHybridAzureADJoinedDeviceAccepted }
        $ExpectedValue = @{ isHybridAzureADJoinedDeviceAccepted = $WantedState }

        Set-CIPPStandardsCompareField -FieldName 'standards.CrossTenantTrustHybridJoin' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'CrossTenantTrustHybridJoin' -FieldValue $CurrentPolicy.inboundTrust.isHybridAzureADJoinedDeviceAccepted -StoreAs bool -Tenant $Tenant
    }
}
