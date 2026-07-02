# Pester tests for Invoke-GetMailQuarantineMessage response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-GetMailQuarantineMessage.ps1'
    $ToolsDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools'

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
    }

    Add-Type -AssemblyName System.Net.Primitives
    Add-Type -AssemblyName System.Net.Http
    $typeAccelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $typeAccelerators::Get.Keys.Contains('HttpStatusCode')) {
        $typeAccelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Get-NormalizedError { param($Message) $Message }
    function ConvertTo-AuthenticationSummary { param($DetailEntries) @{ SPF = @{ result = 'Pass' } } }
    function New-ExoRequest { param($TenantId, $Cmdlet, $CmdParams) $null }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $FunctionPath
}

Describe 'Invoke-GetMailQuarantineMessage' {
    BeforeEach {
        Mock -CommandName Invoke-CippQuarantineExoRequest -MockWith {
            param($TenantId, $Cmdlet, $CmdParams)
            [pscustomobject]@{
                Identity         = $CmdParams.Identity
                MessageId        = '<id@contoso.com>'
                ReceivedTime     = [datetime]'2026-06-01T10:00:00Z'
                Subject          = 'Test subject'
                SenderAddress    = 'sender@example.com'
                RecipientAddress = 'user@contoso.com'
                Type             = 'Spam'
                ReleaseStatus    = 'NotReleased'
                PolicyName       = 'Default'
                PolicyType       = 'HostedContentFilterPolicy'
            }
        }
    }

    It 'returns a structured Results object for detail panels' {
        $request = [pscustomobject]@{
            Query = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                Identity     = 'q-identity-1'
            }
        }

        $response = Invoke-GetMailQuarantineMessage -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -BeOfType [pscustomobject]
        $response.Body.Results.Identity | Should -Be 'q-identity-1'
        $response.Body.Results.ReleaseStatus | Should -Be 'NOTRELEASED'
    }

    It 'returns BadRequest when Identity is missing' {
        $request = [pscustomobject]@{
            Query = @{
                tenantFilter = 'contoso.onmicrosoft.com'
            }
        }

        $response = Invoke-GetMailQuarantineMessage -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        $response.Body.Results | Should -Match 'Identity is required'
    }
}
