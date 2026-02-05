function Invoke-DeleteSharepointSite {
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


    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Body.tenantFilter
    $SiteId = $Request.Body.SiteId

    # Site templates that cannot be deleted or require special handling
    $ProtectedTemplates = @{
        'SPSMSITEHOST#0'         = 'Root site collection - cannot be deleted'
        'SRCHCEN#0'              = 'Search Center - system site'
        'SPSPERS#10'             = 'OneDrive site - delete via user management'
        'EHS#1'                  = 'Team Channel site - delete via Teams'
        'TEAMCHANNEL#0'          = 'Team Channel site - delete via Teams'
        'TEAMCHANNEL#1'          = 'Team Channel site - delete via Teams'
    }

    # Templates that need the RemoveSite API instead of SPSiteManager
    $UseRemoveSiteApi = @(
        'SITEPAGEPUBLISHING#0'   # Communication site
        'STS#3'                  # Modern team site without M365 group
    )

    try {
        # Validate required parameters
        if (-not $SiteId) {
            throw "SiteId is required"
        }
        if (-not $TenantFilter) {
            throw "TenantFilter is required"
        }

        # Validate SiteId format (GUID)
        if ($SiteId -notmatch '^(\{)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(\})?$') {
            throw "SiteId must be a valid GUID"
        }

        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter

        # Get site information using SharePoint admin API
        $SiteInfoUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/sites('$SiteId')"

        # Add the headers that SharePoint REST API expects
        $ExtraHeaders = @{
            'accept' = 'application/json'
            'content-type' = 'application/json'
            'odata-version' = '4.0'
        }

        $SiteInfo = New-GraphGETRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $SiteInfoUri -tenantid $TenantFilter -extraHeaders $ExtraHeaders

        if (-not $SiteInfo) {
            throw "Could not retrieve site information from SharePoint Admin API"
        }

        $SiteTemplate = $SiteInfo.Template
        $SiteUrl = $SiteInfo.Url

        # Check if this is a protected template that cannot be deleted
        if ($ProtectedTemplates.ContainsKey($SiteTemplate)) {
            throw "Cannot delete this site. Template: $SiteTemplate - $($ProtectedTemplates[$SiteTemplate])"
        }

        # Check if site is a hub site - must unregister first
        if ($SiteInfo.HubSiteId -eq $SiteId -or $SiteInfo.IsHubSite -eq $true) {
            Write-Host "Site is a hub site, attempting to unregister hub first..."
            try {
                $UnregisterUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/UnregisterHubSite"
                $UnregisterBody = @{ siteUrl = $SiteUrl }
                $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $UnregisterUri -body (ConvertTo-Json -InputObject $UnregisterBody) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                Write-Host "Successfully unregistered hub site"
            } catch {
                Write-Host "Warning: Could not unregister hub site, proceeding with deletion attempt: $($_.Exception.Message)"
            }
        }

        # Determine if site is group-connected based on GroupId
        $IsGroupConnected = $SiteInfo.GroupId -and $SiteInfo.GroupId -ne "00000000-0000-0000-0000-000000000000"

        $DeleteAttempted = $false

        if ($IsGroupConnected) {
            # Use GroupSiteManager/Delete for group-connected sites (Team sites with M365 group)
            $body = @{
                siteUrl = $SiteUrl
            }
            $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/GroupSiteManager/Delete"
            try {
                $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                $DeleteAttempted = $true
            } catch {
                # If GroupSiteManager fails, try RemoveSite as fallback
                Write-Host "GroupSiteManager/Delete failed, trying RemoveSite API: $($_.Exception.Message)"
            }
        }

        if (-not $DeleteAttempted) {
            # For communication sites and other non-group sites, use RemoveSite API
            if ($SiteTemplate -in $UseRemoveSiteApi -or -not $IsGroupConnected) {
                $body = @{
                    siteUrl = $SiteUrl
                }
                $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/RemoveSite"

                try {
                    $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                    $DeleteAttempted = $true
                } catch {
                    $RemoveSiteError = $_.Exception.Message
                    # If RemoveSite fails, try SPSiteManager/delete as final fallback
                    Write-Host "RemoveSite API failed, trying SPSiteManager/delete: $RemoveSiteError"

                    $body = @{
                        siteId = $SiteId
                    }
                    $DeleteUri = "$($SharePointInfo.AdminUrl)/_api/SPSiteManager/delete"

                    try {
                        $null = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri $DeleteUri -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -extraHeaders $ExtraHeaders
                        $DeleteAttempted = $true
                    } catch {
                        # Provide detailed error with template information
                        $SPSiteManagerError = $_.Exception.Message
                        if ($SPSiteManagerError -match 'siteTemplate|template is not allowed') {
                            throw "This site template ($SiteTemplate) cannot be deleted using standard APIs. Site URL: $SiteUrl. You may need to delete this site manually through the SharePoint Admin Center, or if it's connected to a Team/Group, delete the associated Team or M365 Group instead."
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
        $Results = "Successfully initiated deletion of $SiteTypeMsg SharePoint site '$SiteUrl' (ID: $SiteId). This process can take some time to complete in the background."

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = $ErrorMessage.NormalizedError

        # Provide more helpful error messages for common issues
        if ($ErrorText -match 'siteTemplate|template is not allowed') {
            $TemplateInfo = if ($SiteTemplate) { " (Template: $SiteTemplate)" } else { "" }
            $Results = "Failed to delete SharePoint site with ID $SiteId$TemplateInfo. This site type cannot be deleted via API. If this is a Teams-connected site, delete the Team instead. For hub sites, unregister the hub first. Error: $ErrorText"
        } else {
            $Results = "Failed to delete SharePoint site with ID $SiteId. Error: $ErrorText"
        }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    # Associate values to output bindings
    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body = @{ 'Results' = $Results }
    })
}
