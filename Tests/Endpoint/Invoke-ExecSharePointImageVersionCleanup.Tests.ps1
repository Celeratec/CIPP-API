# Pester tests for the standalone SharePoint version cleanup HTTP entrypoint.
# Focus: result messaging must never report a deletion that did not happen (dry run) and
# must never report generic success when some/all files failed; inputs are de-duplicated.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $EntryPoint = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ExecSharePointImageVersionCleanup.ps1'

    # The Functions worker supplies [HttpResponseContext] and `using namespace System.Net`
    # (so [HttpStatusCode] resolves). Shim both for unit testing.
    if (-not ('HttpResponseContext' -as [type])) {
        class HttpResponseContext {
            [object]$StatusCode
            [object]$Body
        }
    }
    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Remove-CIPPDriveItemVersion { param($TenantFilter, $DriveId, $DriveItemId, $CleanupMode, $WhatIf) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [PSCustomObject]@{ NormalizedError = $Exception.Exception.Message } }

    . $EntryPoint

    function New-Request {
        param($Body)
        [PSCustomObject]@{
            Body    = $Body
            Query   = [PSCustomObject]@{}
            Params  = [PSCustomObject]@{ CIPPEndpoint = 'ExecSharePointImageVersionCleanup' }
            Headers = @{}
        }
    }

    # A clean (no-error) cleanup result that removed 2 old versions.
    function New-CleanupOk {
        [PSCustomObject]@{
            VersionCountBefore = 3
            VersionsDeleted    = 2
            Warnings           = [System.Collections.Generic.List[string]]::new()
            Errors             = [System.Collections.Generic.List[string]]::new()
        }
    }
    # A failed cleanup result.
    function New-CleanupFail {
        $r = [PSCustomObject]@{
            VersionCountBefore = 3
            VersionsDeleted    = 0
            Warnings           = [System.Collections.Generic.List[string]]::new()
            Errors             = [System.Collections.Generic.List[string]]::new()
        }
        $r.Errors.Add('Access denied')
        $r
    }
}

Describe 'Invoke-ExecSharePointImageVersionCleanup' {
    Context 'validation' {
        It 'requires a tenant filter' {
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request ([PSCustomObject]@{ Files = @('a') }))
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        }
        It 'requires at least one file' {
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request ([PSCustomObject]@{ TenantFilter = 't'; Files = @() }))
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        }
        It 'rejects an invalid cleanup mode' {
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'nuke'; Files = @(@{ id = 'a'; driveId = 'd' }) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        }
    }

    Context 'dry run (WhatIf)' {
        It 'never claims a deletion happened' {
            Mock Remove-CIPPDriveItemVersion { New-CleanupOk }
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'recycle'; WhatIf = $true; Files = @(@{ id = 'a'; driveId = 'd' }) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $resp.Body.Results | Should -Match 'Dry run'
            $resp.Body.Results | Should -Not -Match 'Deleted \d'
            $resp.Body.WhatIf | Should -BeTrue
        }
    }

    Context 'live runs' {
        It 'reports plain success when all files succeed' {
            Mock Remove-CIPPDriveItemVersion { New-CleanupOk }
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'recycle'; WhatIf = $false; Files = @(@{ id = 'a'; driveId = 'd' }, @{ id = 'b'; driveId = 'd' }) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $resp.Body.Errors | Should -Be 0
            $resp.Body.Succeeded | Should -Be 2
            $resp.Body.VersionsDeleted | Should -Be 4
            $resp.Body.Results | Should -Be 'Deleted 4 version(s) across 2 file(s).'
        }

        It 'does NOT report generic success when every file fails (status reflects failure)' {
            Mock Remove-CIPPDriveItemVersion { New-CleanupFail }
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'permanent'; WhatIf = $false; Files = @(@{ id = 'a'; driveId = 'd' }, @{ id = 'b'; driveId = 'd' }) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::InternalServerError)
            $resp.Body.Results | Should -Match 'failed for all'
            $resp.Body.Succeeded | Should -Be 0
            $resp.Body.Errors | Should -Be 2
        }

        It 'reports partial failure clearly' {
            $script:call = 0
            Mock Remove-CIPPDriveItemVersion {
                $script:call++
                if ($script:call -eq 1) { New-CleanupOk } else { New-CleanupFail }
            }
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'recycle'; WhatIf = $false; Files = @(@{ id = 'a'; driveId = 'd' }, @{ id = 'b'; driveId = 'd' }) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $resp.Body.Succeeded | Should -Be 1
            $resp.Body.Errors | Should -Be 1
            $resp.Body.Results | Should -Match 'file\(s\) failed'
        }
    }

    Context 'de-duplication' {
        It 'processes each unique drive item only once' {
            Mock Remove-CIPPDriveItemVersion { New-CleanupOk }
            $body = [PSCustomObject]@{ TenantFilter = 't'; CleanupMode = 'recycle'; WhatIf = $false; Files = @(
                    @{ id = 'a'; driveId = 'd' },
                    @{ id = 'a'; driveId = 'd' },
                    @{ id = 'b'; driveId = 'd' }
                ) }
            $resp = Invoke-ExecSharePointImageVersionCleanup -Request (New-Request $body)
            Should -Invoke Remove-CIPPDriveItemVersion -Times 2 -Exactly
            $resp.Body.ProcessedCount | Should -Be 2
        }
    }
}
