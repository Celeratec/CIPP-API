function Invoke-CIPPStandardBlockMSNSignIn {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) BlockMSNSignIn
    .SYNOPSIS
        (Label) Block personal Microsoft account (MSN) sign-in
    .DESCRIPTION
        (Helptext) Controls whether personal Microsoft accounts (MSN/Outlook.com/Hotmail) can be used to sign in. Blocking MSN sign-in prevents users from using personal accounts to access organizational resources.
        (DocsDescription) Controls whether personal Microsoft accounts (MSN/Outlook.com/Hotmail) can be used to sign in to the tenant. When enabled, users cannot use personal Microsoft accounts to access organizational resources, improving security by ensuring only managed accounts are used.
    .NOTES
        CAT
            Entra (AAD) Standards
        TAG
        EXECUTIVETEXT
            Prevents users from signing in with personal Microsoft accounts (Outlook.com, Hotmail, etc.), ensuring that only organizational or approved external accounts can access company resources. This reduces shadow IT risks and maintains compliance with identity governance policies.
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"creatable":false,"label":"Block MSN sign-in","name":"standards.BlockMSNSignIn.state","options":[{"label":"Enabled (block personal accounts)","value":"true"},{"label":"Disabled (allow personal accounts)","value":"false"}]}
        IMPACT
            Low Impact
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
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get BlockMSNSignIn state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    $state = $Settings.state.value ?? $Settings.state
    $WantedState = if ($state -eq 'true') { $true } else { $false }
    $StateMessage = if ($WantedState) { 'blocked' } else { 'allowed' }

    if (([string]::IsNullOrWhiteSpace($state) -or $state -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'BlockMSNSignIn: Invalid state parameter set' -sev Error
        return
    }

    $StateIsCorrect = ($CurrentState.blockMsnSignIn -eq $WantedState)

    if ($Settings.remediate -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "MSN sign-in is already $StateMessage." -sev Info
        } else {
            try {
                $Body = @{ blockMsnSignIn = $WantedState } | ConvertTo-Json -Compress
                $null = New-GraphPostRequest -tenantid $Tenant -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -Type PATCH -Body $Body -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Set MSN sign-in to $StateMessage." -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set MSN sign-in to $StateMessage. Error: $ErrorMessage" -sev Error
            }
        }
    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "MSN sign-in is $StateMessage." -sev Info
        } else {
            Write-StandardsAlert -message "MSN sign-in is not $StateMessage" -object @{ blockMsnSignIn = $CurrentState.blockMsnSignIn } -tenant $Tenant -standardName 'BlockMSNSignIn' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "MSN sign-in is not $StateMessage." -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $CurrentValue = @{ blockMsnSignIn = $CurrentState.blockMsnSignIn }
        $ExpectedValue = @{ blockMsnSignIn = $WantedState }

        Set-CIPPStandardsCompareField -FieldName 'standards.BlockMSNSignIn' -CurrentValue $CurrentValue -ExpectedValue $ExpectedValue -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'BlockMSNSignIn' -FieldValue $StateIsCorrect -StoreAs bool -Tenant $Tenant
    }
}
