# Pester tests for the SharePoint Image Optimizer feature.
# Covers audit filtering, threshold, WhatIf safety, savings rules, version cleanup safety,
# throttling retry, permission failure, and empty library handling.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ImgDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/SharePoint/Image Optimizer'

    # Stub the external dependencies so Pester can Mock them.
    function New-GraphGetRequest { param($uri, $tenantid, $AsApp, $NoAuthCheck, $scope) }
    function New-GraphPOSTRequest { param($uri, $tenantid, $type, $AsApp, $NoAuthCheck, $scope, $Body, $ContentType, $AddedHeaders) }
    function Get-GraphToken { param($tenantid, $AsApp) }
    function Get-SharePointAdminLink { param($Public, $TenantFilter) }

    . (Join-Path $ImgDir 'Compress-CIPPImage.ps1')
    . (Join-Path $ImgDir 'Get-CIPPSharePointImageCandidate.ps1')
    . (Join-Path $ImgDir 'Remove-CIPPDriveItemVersion.ps1')
    . (Join-Path $ImgDir 'Invoke-CIPPSharePointImageOptimizer.ps1')

    # Default sizes; individual tests override.
    $script:DownloadSize = 1000000
    $script:CompressedSize = 300000

    function New-RootListing {
        @(
            [PSCustomObject]@{ id = 'big';   name = 'big.jpg';   size = 10485760; file = @{ mimeType = 'image/jpeg' }; folder = $null; parentReference = @{ id = 'root'; path = '/drive/root:' }; webUrl = 'https://c/big.jpg';   lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'small'; name = 'small.jpg'; size = 1048576;  file = @{ mimeType = 'image/jpeg' }; folder = $null; parentReference = @{ id = 'root'; path = '/drive/root:' }; webUrl = 'https://c/small.jpg'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'pic';   name = 'pic.JPEG';  size = 8388608;  file = @{ mimeType = 'image/jpeg' }; folder = $null; parentReference = @{ id = 'root'; path = '/drive/root:' }; webUrl = 'https://c/pic.JPEG';  lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'notes'; name = 'notes.txt'; size = 6291456;  file = @{ mimeType = 'text/plain' }; folder = $null; parentReference = @{ id = 'root'; path = '/drive/root:' }; webUrl = 'https://c/notes.txt'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
            [PSCustomObject]@{ id = 'FOLDER1'; name = 'Sub'; size = 0; file = $null; folder = @{ childCount = 1 }; parentReference = @{ id = 'root'; path = '/drive/root:' }; webUrl = 'https://c/Sub'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
        )
    }
    function New-SubListing {
        @(
            [PSCustomObject]@{ id = 'nested'; name = 'nested.jpg'; size = 9437184; file = @{ mimeType = 'image/jpeg' }; folder = $null; parentReference = @{ id = 'FOLDER1'; path = '/drive/root:/Sub' }; webUrl = 'https://c/Sub/nested.jpg'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; createdDateTime = '2024-01-01T00:00:00Z' }
        )
    }
}

Describe 'Get-CIPPSharePointImageCandidate' {
    BeforeEach {
        Mock New-GraphGetRequest { @() }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'items/root/children' } -MockWith { New-RootListing }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'items/FOLDER1/children' } -MockWith { New-SubListing }
    }

    It 'returns only .jpg and .jpeg files' {
        $r = Get-CIPPSharePointImageCandidate -TenantFilter 't' -DriveId 'D' -MinimumFileSizeMB 5
        $r.Candidates.FileName | Should -Not -Contain 'notes.txt'
        ($r.Candidates | Where-Object { $_.Extension -notin @('jpg', 'jpeg') }) | Should -BeNullOrEmpty
    }

    It 'is case-insensitive on the extension' {
        $r = Get-CIPPSharePointImageCandidate -TenantFilter 't' -DriveId 'D' -MinimumFileSizeMB 5
        ($r.Candidates | Where-Object { $_.FileName -eq 'pic.JPEG' }) | Should -Not -BeNullOrEmpty
    }

    It 'marks files below the threshold as not eligible' {
        $r = Get-CIPPSharePointImageCandidate -TenantFilter 't' -DriveId 'D' -MinimumFileSizeMB 5
        $small = $r.Candidates | Where-Object { $_.FileName -eq 'small.jpg' }
        $small.Eligible | Should -BeFalse
        $small.SkipReason | Should -Be 'Skipped: below threshold'
    }

    It 'recurses subfolders and counts scanned files' {
        $r = Get-CIPPSharePointImageCandidate -TenantFilter 't' -DriveId 'D' -MinimumFileSizeMB 5
        ($r.Candidates | Where-Object { $_.FileName -eq 'nested.jpg' }) | Should -Not -BeNullOrEmpty
        $r.FilesScanned | Should -Be 5
        @($r.Candidates | Where-Object { $_.Eligible }).Count | Should -Be 3
    }

    It 'does not recurse when IncludeSubfolders is false' {
        $r = Get-CIPPSharePointImageCandidate -TenantFilter 't' -DriveId 'D' -MinimumFileSizeMB 5 -IncludeSubfolders $false
        ($r.Candidates | Where-Object { $_.FileName -eq 'nested.jpg' }) | Should -BeNullOrEmpty
    }
}

Describe 'Compress-CIPPImage' {
    It 'returns failure for empty input' {
        $r = Compress-CIPPImage -ImageBytes ([byte[]]::new(0)) -Quality 82
        $r.Success | Should -BeFalse
        $r.Error | Should -Be 'No image data supplied.'
    }

    It 'warns when metadata preservation is requested' {
        $r = Compress-CIPPImage -ImageBytes ([byte[]]::new(0)) -Quality 82 -StripMetadata $false
        $r.Warning | Should -Match 'preservation is not supported'
    }
}

Describe 'Invoke-CIPPImageHttpWithRetry' {
    It 'retries on throttling then succeeds' {
        Mock Start-Sleep {}
        $script:calls = 0
        $result = Invoke-CIPPImageHttpWithRetry -ScriptBlock {
            $script:calls++
            if ($script:calls -lt 2) { throw 'Too many requests' }
            'ok'
        }
        $result | Should -Be 'ok'
        $script:calls | Should -Be 2
    }

    It 'does not retry non-throttling errors' {
        Mock Start-Sleep {}
        $script:calls = 0
        { Invoke-CIPPImageHttpWithRetry -ScriptBlock { $script:calls++; throw 'Access denied' } } | Should -Throw
        $script:calls | Should -Be 1
    }
}

Describe 'Remove-CIPPDriveItemVersion' {
    BeforeEach {
        Mock New-GraphGetRequest { @() }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match '/versions' } -MockWith {
            @(
                [PSCustomObject]@{ id = '3.0'; lastModifiedDateTime = '2024-03-01T00:00:00Z'; size = 100 }
                [PSCustomObject]@{ id = '2.0'; lastModifiedDateTime = '2024-02-01T00:00:00Z'; size = 100 }
                [PSCustomObject]@{ id = '1.0'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; size = 100 }
            )
        }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'sharepointIds' } -MockWith {
            [PSCustomObject]@{ id = 'f'; name = 'f.jpg'; webUrl = 'https://c/f.jpg'; sharepointIds = @{ siteUrl = 'https://c/sites/m'; listItemUniqueId = '11111111-1111-1111-1111-111111111111' } }
        }
        Mock Get-SharePointAdminLink { [PSCustomObject]@{ SharePointUrl = 'https://c'; AdminUrl = 'https://c-admin'; TenantName = 'c' } }
        Mock New-GraphPOSTRequest { $null }
    }

    It 'is a no-op when CleanupMode is none' {
        $r = Remove-CIPPDriveItemVersion -TenantFilter 't' -DriveId 'D' -DriveItemId 'f' -CleanupMode 'none' -WhatIf $false
        $r.VersionsDeleted | Should -Be 0
        Should -Invoke New-GraphPOSTRequest -Times 0
    }

    It 'deletes all old versions but keeps the current (count - 1)' {
        $r = Remove-CIPPDriveItemVersion -TenantFilter 't' -DriveId 'D' -DriveItemId 'f' -CleanupMode 'recycle' -WhatIf $false
        $r.VersionCountBefore | Should -Be 3
        $r.VersionsDeleted | Should -Be 2
        Should -Invoke New-GraphPOSTRequest -Times 1 -ParameterFilter { $uri -match 'recycleAll' }
    }

    It 'uses deleteAll for permanent mode' {
        $r = Remove-CIPPDriveItemVersion -TenantFilter 't' -DriveId 'D' -DriveItemId 'f' -CleanupMode 'permanent' -WhatIf $false
        Should -Invoke New-GraphPOSTRequest -Times 1 -ParameterFilter { $uri -match 'deleteAll' }
        $r.VersionsDeleted | Should -Be 2
    }

    It 'does not call SharePoint REST during WhatIf' {
        $r = Remove-CIPPDriveItemVersion -TenantFilter 't' -DriveId 'D' -DriveItemId 'f' -CleanupMode 'recycle' -WhatIf $true
        Should -Invoke New-GraphPOSTRequest -Times 0
        $r.VersionsDeleted | Should -Be 2
    }

    It 'does nothing when only the current version exists' {
        Mock New-GraphGetRequest -ParameterFilter { $uri -match '/versions' } -MockWith {
            @([PSCustomObject]@{ id = '1.0'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; size = 100 })
        }
        $r = Remove-CIPPDriveItemVersion -TenantFilter 't' -DriveId 'D' -DriveItemId 'f' -CleanupMode 'permanent' -WhatIf $false
        $r.VersionsDeleted | Should -Be 0
        Should -Invoke New-GraphPOSTRequest -Times 0
    }
}

Describe 'Invoke-CIPPSharePointImageOptimizer' {
    BeforeEach {
        $script:DownloadSize = 1000000
        $script:CompressedSize = 300000

        Mock New-GraphGetRequest { @() }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'items/root/children' } -MockWith { New-RootListing }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'items/FOLDER1/children' } -MockWith { New-SubListing }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'downloadUrl' } -MockWith {
            [PSCustomObject]@{ id = 'x'; name = 'x.jpg'; '@microsoft.graph.downloadUrl' = 'https://dl/x' }
        }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match '/versions' } -MockWith {
            @(
                [PSCustomObject]@{ id = '3.0'; lastModifiedDateTime = '2024-03-01T00:00:00Z'; size = 100 }
                [PSCustomObject]@{ id = '2.0'; lastModifiedDateTime = '2024-02-01T00:00:00Z'; size = 100 }
                [PSCustomObject]@{ id = '1.0'; lastModifiedDateTime = '2024-01-01T00:00:00Z'; size = 100 }
            )
        }
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'sharepointIds' } -MockWith {
            [PSCustomObject]@{ id = 'f'; sharepointIds = @{ siteUrl = 'https://c/sites/m'; listItemUniqueId = '11111111-1111-1111-1111-111111111111' } }
        }
        Mock Get-GraphToken { @{ access_token = 'token' } }
        Mock Get-SharePointAdminLink { [PSCustomObject]@{ SharePointUrl = 'https://c' } }
        Mock New-GraphPOSTRequest { $null }
        Mock Start-Sleep {}
        Mock Invoke-WebRequest { [System.IO.File]::WriteAllBytes($OutFile, [byte[]]::new($script:DownloadSize)) }
        Mock Invoke-RestMethod { $null }
        Mock Compress-CIPPImage {
            [PSCustomObject]@{ Success = $true; Engine = 'Test'; OriginalBytes = $ImageBytes.Length; CompressedBytes = $script:CompressedSize; Data = [byte[]]::new($script:CompressedSize); Warning = $null; Error = $null }
        }
    }

    It 'audit mode returns only jpgs and never compresses' {
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Audit' -MinimumFileSizeMB 5
        $r.Summary.FilesScanned | Should -Be 5
        $r.Summary.EligibleFiles | Should -Be 3
        @($r.Results).Count | Should -Be 4
        Should -Invoke Compress-CIPPImage -Times 0
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'PUT' }
    }

    It 'WhatIf compress does not upload or delete versions' {
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'CompressAndCleanup' -MinimumFileSizeMB 5 -WhatIf $true -VersionCleanupMode 'recycle'
        $r.Summary.FilesCompressed | Should -Be 3
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'PUT' }
        Should -Invoke New-GraphPOSTRequest -Times 0
        ($r.Results | Where-Object { $_.Status -eq 'Compressed' }).Count | Should -Be 3
    }

    It 'skips files when the compressed result is larger than the original' {
        $script:CompressedSize = 1200000
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Compress' -MinimumFileSizeMB 5 -WhatIf $false
        $r.Summary.FilesCompressed | Should -Be 0
        ($r.Results | Where-Object { $_.Status -eq 'Skipped: compression savings too small' }).Count | Should -Be 3
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'PUT' }
    }

    It 'respects the minimum savings percent' {
        $script:CompressedSize = 950000 # only 5% savings, below default 15%
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Compress' -MinimumFileSizeMB 5 -MinimumSavingsPercent 15 -WhatIf $false
        $r.Summary.FilesCompressed | Should -Be 0
        ($r.Results | Where-Object { $_.Status -eq 'Skipped: compression savings too small' }).Count | Should -Be 3
    }

    It 'uploads compressed files on a live Compress run without touching versions' {
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Compress' -MinimumFileSizeMB 5 -WhatIf $false
        $r.Summary.FilesCompressed | Should -Be 3
        Should -Invoke Invoke-RestMethod -Times 3 -ParameterFilter { $Method -eq 'PUT' }
        Should -Invoke New-GraphPOSTRequest -Times 0
        ($r.Results | Where-Object { $_.Status -eq 'Compressed' }).Count | Should -Be 3
    }

    It 'compresses and cleans versions on a live CompressAndCleanup run' {
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'CompressAndCleanup' -MinimumFileSizeMB 5 -WhatIf $false -VersionCleanupMode 'recycle'
        $r.Summary.FilesCompressed | Should -Be 3
        $r.Summary.VersionsDeleted | Should -Be 6
        Should -Invoke New-GraphPOSTRequest -Times 3 -ParameterFilter { $uri -match 'recycleAll' }
        ($r.Results | Where-Object { $_.Status -eq 'Compressed and versions cleaned' }).Count | Should -Be 3
    }

    It 'returns a clear per-file error when upload is denied' {
        Mock Invoke-RestMethod { throw 'Access denied (403)' }
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Compress' -MinimumFileSizeMB 5 -WhatIf $false
        $r.Summary.FilesCompressed | Should -Be 0
        $r.Summary.Errors | Should -Be 3
        ($r.Results | Where-Object { $_.Status -eq 'Failed' -and $_.Error -match 'Upload failed' }).Count | Should -Be 3
    }

    It 'returns a successful empty result for an empty library' {
        Mock New-GraphGetRequest -ParameterFilter { $uri -match 'items/root/children' } -MockWith { @() }
        $r = Invoke-CIPPSharePointImageOptimizer -TenantFilter 't' -SiteId 'S' -DriveId 'D' -Mode 'Compress' -MinimumFileSizeMB 5 -WhatIf $false
        $r.Summary.FilesScanned | Should -Be 0
        $r.Summary.EligibleFiles | Should -Be 0
        @($r.Results).Count | Should -Be 0
    }
}
