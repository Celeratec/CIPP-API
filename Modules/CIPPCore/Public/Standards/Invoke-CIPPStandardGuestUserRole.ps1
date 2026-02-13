function Invoke-CIPPStandardGuestUserRole {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) GuestUserRole
    .SYNOPSIS
        (Label) Sets the guest user default access level
    .DESCRIPTION
        (Helptext) Sets the default access level for guest users in the directory. Choose between member-level access, default guest access, or the most restrictive setting that blocks directory enumeration. This is a more flexible alternative to the DisableGuestDirectory standard.
        (DocsDescription) Controls what permissions guest users have in the directory. The most restrictive option prevents guests from enumerating users and group memberships. The default option limits guest access but allows basic directory browsing. The least restrictive option gives guests the same access as member users.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
            "EIDSCA.AP14"
        EXECUTIVETEXT
            Controls the level of directory access granted to external guest users, balancing collaboration needs with security requirements. Setting appropriate guest permissions prevents unauthorized discovery of organizational structure and employee information.
        ADDEDCOMPONENT
            {"type":"autoComplete","required":true,"multiple":false,"creatable":false,"label":"Guest user access level","name":"standards.GuestUserRole.guestUserRoleId","options":[{"label":"Same access as member users (least restrictive)","value":"a0b1b346-4d3e-4e8b-98f8-753987be4970"},{"label":"Limited access - default guest access","value":"10dae51f-b6af-4016-8d66-8c2a99b929b3"},{"label":"Restricted access - cannot enumerate directory (most restrictive)","value":"2af84b1e-32c8-42b7-82bc-daa82404023b"}]}
        IMPACT
            Medium Impact
        ADDEDDATE
            2026-02-13
        POWERSHELLEQUIVALENT
            Update-MgPolicyAuthorizationPolicy
        RECOMMENDEDBY
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/list-standards
    #>

    param($Tenant, $Settings)

    try {
        $CurrentState = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $Tenant
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get GuestUserRole state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $WantedRoleId = $Settings.guestUserRoleId.value ?? $Settings.guestUserRoleId

    if (([string]::IsNullOrWhiteSpace($WantedRoleId) -or $WantedRoleId -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'GuestUserRole: Invalid guestUserRoleId parameter set' -sev Error
        return
    }

    $RoleLabels = @{
        'a0b1b346-4d3e-4e8b-98f8-753987be4970' = 'Same as members'
        '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Limited access (default)'
        '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted access'
    }
    $WantedLabel = $RoleLabels[$WantedRoleId] ?? $WantedRoleId

    $StateIsCorrect = ($CurrentState.guestUserRoleId -eq $WantedRoleId)

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Guest user role is already set to $WantedLabel." -sev Info
        } else {
            try {
                $Body = @{ guestUserRoleId = $WantedRoleId } | ConvertTo-Json -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -Type PATCH -Body $Body -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set guest user role to $WantedLabel." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set guest user role to $WantedLabel. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Guest user role is set to $WantedLabel." -sev Info
        } else {
            $CurrentLabel = $RoleLabels[$CurrentState.guestUserRoleId] ?? $CurrentState.guestUserRoleId
            Write-StandardsAlert -message "Guest user role is not set to $WantedLabel (currently: $CurrentLabel)" -object @{ guestUserRoleId = $CurrentState.guestUserRoleId } -tenant $Tenant -standardName 'GuestUserRole' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "Guest user role is not set to $WantedLabel." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ guestUserRoleId = $CurrentState.guestUserRoleId }
        $ExpectedValue = @{ guestUserRoleId = $WantedRoleId }

        Set-CIPPStandardsCompareField -FieldName 'standards.GuestUserRole' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'GuestUserRole' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
