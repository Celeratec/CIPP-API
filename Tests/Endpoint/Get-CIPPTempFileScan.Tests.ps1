# Pester tests for the Temp File Cleanup scan engine.
# Focus: delta-based enumeration (large-folder performance), classifier rules, and the
# graceful fallback to recursive scanning when delta fails.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $GraphDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/GraphHelper'

    function New-GraphGetRequest { param($uri, $tenantid, $AsApp, $NoAuthCheck, $scope, $ComplexFilter) }

    . (Join-Path $GraphDir 'Test-CIPPTempFileMatch.ps1')
    . (Join-Path $GraphDir 'Get-CIPPDriveTempFile.ps1')
    . (Join-Path $GraphDir 'Get-TempFilesRecursive.ps1')
    . (Join-Path $GraphDir 'Get-CIPPTempFileScan.ps1')

    $script:AllFilters = [PSCustomObject]@{
        officeTemp    = $true
        tempFiles     = $true
        zeroByteFiles = $true
        systemJunk    = $true
        backupFiles   = $true
    }

    function New-DeltaListing {
        @(
            [PSCustomObject]@{ id = 'root'; name = 'root'; folder = @{ childCount = 3 }; file = $null; parentReference = @{}; size = 0 }
            [PSCustomObject]@{ id = 'folderA'; name = 'Folder A'; folder = @{ childCount = 2 }; file = $null; parentReference = @{ path = '/drives/D/root:' }; size = 0 }
            [PSCustomObject]@{ id = 'office'; name = '~$report.docx'; file = @{ mimeType = 'application/msword' }; folder = $null; parentReference = @{ path = '/drives/D/root:/Folder A' }; size = 1024; webUrl = 'https://c/o'; lastModifiedDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'tmp'; name = 'data.TMP'; file = @{ mimeType = 'application/octet-stream' }; folder = $null; parentReference = @{ path = '/drive/root:' }; size = 2048; webUrl = 'https://c/t'; lastModifiedDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'zero'; name = 'empty.dat'; file = @{ mimeType = 'application/octet-stream' }; folder = $null; parentReference = @{ path = '/drive/root:/Folder A' }; size = 0; webUrl = 'https://c/z'; lastModifiedDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'junk'; name = 'Thumbs.db'; file = @{ mimeType = 'application/octet-stream' }; folder = $null; parentReference = @{ path = '/drive/root:' }; size = 50; webUrl = 'https://c/j'; lastModifiedDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'keep'; name = 'keep.docx'; file = @{ mimeType = 'application/msword' }; folder = $null; parentReference = @{ path = '/drive/root:' }; size = 100; webUrl = 'https://c/k'; lastModifiedDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'gone'; name = 'old.TMP'; file = @{ mimeType = 'application/octet-stream' }; folder = $null; parentReference = @{ path = '/drive/root:' }; size = 10; deleted = @{ state = 'deleted' } }
        )
    }
}

Describe 'Test-CIPPTempFileMatch' {
    It 'detects Office lock/temp files' {
        $m = Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = '~$book.xlsx'; size = 10 }) -Filters $script:AllFilters
        $m | Should -Contain 'officeTemp'
    }
    It 'detects .TMP/.temp files case-insensitively' {
        (Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = 'x.tmp'; size = 1 }) -Filters $script:AllFilters) | Should -Contain 'tempFiles'
        (Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = 'x.TEMP'; size = 1 }) -Filters $script:AllFilters) | Should -Contain 'tempFiles'
    }
    It 'detects zero-byte files' {
        (Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = 'a.bin'; size = 0 }) -Filters $script:AllFilters) | Should -Contain 'zeroByteFiles'
    }
    It 'detects system junk' {
        (Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = '.DS_Store'; size = 5 }) -Filters $script:AllFilters) | Should -Contain 'systemJunk'
    }
    It 'respects disabled filters' {
        $f = [PSCustomObject]@{ officeTemp = $false; tempFiles = $false; zeroByteFiles = $false; systemJunk = $false; backupFiles = $false }
        @(Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = 'x.tmp'; size = 0 }) -Filters $f) | Should -BeNullOrEmpty
    }
    It 'returns empty for a normal file' {
        @(Test-CIPPTempFileMatch -Item ([PSCustomObject]@{ name = 'report.docx'; size = 100 }) -Filters $script:AllFilters) | Should -BeNullOrEmpty
    }
}

Describe 'Get-CIPPDriveTempFile' {
    BeforeEach {
        Mock New-GraphGetRequest { @() }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'root/delta' } -MockWith { New-DeltaListing }
    }

    It 'enumerates the whole drive in a single delta call' {
        $r = @(Get-CIPPDriveTempFile -TenantFilter 't' -DriveId 'D' -Filters $script:AllFilters)
        Should -Invoke New-GraphGetRequest -Times 1 -ParameterFilter { $uri -match 'root/delta' }
    }

    It 'returns only matching files and skips folders, normal files, and deleted items' {
        $r = @(Get-CIPPDriveTempFile -TenantFilter 't' -DriveId 'D' -Filters $script:AllFilters)
        $r.Count | Should -Be 4
        $r.name | Should -Not -Contain 'keep.docx'
        $r.name | Should -Not -Contain 'old.TMP'
        $r.name | Should -Not -Contain 'Folder A'
    }

    It 'reconstructs library-relative paths for both path prefixes' {
        $r = @(Get-CIPPDriveTempFile -TenantFilter 't' -DriveId 'D' -Filters $script:AllFilters)
        ($r | Where-Object { $_.name -eq '~$report.docx' }).path | Should -Be '/Folder A/~$report.docx'
        ($r | Where-Object { $_.name -eq 'data.TMP' }).path | Should -Be '/data.TMP'
    }

    It 'returns nothing when all filters are disabled' {
        $f = [PSCustomObject]@{ officeTemp = $false; tempFiles = $false; zeroByteFiles = $false; systemJunk = $false; backupFiles = $false }
        @(Get-CIPPDriveTempFile -TenantFilter 't' -DriveId 'D' -Filters $f) | Should -BeNullOrEmpty
        Should -Invoke New-GraphGetRequest -Times 0 -ParameterFilter { $uri -match 'root/delta' }
    }
}

Describe 'Get-CIPPTempFileScan' {
    BeforeEach {
        Mock New-GraphGetRequest { @() }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match '/sites/S$' } -MockWith {
            [PSCustomObject]@{ id = 'S'; displayName = 'Marketing'; webUrl = 'https://c/sites/m' }
        }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match '/sites/S/drive$' } -MockWith {
            [PSCustomObject]@{ id = 'D'; webUrl = 'https://c/sites/m/drive' }
        }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'root/delta' } -MockWith { New-DeltaListing }
    }

    It 'scans a site via delta and aggregates results with site metadata' {
        $r = Get-CIPPTempFileScan -TenantFilter 't' -Scope 'site' -SiteId 'S' -Filters $script:AllFilters
        $r.TotalCount | Should -Be 4
        ($r.Results | Select-Object -First 1).SiteName | Should -Be 'Marketing'
        Should -Invoke New-GraphGetRequest -Times 1 -ParameterFilter { $uri -match 'root/delta' }
    }

    It 'falls back to recursive scanning when delta fails' {
        Mock Get-CIPPDriveTempFile { throw 'delta unavailable' }
        Mock Get-TempFilesRecursive { @(@{ id = 'r1'; name = 'fallback.tmp'; size = 5; type = 'tempFiles'; matchTypes = @('tempFiles') }) }
        $r = Get-CIPPTempFileScan -TenantFilter 't' -Scope 'site' -SiteId 'S' -Filters $script:AllFilters
        Should -Invoke Get-TempFilesRecursive -Times 1
        $r.TotalCount | Should -Be 1
        ($r.Results | Select-Object -First 1).name | Should -Be 'fallback.tmp'
    }

    It 'continues when both delta and recursive scans fail for a drive' {
        Mock Get-CIPPDriveTempFile { throw 'delta unavailable' }
        Mock Get-TempFilesRecursive { throw 'recursive failed too' }
        $r = Get-CIPPTempFileScan -TenantFilter 't' -Scope 'site' -SiteId 'S' -Filters $script:AllFilters
        $r.TotalCount | Should -Be 0
    }
}
