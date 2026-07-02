# Pester tests for Invoke-ExportMailQuarantine response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExportMailQuarantine.ps1'
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

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $FunctionPath
}

Describe 'Invoke-ExportMailQuarantine' {
    BeforeEach {
        Mock -CommandName Invoke-CippQuarantineExoRequest -MockWith {
            @(
                [pscustomobject]@{
                    Identity         = 'q-1'
                    MessageId        = '<id@contoso.com>'
                    ReceivedTime     = [datetime]'2026-06-01T10:00:00Z'
                    Subject          = 'Invoice test'
                    SenderAddress    = 'sender@example.com'
                    RecipientAddress = 'user@contoso.com'
                    Type             = 'Spam'
                    ReleaseStatus    = 'NotReleased'
                    PolicyName       = 'Default'
                    PolicyType       = 'HostedContentFilterPolicy'
                }
            )
        }
    }

    It 'returns CSV export metadata with raw row scan details' {
        $request = [pscustomobject]@{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                days         = 7
                subject      = 'invoice'
                format       = 'csv'
            }
        }

        $response = Invoke-ExportMailQuarantine -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Metadata.format | Should -Be 'csv'
        $response.Body.Metadata.HasPostFilters | Should -Be $true
        $response.Body.Metadata.RawRowsScanned | Should -BeGreaterThan 0
        $response.Body.Results | Should -Match 'Invoice test'
    }

    It 'returns JSON export payload with filtered row count' {
        $request = [pscustomobject]@{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                days         = 7
                format       = 'json'
            }
        }

        $response = Invoke-ExportMailQuarantine -Request $request -TriggerMetadata $null

        $response.Body.Metadata.format | Should -Be 'json'
        $response.Body.Results.Count | Should -Be 1
        $response.Body.Results[0].ReleaseStatus | Should -Be 'NOTRELEASED'
    }
}
