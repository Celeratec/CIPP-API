# Pester tests for Disable-CIPPUserInboxRules.
# Background worker used by BEC remediator so Exchange work stays off the SWA HTTP path.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Disable-CIPPUserInboxRules.ps1' -File |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Disable-CIPPUserInboxRules.ps1 under Modules/' }

    function New-ExoRequest { param($anchor, $tenantid, $cmdlet, $cmdParams) }
    function Set-CIPPMailboxRule { param($Username, $UserId, $TenantFilter, $RuleId, $RuleName, [switch]$Disable, $APIName, $Headers) }
    function Write-LogMessage { param($headers, $API, $message, $Sev, $tenant, $LogData) }

    . $FunctionPath
}

Describe 'Disable-CIPPUserInboxRules' {
    BeforeEach {
        $script:disabledRules = [System.Collections.Generic.List[string]]::new()
        Mock -CommandName Write-LogMessage -MockWith {}
        Mock -CommandName Set-CIPPMailboxRule -MockWith {
            $script:disabledRules.Add($RuleName)
        }
    }

    It 'returns info when the mailbox has no rules' {
        Mock -CommandName New-ExoRequest -MockWith { @() }

        $results = Disable-CIPPUserInboxRules -Username 'jdoe@contoso.com' -TenantFilter 'contoso.onmicrosoft.com'

        $results.resultText | Should -Match 'No Inbox Rules'
        $results.state | Should -Be 'info'
        Should -Invoke Set-CIPPMailboxRule -Times 0 -Exactly
    }

    It 'disables user rules and skips Junk and OOF system rules' {
        Mock -CommandName New-ExoRequest -MockWith {
            @(
                [pscustomobject]@{ Name = 'Forward to attacker'; Identity = 'rule-1' }
                [pscustomobject]@{ Name = 'Junk E-Mail Rule'; Identity = 'junk' }
                [pscustomobject]@{ Name = 'Microsoft.Exchange.OOF.External'; Identity = 'oof' }
            )
        }

        $results = Disable-CIPPUserInboxRules -Username 'jdoe@contoso.com' -TenantFilter 'contoso.onmicrosoft.com'

        $script:disabledRules | Should -Contain 'Forward to attacker'
        $script:disabledRules | Should -Not -Contain 'Junk E-Mail Rule'
        $script:disabledRules | Should -Not -Contain 'Microsoft.Exchange.OOF.External'
        ($results | Where-Object { $_.state -eq 'success' }).resultText | Should -Match 'Successfully disabled 1 inbox rules'
    }

    It 'treats delegate-rule disable failures as expected skips' {
        Mock -CommandName New-ExoRequest -MockWith {
            @([pscustomobject]@{ Name = 'Delegate Rule -123'; Identity = 'delegate-1' })
        }
        Mock -CommandName Set-CIPPMailboxRule -MockWith { throw 'cannot disable delegate rule' }

        $results = Disable-CIPPUserInboxRules -Username 'jdoe@contoso.com' -TenantFilter 'contoso.onmicrosoft.com'

        ($results | Where-Object { $_.state -eq 'info' }).resultText | Should -Match 'No processable inbox rules'
        Should -Invoke Set-CIPPMailboxRule -Times 1 -Exactly
    }
}
