function Invoke-CIPPStandardAutomaticUserConsent {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) AutomaticUserConsent
    .SYNOPSIS
        (Label) Sets automatic invitation redemption for cross-tenant access
    .DESCRIPTION
        (Helptext) Controls whether users automatically redeem invitations when accessing external organizations or when external users access your resources. When enabled, users don't see a consent prompt for first-time access.
        (DocsDescription) Controls the automatic user consent settings in the cross-tenant access policy defaults. Inbound automatic consent means external users will automatically redeem invitations without a consent prompt. Outbound automatic consent means your users will automatically redeem invitations from other organizations. This is commonly used to streamline B2B collaboration and B2B Direct Connect experiences.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Controls automatic invitation redemption for cross-tenant collaboration. Enabling automatic consent provides a smoother experience for B2B collaborators by removing the manual invitation acceptance step, while disabling it ensures users explicitly agree before accessing external resources.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Inbound automatic redemption","name":"standards.AutomaticUserConsent.inboundAllowed","options":[{"label":"Enabled","value":"true"},{"label":"Disabled","value":"false"}]}
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Outbound automatic redemption","name":"standards.AutomaticUserConsent.outboundAllowed","options":[{"label":"Enabled","value":"true"},{"label":"Disabled","value":"false"}]}
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
        $CurrentPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default?$select=automaticUserConsentSettings' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get AutomaticUserConsent state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    # Parse inbound setting
    $inboundState = $Settings.inboundAllowed.value ?? $Settings.inboundAllowed
    $WantedInbound = if ($inboundState -eq 'true') { $true } else { $false }

    # Parse outbound setting
    $outboundState = $Settings.outboundAllowed.value ?? $Settings.outboundAllowed
    $WantedOutbound = if ($outboundState -eq 'true') { $true } else { $false }

    # Validate at least one setting is provided
    if (([string]::IsNullOrWhiteSpace($inboundState) -and [string]::IsNullOrWhiteSpace($outboundState)) -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'AutomaticUserConsent: No valid parameters set' -sev Error
        return
    }

    $CurrentInbound = $CurrentPolicy.automaticUserConsentSettings.inboundAllowed
    $CurrentOutbound = $CurrentPolicy.automaticUserConsentSettings.outboundAllowed

    $InboundCorrect = [string]::IsNullOrWhiteSpace($inboundState) -or ($CurrentInbound -eq $WantedInbound)
    $OutboundCorrect = [string]::IsNullOrWhiteSpace($outboundState) -or ($CurrentOutbound -eq $WantedOutbound)
    $StateIsCorrect = $InboundCorrect -and $OutboundCorrect

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Automatic user consent settings are already correct.' -sev Info
        } else {
            try {
                $PatchBody = @{
                    automaticUserConsentSettings = @{}
                }
                if (-not [string]::IsNullOrWhiteSpace($inboundState)) {
                    $PatchBody.automaticUserConsentSettings.inboundAllowed = $WantedInbound
                }
                if (-not [string]::IsNullOrWhiteSpace($outboundState)) {
                    $PatchBody.automaticUserConsentSettings.outboundAllowed = $WantedOutbound
                }
                $Body = ConvertTo-Json -Depth 10 -InputObject $PatchBody -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default' -Type PATCH -Body $Body -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Set automatic user consent settings.' -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set automatic user consent settings. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Automatic user consent settings are correct.' -sev Info
        } else {
            $AlertDetails = @{
                currentInbound  = $CurrentInbound
                currentOutbound = $CurrentOutbound
                wantedInbound   = $WantedInbound
                wantedOutbound  = $WantedOutbound
            }
            Write-StandardsAlert -message 'Automatic user consent settings do not match the expected configuration' -object $AlertDetails -tenant $Tenant -standardName 'AutomaticUserConsent' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message 'Automatic user consent settings do not match.' -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{
            inboundAllowed  = $CurrentInbound
            outboundAllowed = $CurrentOutbound
        }
        $ExpectedValue = @{
            inboundAllowed  = $WantedInbound
            outboundAllowed = $WantedOutbound
        }

        Set-CIPPStandardsCompareField -FieldName 'standards.AutomaticUserConsent' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'AutomaticUserConsent' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
