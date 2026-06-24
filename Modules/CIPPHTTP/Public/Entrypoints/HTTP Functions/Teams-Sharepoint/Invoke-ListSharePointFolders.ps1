function Invoke-ListSharePointFolders {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    .SYNOPSIS
        Lists folders inside a SharePoint document library for the Image Optimizer folder picker.
    .DESCRIPTION
        Accepts a SiteId and optional DriveId (document library). When DriveId is omitted the
        default document library for the site is used. Returns folder items with their id and
        library-relative path so callers can scope a scan to a specific folder.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.TenantFilter ?? $Request.Body.TenantFilter
    $SiteId = $Request.Query.SiteId ?? $Request.Body.SiteId
    $DriveId = $Request.Query.DriveId ?? $Request.Body.DriveId

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = 'TenantFilter is required'
            })
    }
    if (-not $DriveId -and -not $SiteId) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = 'DriveId or SiteId is required'
            })
    }

    try {
        if (-not $DriveId) {
            $Drives = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives?`$select=id,name,driveType" -tenantid $TenantFilter -AsApp $true
            $Drives = @($Drives) | Where-Object { $_.id }
            $Drive = $Drives | Where-Object { $_.driveType -eq 'documentLibrary' } | Select-Object -First 1
            if (-not $Drive) { $Drive = $Drives | Select-Object -First 1 }
            $DriveId = $Drive.id
        }

        if (-not $DriveId) {
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @()
                })
        }

        $Folders = Get-CIPPSharePointFolderList -TenantFilter $TenantFilter -DriveId $DriveId
        $GraphRequest = @($Folders | Sort-Object -Property path)
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to list folders: $ErrorMessage" -Sev Error
        # Reserve 403 for genuine permission/authorization failures; other failures
        # (throttling, transient Graph errors, bad input) should not masquerade as 403.
        $StatusCode = if ($ErrorMessage -match '(?i)forbidden|denied|unauthor|insufficient|privile|consent|permission') {
            [HttpStatusCode]::Forbidden
        } else {
            [HttpStatusCode]::InternalServerError
        }
        $GraphRequest = $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @($GraphRequest)
        })
}
