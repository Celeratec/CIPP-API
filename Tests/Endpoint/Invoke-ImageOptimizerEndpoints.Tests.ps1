# Pester tests for the SharePoint Image Optimizer HTTP entrypoints:
#   - Invoke-ExecSharePointImageOptimize   (queues a background job)
#   - Invoke-ListImageOptimizerResults      (polls queue + cached result)
# Focus: request validation, queueing contract, and the poll state machine
# (Running -> Completed/error) including cached-error and not-found handling.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $EntryDir = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint'

    # The Functions worker supplies [HttpResponseContext] and `using namespace System.Net`.
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

    function New-CippQueueEntry { param($Name, $Link, $Reference, $TotalTasks) }
    function Add-CippQueueMessage { param($Cmdlet, $Parameters) }
    function Get-CIPPQueueData { param($QueueId) }
    function Get-CippTable { param($tablename) }
    function Get-CIPPAzDataTableEntity { param($Filter) }
    function ConvertTo-CIPPODataFilterValue { param($Value, $Type) $Value }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [PSCustomObject]@{ NormalizedError = $Exception.Exception.Message } }

    . (Join-Path $EntryDir 'Invoke-ExecSharePointImageOptimize.ps1')
    . (Join-Path $EntryDir 'Invoke-ListImageOptimizerResults.ps1')

    function New-Request {
        param($Body = $null, $Query = $null)
        [PSCustomObject]@{
            Body    = $Body    ?? ([PSCustomObject]@{})
            Query   = $Query   ?? ([PSCustomObject]@{})
            Params  = [PSCustomObject]@{ CIPPEndpoint = 'ImageOptimizer' }
            Headers = @{}
        }
    }
}

Describe 'Invoke-ExecSharePointImageOptimize' {
    BeforeEach {
        Mock New-CippQueueEntry { [PSCustomObject]@{ RowKey = 'queue-123' } }
        Mock Add-CippQueueMessage { $true }
        Mock Write-LogMessage {}
        Mock Get-CippException { [PSCustomObject]@{ NormalizedError = $Exception.Exception.Message } }
    }

    It 'requires a tenant filter' {
        $resp = Invoke-ExecSharePointImageOptimize -Request (New-Request ([PSCustomObject]@{ DriveId = 'D' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'requires a target (DriveId, SiteId, or SiteUrl)' {
        $resp = Invoke-ExecSharePointImageOptimize -Request (New-Request ([PSCustomObject]@{ TenantFilter = 't' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'rejects an invalid mode' {
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'Nuke' }
        $resp = Invoke-ExecSharePointImageOptimize -Request (New-Request $body)
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'queues a job and returns the QueueId' {
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'Audit' }
        $resp = Invoke-ExecSharePointImageOptimize -Request (New-Request $body)
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $resp.Body.Queued | Should -BeTrue
        $resp.Body.QueueId | Should -Be 'queue-123'
        Should -Invoke Add-CippQueueMessage -Times 1 -Exactly
    }

    It 'forces VersionCleanupMode to none unless mode is CompressAndCleanup' {
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'Compress'; VersionCleanupMode = 'permanent' }
        Invoke-ExecSharePointImageOptimize -Request (New-Request $body) | Out-Null
        Should -Invoke Add-CippQueueMessage -Times 1 -Exactly -ParameterFilter { $Parameters.VersionCleanupMode -eq 'none' }
    }

    It 'preserves VersionCleanupMode for CompressAndCleanup' {
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'CompressAndCleanup'; VersionCleanupMode = 'recycle' }
        Invoke-ExecSharePointImageOptimize -Request (New-Request $body) | Out-Null
        Should -Invoke Add-CippQueueMessage -Times 1 -Exactly -ParameterFilter { $Parameters.VersionCleanupMode -eq 'recycle' }
    }

    It 'defaults WhatIf to true (fail safe) when omitted' {
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'Compress' }
        Invoke-ExecSharePointImageOptimize -Request (New-Request $body) | Out-Null
        Should -Invoke Add-CippQueueMessage -Times 1 -Exactly -ParameterFilter { $Parameters.WhatIf -eq $true }
    }

    It 'returns 500 when queueing fails' {
        Mock Add-CippQueueMessage { $false }
        $body = [PSCustomObject]@{ TenantFilter = 't'; DriveId = 'D'; Mode = 'Audit' }
        $resp = Invoke-ExecSharePointImageOptimize -Request (New-Request $body)
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::InternalServerError)
    }
}

Describe 'Invoke-ListImageOptimizerResults' {
    BeforeEach {
        Mock Get-CippTable { @{ TableName = 'CacheImageOptimizer' } }
        Mock Write-LogMessage {}
        Mock Get-CippException { [PSCustomObject]@{ NormalizedError = $Exception.Exception.Message } }
        Mock Get-CIPPAzDataTableEntity { $null }
    }

    It 'requires a queueId' {
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{}))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'returns 404 when the queue entry does not exist' {
        Mock Get-CIPPQueueData { $null }
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{ queueId = 'q1' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::NotFound)
    }

    It 'reports Running while the job is still processing' {
        Mock Get-CIPPQueueData { [PSCustomObject]@{ Status = 'Running' } }
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{ queueId = 'q1' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $resp.Body.Status | Should -Be 'Running'
    }

    It 'reports Running when completed but the cache has not been written yet' {
        Mock Get-CIPPQueueData { [PSCustomObject]@{ Status = 'Completed' } }
        Mock Get-CIPPAzDataTableEntity { $null }
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{ queueId = 'q1' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $resp.Body.Status | Should -Be 'Running'
    }

    It 'returns the completed result payload from cache' {
        Mock Get-CIPPQueueData { [PSCustomObject]@{ Status = 'Completed' } }
        $payload = @{
            Mode    = 'Audit'
            WhatIf  = $true
            SiteUrl = 'https://c/sites/m'
            Library = 'Documents'
            Folder  = $null
            Summary = @{ FilesScanned = 5; EligibleFiles = 3 }
            Results = @(@{ FileName = 'a.jpg' }, $null, @{ FileName = 'b.jpg' })
            Warnings = @('w1', $null)
        } | ConvertTo-Json -Depth 10
        Mock Get-CIPPAzDataTableEntity { [PSCustomObject]@{ Data = $payload } }
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{ queueId = 'q1'; tenantFilter = 't' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $resp.Body.Status | Should -Be 'Completed'
        $resp.Body.Summary.EligibleFiles | Should -Be 3
        # Null entries must be stripped from the serialized arrays.
        @($resp.Body.Results).Count | Should -Be 2
        @($resp.Body.Warnings).Count | Should -Be 1
    }

    It 'returns 500 when the cached job recorded an error' {
        Mock Get-CIPPQueueData { [PSCustomObject]@{ Status = 'Completed (with errors)' } }
        Mock Get-CIPPAzDataTableEntity { [PSCustomObject]@{ Error = 'boom' } }
        $resp = Invoke-ListImageOptimizerResults -Request (New-Request -Query ([PSCustomObject]@{ queueId = 'q1' }))
        $resp.StatusCode | Should -Be ([System.Net.HttpStatusCode]::InternalServerError)
        $resp.Body.Results | Should -Match 'boom'
    }
}
