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

    try {
        $Results = @()

        $DrivesToScan = switch ($Scope) {
            'site' {
                if (-not $SiteId) {
                    throw 'SiteId is required when scope is site'
                }
                $SiteInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId" -tenantid $TenantFilter -AsApp $true
                $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drive" -tenantid $TenantFilter -AsApp $true
                @(@{ DriveId = $DriveInfo.id; SiteName = $SiteInfo.displayName; SiteUrl = $SiteInfo.webUrl })
            }
            'user' {
                if (-not $UserId) {
                    throw 'UserId is required when scope is user'
                }
                $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserId/drive" -tenantid $TenantFilter -AsApp $true
                $UserInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserId" -tenantid $TenantFilter -AsApp $true
                @(@{ DriveId = $DriveInfo.id; SiteName = "OneDrive - $($UserInfo.displayName)"; SiteUrl = $DriveInfo.webUrl })
            }
            'allSites' {
                $Sites = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites?`$top=999" -tenantid $TenantFilter -AsApp $true
                $Sites | ForEach-Object {
                    try {
                        $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($_.id)/drive" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
                        @{ DriveId = $DriveInfo.id; SiteName = $_.displayName; SiteUrl = $_.webUrl }
                    } catch { $null }
                } | Where-Object { $_ }
            }
            'allOneDrives' {
                $Users = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=assignedLicenses/`$count ne 0&`$count=true" -tenantid $TenantFilter -AsApp $true -ComplexFilter
                $Users | ForEach-Object {
                    try {
                        $Drive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$($_.id)/drive" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
                        @{ DriveId = $Drive.id; SiteName = "OneDrive - $($_.displayName)"; SiteUrl = $Drive.webUrl }
                    } catch { $null }
                } | Where-Object { $_ }
            }
            default {
                throw "Invalid scope: $Scope. Must be one of: site, user, allSites, allOneDrives"
            }
        }

        foreach ($Drive in $DrivesToScan) {
            $DriveFiles = Get-TempFilesRecursive -TenantFilter $TenantFilter -DriveId $Drive.DriveId -Filters $Filters
            $DriveFiles | ForEach-Object {
                $_.SiteName = $Drive.SiteName
                $_.SiteUrl = $Drive.SiteUrl
            }
            $Results += $DriveFiles
        }

        $Body = @{
            Results    = $Results
            TotalCount = $Results.Count
            TotalSize  = ($Results | Measure-Object -Property size -Sum).Sum
        }
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Temp file scan failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to scan for temp files: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
