function Invoke-CIPPStandardB2BCollaborationInbound {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) B2BCollaborationInbound
    .SYNOPSIS
        (Label) Sets the default inbound B2B collaboration access policy
    .DESCRIPTION
        (Helptext) Controls whether external users from other organizations can be invited to access your resources through B2B collaboration (guest access) by default. This applies to all external organizations without a partner-specific configuration.
        (DocsDescription) Controls whether external users from other organizations can be invited to access your resources through B2B collaboration (guest access) by default. When set to blocked, no external users can collaborate unless a partner-specific override is configured.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Manages the default inbound B2B collaboration policy, controlling whether external users from partner organizations can access company resources as guests. Restricting this to specific organizations reduces the attack surface while allowing necessary business collaboration.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Default inbound B2B collaboration access","name":"standards.B2BCollaborationInbound.accessType","options":[{"label":"Allow (all external users)","value":"allowed"},{"label":"Block (no external users)","value":"blocked"}]}
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
        $CurrentPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default?$select=b2bCollaborationInbound' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get B2B Collaboration Inbound state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $WantedAccessType = $Settings.accessType.value ?? $Settings.accessType

    if (([string]::IsNullOrWhiteSpace($WantedAccessType) -or $WantedAccessType -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'B2BCollaborationInbound: Invalid accessType parameter set' -sev Error
        return
    }

    $CurrentAccessType = $CurrentPolicy.b2bCollaborationInbound.usersAndGroups.accessType
    $StateIsCorrect = ($CurrentAccessType -eq $WantedAccessType)

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Collaboration Inbound is already set to $WantedAccessType." -sev Info
        } else {
            try {
                $Body = @{
                    b2bCollaborationInbound = @{
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
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set B2B Collaboration Inbound to $WantedAccessType." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set B2B Collaboration Inbound to $WantedAccessType. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Collaboration Inbound is set to $WantedAccessType." -sev Info
        } else {
            Write-StandardsAlert -message "B2B Collaboration Inbound is not set to $WantedAccessType (currently: $CurrentAccessType)" -object $CurrentPolicy.b2bCollaborationInbound -tenant $Tenant -standardName 'B2BCollaborationInbound' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "B2B Collaboration Inbound is not set to $WantedAccessType." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ accessType = $CurrentAccessType }
        $ExpectedValue = @{ accessType = $WantedAccessType }

        Set-CIPPStandardsCompareField -FieldName 'standards.B2BCollaborationInbound' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'B2BCollaborationInbound' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
