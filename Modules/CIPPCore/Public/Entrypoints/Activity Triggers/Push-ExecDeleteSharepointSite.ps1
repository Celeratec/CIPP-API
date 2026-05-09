function Push-ExecDeleteSharepointSite {
    <#
    .FUNCTIONALITY
        Entrypoint - Runs SharePoint site deletion in the background (activity).
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    param($Item)

    $TenantFilter = $Item.TenantFilter
    $SiteId = $Item.SiteId
    $Headers = $Item.Headers
    $APIName = $Item.APIName

    # Site templates that cannot be deleted or require special handling
    $ProtectedTemplates = @{
        'SPSMSITEHOST#0' = 'Root site collection - cannot be deleted'
        'SRCHCEN#0'      = 'Search Center - system site'
        'SPSPERS#10'     = 'OneDrive site - delete via user management'
        'EHS#1'          = 'Team Channel site - delete via Teams'
        'TEAMCHANNEL#0'  = 'Team Channel site - delete via Teams'
        'TEAMCHANNEL#1'  = 'Team Channel site - delete via Teams'
    }

    $UseRemoveSiteApi = @(
        'SITEPAGEPUBLISHING#0'   # Communication site
        'STS#3'                  # Modern team site without M365 group
    )

    if (-not $SiteId) { throw "SiteId is required" }
    if (-not $TenantFilter) { throw "TenantFilter is required" }
    if ($SiteId -notmatch '^(\{)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(\})?$') {
        throw "SiteId must be a valid GUID"
    }

    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
    $SiteInfoUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/sites('$SiteId')"
    $ExtraHeaders = @{
        'accept'         = 'application/json'
        'content-type'    = 'application/json'
        'odata-version'   = '4.0'
    }

    $SiteInfo = New-GraphGETRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $SiteInfoUri -tenantid $TenantFilter -extraHeaders $ExtraHeaders
    if (-not $SiteInfo) { throw "Could not retrieve site information from SharePoint Admin API" }

    $SiteTemplate = $SiteInfo.Template
    $SiteUrl = $SiteInfo.Url

    if ($ProtectedTemplates.ContainsKey($SiteTemplate)) {
        throw "Cannot delete this site. Template: $SiteTemplate - $($ProtectedTemplates[$SiteTemplate])"
    }

    if ($SiteInfo.HubSiteId -eq $SiteId -or $SiteInfo.IsHubSite -eq $true) {
        try {
            $UnregisterUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/UnregisterHubSite"
            $UnregisterBody = @{ siteUrl = $SiteUrl }
            $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $UnregisterUri -body (ConvertTo-Json -InputObject $UnregisterBody) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
        } catch {
            Write-Host "Warning: Could not unregister hub site, proceeding with deletion attempt: $($_.Exception.Message)"
        }
    }

    $IsGroupConnected = $SiteInfo.GroupId -and $SiteInfo.GroupId -ne "00000000-0000-0000-0000-000000000000"
    $DeleteAttempted = $false

    if ($IsGroupConnected) {
        $body = @{ siteUrl = $SiteUrl }
        $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/GroupSiteManager/Delete"
        try {
            $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
            $DeleteAttempted = $true
        } catch {
            Write-Host "GroupSiteManager/Delete failed, trying RemoveSite API: $($_.Exception.Message)"
        }
    }

    if (-not $DeleteAttempted) {
        if ($SiteTemplate -in $UseRemoveSiteApi -or -not $IsGroupConnected) {
            $body = @{ siteUrl = $SiteUrl }
            $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/RemoveSite"
            try {
                $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                $DeleteAttempted = $true
            } catch {
                $RemoveSiteError = $_.Exception.Message
                $body = @{ siteId = $SiteId }
                $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/SPSiteManager/delete"
                try {
                    $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                    $DeleteAttempted = $true
                } catch {
                    $SPSiteManagerError = $_.Exception.Message
                    if ($SPSiteManagerError -match 'siteTemplate|template is not allowed') {
                        throw "This site template ($SiteTemplate) cannot be deleted using standard APIs. Site URL: $SiteUrl. If this is a Teams-connected site, delete the Team instead. For hub sites, unregister the hub first."
                    }
                    throw $SPSiteManagerError
                }
            }
        }
    }

    $SiteTypeMsg = switch ($true) {
        $IsGroupConnected { "group-connected" }
        ($SiteTemplate -eq 'SITEPAGEPUBLISHING#0') { "communication" }
        default { "regular" }
    }
    $Results = "Successfully initiated deletion of $SiteTypeMsg SharePoint site '$SiteUrl' (ID: $SiteId)."
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info
}
