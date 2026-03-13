function Set-CIPPDBCacheSharePointSiteUsage {
    <#
    .SYNOPSIS
        Caches SharePoint site usage, tenant quota, and settings for the SharePoint dashboard

    .PARAMETER TenantFilter
        The tenant to cache SharePoint data for

    .PARAMETER QueueId
        The queue ID to update with total tasks (optional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,
        [string]$QueueId
    )

    #region Site Usage
    try {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Caching SharePoint site usage' -sev Debug

        $BulkRequests = @(
            @{
                id     = 'listAllSites'
                method = 'GET'
                url    = "sites/getAllSites?`$filter=isPersonalSite eq false&`$select=id,createdDateTime,description,name,displayName,isPersonalSite,lastModifiedDateTime,webUrl,siteCollection,sharepointIds&`$top=999"
            }
            @{
                id     = 'usage'
                method = 'GET'
                url    = "reports/getSharePointSiteUsageDetail(period='D7')?`$format=application/json&`$top=999"
            }
        )

        $Result = New-GraphBulkRequest -tenantid $TenantFilter -Requests @($BulkRequests) -asapp $true
        $Sites = ($Result | Where-Object { $_.id -eq 'listAllSites' }).body.value
        $UsageBase64 = ($Result | Where-Object { $_.id -eq 'usage' }).body
        $UsageJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($UsageBase64))
        $Usage = ($UsageJson | ConvertFrom-Json).value

        $SiteUsageData = foreach ($Site in $Sites) {
            $SiteUsage = $Usage | Where-Object { $_.siteId -eq $Site.sharepointIds.siteId }
            [PSCustomObject]@{
                id                          = $Site.sharepointIds.siteId
                siteId                      = $Site.sharepointIds.siteId
                createdDateTime             = $Site.createdDateTime
                displayName                 = $Site.displayName
                webUrl                      = $Site.webUrl
                ownerDisplayName            = $SiteUsage.ownerDisplayName
                ownerPrincipalName          = $SiteUsage.ownerPrincipalName
                lastActivityDate            = $SiteUsage.lastActivityDate
                fileCount                   = $SiteUsage.fileCount
                storageUsedInBytes          = $SiteUsage.storageUsedInBytes
                storageAllocatedInBytes     = $SiteUsage.storageAllocatedInBytes
                storageUsedInGigabytes      = [math]::round(($SiteUsage.storageUsedInBytes ?? 0) / 1GB, 2)
                storageAllocatedInGigabytes = [math]::round(($SiteUsage.storageAllocatedInBytes ?? 0) / 1GB, 2)
                rootWebTemplate             = $SiteUsage.rootWebTemplate
                reportRefreshDate           = $SiteUsage.reportRefreshDate
            }
        }

        Add-CIPPDbItem -TenantFilter $TenantFilter -Type 'SharePointSiteUsage' -Data $SiteUsageData
        Add-CIPPDbItem -TenantFilter $TenantFilter -Type 'SharePointSiteUsage' -Data $SiteUsageData -Count
        $SiteUsageData = $null
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Cached SharePoint site usage successfully' -sev Debug
    } catch {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache SharePoint site usage: $($_.Exception.Message)" -sev Error
    }
    #endregion Site Usage

    #region Tenant Quota
    try {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Caching SharePoint quota' -sev Debug

        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
        $extraHeaders = @{ 'Accept' = 'application/json' }
        $SharePointQuota = (New-GraphGetRequest -extraHeaders $extraHeaders -scope "$($SharePointInfo.AdminUrl)/.default" -tenantid $TenantFilter -uri "$($SharePointInfo.AdminUrl)/_api/StorageQuotas()?api-version=1.3.2") |
            Sort-Object -Property GeoUsedStorageMB -Descending | Select-Object -First 1

        $UsedStoragePercentage = 0
        if ($SharePointQuota -and $SharePointQuota.TenantStorageMB -gt 0) {
            $UsedStoragePercentage = [int](($SharePointQuota.GeoUsedStorageMB / $SharePointQuota.TenantStorageMB) * 100)
        }

        $QuotaData = @([PSCustomObject]@{
                id               = 'TenantQuota'
                GeoUsedStorageMB = $SharePointQuota.GeoUsedStorageMB
                TenantStorageMB  = $SharePointQuota.TenantStorageMB
                Percentage       = $UsedStoragePercentage
        })

        Add-CIPPDbItem -TenantFilter $TenantFilter -Type 'SharePointQuota' -Data $QuotaData
        $QuotaData = $null
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Cached SharePoint quota successfully' -sev Debug
    } catch {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache SharePoint quota: $($_.Exception.Message)" -sev Error
    }
    #endregion Tenant Quota

    #region Tenant Settings
    try {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Caching SharePoint settings' -sev Debug

        $Settings = New-GraphGetRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true
        $Settings | Add-Member -NotePropertyName 'id' -NotePropertyValue 'TenantSettings' -Force

        Add-CIPPDbItem -TenantFilter $TenantFilter -Type 'SharePointSettings' -Data @($Settings)
        $Settings = $null
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Cached SharePoint settings successfully' -sev Debug
    } catch {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache SharePoint settings: $($_.Exception.Message)" -sev Error
    }
    #endregion Tenant Settings
}
