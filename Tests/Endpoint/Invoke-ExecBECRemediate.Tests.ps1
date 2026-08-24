# Pester tests for Invoke-ExecBECRemediate.
# Containment (password, disable, revoke, MFA) stays in the HTTP request so the
# caller gets the new password. Inbox-rule work is queued — New-ExoRequest plus
# per-rule disables regularly exceed the Azure Static Web Apps ~45s proxy limit
# and surface as "Backend call failure".

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Invoke-ExecBECRemediate.ps1' -File |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Invoke-ExecBECRemediate.ps1 under Modules/' }

    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }

    function Set-CIPPResetPassword { param($UserID, $tenantFilter, $APIName, $Headers) }
    function Set-CIPPSignInState { param($userid, $AccountEnabled, $tenantFilter, $APIName, $Headers) }
    function Revoke-CIPPSessions { param($userid, $username, $Headers, $APIName, $tenantFilter) }
    function Remove-CIPPUserMFA { param($UserPrincipalName, $TenantFilter, $Headers) }
    function New-ExoRequest { param($anchor, $tenantid, $cmdlet, $cmdParams) }
    function Set-CIPPMailboxRule { param($Username, $UserId, $TenantFilter, $RuleId, $RuleName, [switch]$Disable, $APIName, $Headers) }
    function Add-CIPPScheduledTask { param($Task, $Hidden, $Headers, [switch]$RunNow) }
    function Write-LogMessage { param($headers, $API, $message, $Sev, $tenant, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = $Exception.Exception.Message } }

    function New-BecRequest {
        [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecBECRemediate' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                userId       = '11111111-1111-1111-1111-111111111111'
                username     = 'jdoe@contoso.com'
            }
        }
    }

    . $FunctionPath
}

Describe 'Invoke-ExecBECRemediate' {
    BeforeEach {
        $script:resetUserId = $null
        $script:disableUserId = $null
        $script:revokeUserId = $null
        $script:mfaUser = $null
        $script:queuedTask = $null
        $script:queuedRunNow = $false
        $script:exoCalled = $false

        Mock -CommandName Set-CIPPResetPassword -MockWith {
            $script:resetUserId = $UserID
            [pscustomobject]@{ resultText = "Successfully reset the password for $UserID"; copyField = 'TempP@ss1'; state = 'success' }
        }
        Mock -CommandName Set-CIPPSignInState -MockWith {
            $script:disableUserId = $userid
            "Successfully set account enabled state to false for $userid"
        }
        Mock -CommandName Revoke-CIPPSessions -MockWith {
            $script:revokeUserId = $userid
            "Successfully revoked sessions for $username"
        }
        Mock -CommandName Remove-CIPPUserMFA -MockWith {
            $script:mfaUser = $UserPrincipalName
            "Successfully removed MFA methods for user $UserPrincipalName"
        }
        Mock -CommandName New-ExoRequest -MockWith {
            $script:exoCalled = $true
            @()
        }
        Mock -CommandName Set-CIPPMailboxRule -MockWith {}
        Mock -CommandName Add-CIPPScheduledTask -MockWith {
            $script:queuedTask = $Task
            $script:queuedRunNow = [bool]$RunNow
            "Task $($Task.Name) scheduled to run now"
        }
        Mock -CommandName Write-LogMessage -MockWith {}
    }

    It 'returns HTTP 200 with containment results and does not call Exchange inline' {
        $response = Invoke-ExecBECRemediate -Request (New-BecRequest) -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $script:exoCalled | Should -BeFalse
        Should -Invoke New-ExoRequest -Times 0 -Exactly
        Should -Invoke Set-CIPPResetPassword -Times 1 -Exactly
        Should -Invoke Set-CIPPSignInState -Times 1 -Exactly
        Should -Invoke Revoke-CIPPSessions -Times 1 -Exactly
        Should -Invoke Remove-CIPPUserMFA -Times 1 -Exactly

        $texts = @($response.Body.Results | ForEach-Object { $_.resultText })
        $texts | Should -Contain 'Successfully reset the password for 11111111-1111-1111-1111-111111111111'
        ($texts -join ' ') | Should -Match 'inbox rules'
    }

    It 'uses the Entra object ID for Graph containment calls' {
        $null = Invoke-ExecBECRemediate -Request (New-BecRequest) -TriggerMetadata $null

        $script:resetUserId | Should -Be '11111111-1111-1111-1111-111111111111'
        $script:disableUserId | Should -Be '11111111-1111-1111-1111-111111111111'
        $script:revokeUserId | Should -Be '11111111-1111-1111-1111-111111111111'
    }

    It 'queues inbox-rule processing as a RunNow scheduled task' {
        $null = Invoke-ExecBECRemediate -Request (New-BecRequest) -TriggerMetadata $null

        $script:queuedRunNow | Should -BeTrue
        $script:queuedTask.Command.value | Should -Be 'Disable-CIPPUserInboxRules'
        $script:queuedTask.Parameters.Username | Should -Be 'jdoe@contoso.com'
        $script:queuedTask.TenantFilter | Should -Be 'contoso.onmicrosoft.com'
        Should -Invoke Add-CIPPScheduledTask -Times 1 -Exactly
    }

    It 'still returns 200 when queuing inbox rules fails' {
        Mock -CommandName Add-CIPPScheduledTask -MockWith { throw 'queue unavailable' }

        $response = Invoke-ExecBECRemediate -Request (New-BecRequest) -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $errorTexts = @($response.Body.Results | Where-Object { $_.state -eq 'error' } | ForEach-Object { $_.resultText })
        ($errorTexts -join ' ') | Should -Match 'inbox rule'
    }
}
