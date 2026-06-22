function Invoke-ListSharePointImageCandidates {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    .SYNOPSIS
        Audits a SharePoint document library for large JPG/JPEG files (read-only).
    .DESCRIPTION
        Returns the SharePoint Image Optimizer result object in Audit mode. No files are
        modified and no versions are deleted. Accepts parameters from either the query
        string or the request body so it can be called as a GET (list) or POST.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint

    $TenantFilter = $Request.Body.TenantFilter ?? $Request.Query.TenantFilter
    $SiteId = $Request.Body.SiteId ?? $Request.Query.SiteId
    $SiteUrl = $Request.Body.SiteUrl ?? $Request.Query.SiteUrl
    $DriveId = $Request.Body.DriveId ?? $Request.Query.DriveId
    $LibraryName = $Request.Body.LibraryName ?? $Request.Query.LibraryName
    $MinimumFileSizeMB = $Request.Body.MinimumFileSizeMB ?? $Request.Query.MinimumFileSizeMB ?? 5
    $IncludeSubfoldersRaw = $Request.Body.IncludeSubfolders ?? $Request.Query.IncludeSubfolders
    $IncludeSubfolders = if ($null -eq $IncludeSubfoldersRaw) {
        $true
    } elseif ($IncludeSubfoldersRaw -is [string]) {
        $IncludeSubfoldersRaw -eq 'true'
    } else {
        [bool]$IncludeSubfoldersRaw
    }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }
    if (-not $DriveId -and -not $SiteId -and -not $SiteUrl) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'DriveId, SiteId, or SiteUrl is required' }
        })
    }

    try {
        $Result = Invoke-CIPPSharePointImageOptimizer -TenantFilter $TenantFilter -SiteId $SiteId -SiteUrl $SiteUrl `
            -DriveId $DriveId -LibraryName $LibraryName -Mode 'Audit' `
            -MinimumFileSizeMB ([double]$MinimumFileSizeMB) -IncludeSubfolders ([bool]$IncludeSubfolders)

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Audited SharePoint library for large JPGs. Scanned $($Result.Summary.FilesScanned), eligible $($Result.Summary.EligibleFiles)." -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Image audit failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Image audit failed: $($ErrorMessage.NormalizedError)" }
        })
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Result
    })
}
