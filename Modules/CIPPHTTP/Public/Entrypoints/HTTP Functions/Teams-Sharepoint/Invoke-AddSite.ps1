function Invoke-AddSite {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Headers = $Request.Headers

    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Body.tenantFilter
    $SharePointObj = $Request.Body

    # Build parameters hashtable for splatting
    $SiteParams = @{
        Headers         = $Headers
        SiteName        = $SharePointObj.siteName
        SiteDescription = $SharePointObj.siteDescription
        TenantFilter    = $TenantFilter
    }

    # Handle owner - can be object with value property or direct string
    if ($SharePointObj.siteOwner.value) {
        $SiteParams.SiteOwner = $SharePointObj.siteOwner.value
    } elseif ($SharePointObj.siteOwner) {
        $SiteParams.SiteOwner = $SharePointObj.siteOwner
    }

    # Handle template name
    if ($SharePointObj.templateName.value) {
        $SiteParams.TemplateName = $SharePointObj.templateName.value
    } elseif ($SharePointObj.templateName) {
        $SiteParams.TemplateName = $SharePointObj.templateName
    }

    # Handle site design
    if ($SharePointObj.siteDesign.value) {
        $SiteParams.SiteDesign = $SharePointObj.siteDesign.value
    } elseif ($SharePointObj.siteDesign) {
        $SiteParams.SiteDesign = $SharePointObj.siteDesign
    }

    # Handle custom site design ID
    if ($SharePointObj.customSiteDesignId.value) {
        $SiteParams.CustomSiteDesignId = $SharePointObj.customSiteDesignId.value
    } elseif ($SharePointObj.customSiteDesignId) {
        $SiteParams.CustomSiteDesignId = $SharePointObj.customSiteDesignId
    }

    # Handle sensitivity label
    if ($SharePointObj.sensitivityLabel.value) {
        $SiteParams.SensitivityLabel = $SharePointObj.sensitivityLabel.value
    } elseif ($SharePointObj.sensitivityLabel) {
        $SiteParams.SensitivityLabel = $SharePointObj.sensitivityLabel
    }

    # Handle language/LCID
    if ($SharePointObj.lcid.value) {
        $SiteParams.Lcid = [int]$SharePointObj.lcid.value
    } elseif ($SharePointObj.lcid) {
        $SiteParams.Lcid = [int]$SharePointObj.lcid
    }

    # Handle time zone
    if ($SharePointObj.timeZoneId.value) {
        $SiteParams.TimeZoneId = [int]$SharePointObj.timeZoneId.value
    } elseif ($SharePointObj.timeZoneId) {
        $SiteParams.TimeZoneId = [int]$SharePointObj.timeZoneId
    }

    # Handle storage quota
    if ($SharePointObj.storageQuota) {
        $SiteParams.StorageQuota = [int]$SharePointObj.storageQuota
    }

    # Handle external sharing
    if ($null -ne $SharePointObj.shareByEmailEnabled) {
        $SiteParams.ShareByEmailEnabled = [bool]$SharePointObj.shareByEmailEnabled
    }

    # Handle hub site association
    if ($SharePointObj.hubSiteId.value) {
        $SiteParams.HubSiteId = $SharePointObj.hubSiteId.value
    } elseif ($SharePointObj.hubSiteId) {
        $SiteParams.HubSiteId = $SharePointObj.hubSiteId
    }

    try {
        $Result = New-CIPPSharepointSite @SiteParams
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Result = $_.Exception.Message
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{'Results' = $Result }
        })
}
