function Get-CIPPTempFileScan {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Scans SharePoint/OneDrive drives for temporary and junk files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [ValidateSet('site', 'user', 'allSites', 'allOneDrives')]
        [string]$Scope,

        [string]$SiteId,
        [string]$UserId,
        $Filters
    )

    if (-not $Filters) {
        $Filters = [PSCustomObject]@{
            officeTemp    = $true
            tempFiles     = $true
            zeroByteFiles = $true
            systemJunk    = $true
            backupFiles   = $false
        }
    }

    $Results = [System.Collections.Generic.List[object]]::new()

    $DrivesToScan = switch ($Scope) {
        'site' {
            $SiteInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId" -tenantid $TenantFilter -AsApp $true
            $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drive" -tenantid $TenantFilter -AsApp $true
            $SiteName = $SiteInfo.displayName ?? $SiteInfo.name
            @(@{ DriveId = $DriveInfo.id; SiteName = $SiteName; SiteUrl = $SiteInfo.webUrl })
        }
        'user' {
            $EncodedUserId = if ($UserId -match '@') { $UserId -replace '#', '%23' } else { $UserId }
            $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUserId/drive" -tenantid $TenantFilter -AsApp $true
            $UserInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUserId" -tenantid $TenantFilter -AsApp $true
            @(@{ DriveId = $DriveInfo.id; SiteName = "OneDrive - $($UserInfo.displayName)"; SiteUrl = $DriveInfo.webUrl })
        }
        'allSites' {
            $Sites = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/getAllSites?`$filter=isPersonalSite eq false&`$select=id,displayName,name,webUrl&`$top=999" -tenantid $TenantFilter -AsApp $true
            $Sites | ForEach-Object {
                try {
                    $DriveInfo = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($_.id)/drive" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
                    $SiteName = $_.displayName ?? $_.name
                    @{ DriveId = $DriveInfo.id; SiteName = $SiteName; SiteUrl = $_.webUrl }
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
    }

    foreach ($Drive in $DrivesToScan) {
        $DriveFiles = Get-TempFilesRecursive -TenantFilter $TenantFilter -DriveId $Drive.DriveId -Filters $Filters
        foreach ($File in $DriveFiles) {
            $File.SiteName = $Drive.SiteName
            $File.SiteUrl = $Drive.SiteUrl
        }
        if ($DriveFiles) {
            $Results.AddRange([object[]]@($DriveFiles))
        }
    }

    $TotalSize = ($Results | Where-Object { $_.size }) | Measure-Object -Property size -Sum | Select-Object -ExpandProperty Sum

    [PSCustomObject]@{
        Results    = @($Results)
        TotalCount = $Results.Count
        TotalSize  = $TotalSize ?? 0
    }
}
