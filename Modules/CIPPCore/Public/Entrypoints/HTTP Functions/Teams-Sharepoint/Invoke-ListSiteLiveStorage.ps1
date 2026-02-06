function Invoke-ListSiteLiveStorage {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.TenantFilter
    $SiteId = $Request.Query.SiteId

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'TenantFilter is required'
        })
    }
    if (-not $SiteId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'SiteId is required'
        })
    }

    try {
        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
        $ExtraHeaders = @{
            'accept'        = 'application/json'
            'content-type'  = 'application/json'
            'odata-version' = '4.0'
        }

        $SiteInfo = New-GraphGETRequest `
            -scope "$($SharePointInfo.AdminUrl)/.default" `
            -uri "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/sites('$SiteId')" `
            -tenantid $TenantFilter `
            -extraHeaders $ExtraHeaders

        if (-not $SiteInfo) {
            throw 'Could not retrieve site information from SharePoint Admin API'
        }

        # StorageUsage is in MB from the admin API
        $StorageUsedMB = $SiteInfo.StorageUsage
        $StorageQuotaMB = $SiteInfo.StorageMaximumLevel
        $StorageWarningMB = $SiteInfo.StorageWarningLevel

        $StorageUsedGB = [math]::Round($StorageUsedMB / 1024, 2)
        $StorageQuotaGB = [math]::Round($StorageQuotaMB / 1024, 2)
        $StorageWarningGB = [math]::Round($StorageWarningMB / 1024, 2)

        $Percentage = if ($StorageQuotaMB -gt 0) {
            [math]::Round(($StorageUsedMB / $StorageQuotaMB) * 100, 1)
        } else { 0 }

        $SiteName = $SiteInfo.Title
        if (-not $SiteName) { $SiteName = $SiteInfo.Url }

        $ResultMessage = "Live storage for $SiteName`: $StorageUsedGB GB used of $StorageQuotaGB GB allocated ($Percentage%). Warning level: $StorageWarningGB GB. Lock state: $($SiteInfo.LockState). Retrieved at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC."

        $Result = [PSCustomObject]@{
            Results                     = $ResultMessage
            siteId                      = $SiteId
            displayName                 = $SiteName
            storageUsedInMB             = $StorageUsedMB
            storageUsedInGigabytes      = $StorageUsedGB
            storageAllocatedInMB        = $StorageQuotaMB
            storageAllocatedInGigabytes = $StorageQuotaGB
            storageWarningInMB          = $StorageWarningMB
            storageWarningInGigabytes   = $StorageWarningGB
            storagePercentage           = $Percentage
            lastModifiedDateTime        = $SiteInfo.LastContentModifiedDate
            lockState                   = $SiteInfo.LockState
            sharingCapability           = $SiteInfo.SharingCapability
            template                    = $SiteInfo.Template
            url                         = $SiteInfo.Url
            retrievedAt                 = (Get-Date -Format 'o')
        }

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Result
        })
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Forbidden
            Body       = @{ Results = "Failed to get live storage data: $ErrorMessage" }
        })
    }
}
