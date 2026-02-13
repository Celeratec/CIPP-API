function Invoke-CIPPStandardB2BDirectConnectInbound {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) B2BDirectConnectInbound
    .SYNOPSIS
        (Label) Sets the default inbound B2B Direct Connect access policy
    .DESCRIPTION
        (Helptext) Controls whether external users can access your Teams shared channels through B2B Direct Connect by default. Direct Connect enables seamless collaboration without creating guest accounts.
        (DocsDescription) Controls whether external users can access your Teams shared channels through B2B Direct Connect by default. When blocked, no external users can join shared channels unless a partner-specific override is configured. B2B Direct Connect is commonly used for Teams shared channels.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Controls whether external users can seamlessly join Teams shared channels through B2B Direct Connect. Blocking this by default and only allowing specific partner organizations reduces unauthorized access to sensitive team collaboration spaces.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Default inbound B2B Direct Connect access","name":"standards.B2BDirectConnectInbound.accessType","options":[{"label":"Allow (all external users)","value":"allowed"},{"label":"Block (no external users)","value":"blocked"}]}
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
        $CurrentPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default?$select=b2bDirectConnectInbound' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get B2B Direct Connect Inbound state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $WantedAccessType = $Settings.accessType.value ?? $Settings.accessType

    if (([string]::IsNullOrWhiteSpace($WantedAccessType) -or $WantedAccessType -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'B2BDirectConnectInbound: Invalid accessType parameter set' -sev Error
        return
    }

    $CurrentAccessType = $CurrentPolicy.b2bDirectConnectInbound.usersAndGroups.accessType
    $StateIsCorrect = ($CurrentAccessType -eq $WantedAccessType)

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Inbound is already set to $WantedAccessType." -sev Info
        } else {
            try {
                $Body = @{
                    b2bDirectConnectInbound = @{
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
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set B2B Direct Connect Inbound to $WantedAccessType." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set B2B Direct Connect Inbound to $WantedAccessType. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Inbound is set to $WantedAccessType." -sev Info
        } else {
            Write-StandardsAlert -message "B2B Direct Connect Inbound is not set to $WantedAccessType (currently: $CurrentAccessType)" -object $CurrentPolicy.b2bDirectConnectInbound -tenant $Tenant -standardName 'B2BDirectConnectInbound' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Direct Connect Inbound is not set to $WantedAccessType." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ accessType = $CurrentAccessType }
        $ExpectedValue = @{ accessType = $WantedAccessType }

        Set-CIPPStandardsCompareField -FieldName 'standards.B2BDirectConnectInbound' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'B2BDirectConnectInbound' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
