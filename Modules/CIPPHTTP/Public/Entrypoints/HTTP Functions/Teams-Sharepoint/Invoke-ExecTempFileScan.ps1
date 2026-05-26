function Invoke-ExecTempFileScan {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $Scope = $Request.Body.scope
    $SiteId = $Request.Body.siteId
    $UserId = $Request.Body.userId
    $Filters = $Request.Body.filters
    if (-not $Filters) {
        $Filters = [PSCustomObject]@{
            officeTemp    = $true
            tempFiles     = $true
            zeroByteFiles = $true
            systemJunk    = $true
            backupFiles   = $false
        }
    }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    if (-not $Scope) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Scope is required (site, user, allSites, or allOneDrives)' }
        })
    }

    if ($Scope -eq 'site' -and -not $SiteId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'SiteId is required when scope is site' }
        })
    }

    if ($Scope -eq 'user' -and -not $UserId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'UserId is required when scope is user' }
        })
    }

    if ($Scope -notin @('site', 'user', 'allSites', 'allOneDrives')) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = "Invalid scope: $Scope. Must be one of: site, user, allSites, allOneDrives" }
        })
    }

    try {
        $ScopeLabel = switch ($Scope) {
            'site' { 'Single Site' }
            'user' { 'OneDrive User' }
            'allSites' { 'All SharePoint Sites' }
            'allOneDrives' { 'All OneDrives' }
        }
        $QueueReference = "TempFileScan-$TenantFilter-$Scope-$SiteId-$UserId"
        $Queue = New-CippQueueEntry -Name "Temp File Scan - $ScopeLabel" -Link '/teams-share/sharepoint/temp-file-cleanup' -Reference $QueueReference -TotalTasks 1

        $FilterParams = @{
            officeTemp    = [bool]$Filters.officeTemp
            tempFiles     = [bool]$Filters.tempFiles
            zeroByteFiles = [bool]$Filters.zeroByteFiles
            systemJunk    = [bool]$Filters.systemJunk
            backupFiles   = [bool]$Filters.backupFiles
        }

        $Queued = Add-CippQueueMessage -Cmdlet 'Start-TempFileScan' -Parameters @{
            QueueId      = $Queue.RowKey
            TenantFilter = $TenantFilter
            Scope        = $Scope
            SiteId         = $SiteId
            UserId         = $UserId
            Filters        = $FilterParams
        }

        if (-not $Queued) {
            throw 'Failed to queue temp file scan'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Queued temp file scan (scope=$Scope, queueId=$($Queue.RowKey))" -Sev Info

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Queued       = $true
            QueueId      = $Queue.RowKey
            QueueMessage = 'Scan queued. Results will be available when the job completes.'
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Temp file scan queue failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to start temp file scan: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
