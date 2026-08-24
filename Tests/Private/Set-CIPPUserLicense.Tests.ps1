# Pester tests for Set-CIPPUserLicense.
# assignLicense must use app-only tokens. Delegated tokens need an Entra
# License/User Administrator role; profile edits succeed without it, which is
# why Edit User can succeed while license assignment returns
# "Insufficient privileges to complete the operation."

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Set-CIPPUserLicense.ps1' -File |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Set-CIPPUserLicense.ps1 under Modules/' }

    function Get-CippTable { param($tablename) @{ Name = $tablename } }
    function Get-CIPPAzDataTableEntity { param($Table, $Filter) $null }
    function New-GraphBulkRequest { param($tenantid, $Requests, $asapp) }
    function Write-LogMessage { param($Headers, $API, $tenant, $message, $Sev) }

    . $FunctionPath
}

Describe 'Set-CIPPUserLicense' {
    BeforeEach {
        $script:bulkCalls = [System.Collections.Generic.List[hashtable]]::new()
        Mock -CommandName Get-CippTable -MockWith { @{ Name = 'UserSettings' } }
        Mock -CommandName Get-CIPPAzDataTableEntity -MockWith { $null }
        Mock -CommandName Write-LogMessage -MockWith {}
        Mock -CommandName New-GraphBulkRequest -MockWith {
            $script:bulkCalls.Add(@{
                    tenantid = $tenantid
                    asapp    = $asapp
                    Requests = @($Requests)
                })
            foreach ($Req in @($Requests)) {
                [pscustomobject]@{
                    id     = $Req.id
                    status = 200
                    body   = @{}
                }
            }
        }
    }

    It 'sends assignLicense through Graph as an app-only call' {
        $null = Set-CIPPUserLicense -UserId '11111111-1111-1111-1111-111111111111' -UserPrincipalName 'christina@nicholsonclinic.com' -TenantFilter 'nicholsonclinic.com' -AddLicenses @('sku-1')

        $script:bulkCalls.Count | Should -BeGreaterThan 0
        foreach ($Call in $script:bulkCalls) {
            $Call.asapp | Should -BeTrue
        }
    }

    It 'returns a classified privilege message when Graph denies assignLicense' {
        Mock -CommandName New-GraphBulkRequest -MockWith {
            $script:bulkCalls.Add(@{ asapp = $asapp })
            @(
                [pscustomobject]@{
                    id     = '11111111-1111-1111-1111-111111111111'
                    status = 403
                    body   = [pscustomobject]@{
                        error = [pscustomobject]@{ message = 'Insufficient privileges to complete the operation.' }
                    }
                }
            )
        }

        $Result = Set-CIPPUserLicense -UserId '11111111-1111-1111-1111-111111111111' -UserPrincipalName 'christina@nicholsonclinic.com' -TenantFilter 'nicholsonclinic.com' -AddLicenses @('sku-1')

        $Result | Should -Match 'Insufficient privileges'
        $Result | Should -Match 'License Administrator|department|self-service|app-only'
    }
}
