function New-CIPPSharepointSite {
    <#
    .SYNOPSIS
    Create a new SharePoint site

    .DESCRIPTION
    Create a new SharePoint site using the Modern REST API

    .PARAMETER SiteName
    The name of the site

    .PARAMETER SiteDescription
    The description of the site

    .PARAMETER SiteOwner
    The username of the site owner

    .PARAMETER TemplateName
    The template to use for the site. Default is Communication

    .PARAMETER SiteDesign
    The design to use for the site (for Communication sites). Default is Blank

    .PARAMETER CustomSiteDesignId
    Custom site design ID from tenant's site designs

    .PARAMETER SensitivityLabel
    The Purview sensitivity label to apply to the site

    .PARAMETER Lcid
    The language/locale ID for the site. Default is 1033 (English US)

    .PARAMETER TimeZoneId
    The time zone ID for the site. Default is 13 (UTC-08:00 Pacific Time)

    .PARAMETER StorageQuota
    Storage quota in MB. Default is determined by tenant settings

    .PARAMETER ShareByEmailEnabled
    Allow external sharing via email. Default is false

    .PARAMETER HubSiteId
    Associate the site with a hub site

    .PARAMETER TenantFilter
    The tenant associated with the site

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,

        [Parameter(Mandatory = $true)]
        [string]$SiteDescription,

        [Parameter(Mandatory = $true)]
        [string]$SiteOwner,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Communication', 'Team', 'TeamChannel')]
        [string]$TemplateName = 'Communication',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Topic', 'Showcase', 'Blank', 'Custom')]
        [string]$SiteDesign = 'Blank',

        [Parameter(Mandatory = $false)]
        [string]$CustomSiteDesignId,

        [Parameter(Mandatory = $false)]
        [string]$SensitivityLabel,

        [Parameter(Mandatory = $false)]
        [string]$Classification,

        [Parameter(Mandatory = $false)]
        [int]$Lcid = 1033,

        [Parameter(Mandatory = $false)]
        [int]$TimeZoneId,

        [Parameter(Mandatory = $false)]
        [int]$StorageQuota,

        [Parameter(Mandatory = $false)]
        [bool]$ShareByEmailEnabled = $false,

        [Parameter(Mandatory = $false)]
        [string]$HubSiteId,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        $APIName = 'Create SharePoint Site',
        $Headers
    )

    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
    $SitePath = $SiteName -replace ' ' -replace '[^A-Za-z0-9-]'
    $SiteUrl = "https://$($SharePointInfo.TenantName).sharepoint.com/sites/$SitePath"

    # Map template name to SharePoint web template
    $WebTemplate = switch ($TemplateName) {
        'Communication' { 'SITEPAGEPUBLISHING#0' }
        'Team' { 'STS#3' }
        'TeamChannel' { 'TEAMCHANNEL#1' }
        default { 'SITEPAGEPUBLISHING#0' }
    }

    # Default site design IDs (built-in Microsoft designs for Communication sites)
    $DefaultSiteDesignIds = @{
        'Topic'    = '96c933ac-3698-44c7-9f4a-5fd17d71af9e'
        'Showcase' = '6142d2a0-63a5-4ba0-aede-d9fefca2c767'
        'Blank'    = 'f6cc5403-0d63-442e-96c0-285923709ffc'
    }

    # Determine site design ID
    $SiteDesignId = '00000000-0000-0000-0000-000000000000'
    $WebTemplateExtensionId = '00000000-0000-0000-0000-000000000000'

    if ($TemplateName -eq 'Communication') {
        if ($SiteDesign -eq 'Custom' -and $CustomSiteDesignId) {
            # Use custom site design - validate it's a GUID
            if ($CustomSiteDesignId -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
                # Check if it's a default design ID or a custom one
                if ($CustomSiteDesignId -in $DefaultSiteDesignIds.Values) {
                    $SiteDesignId = $CustomSiteDesignId
                } else {
                    # Custom site design uses WebTemplateExtensionId
                    $WebTemplateExtensionId = $CustomSiteDesignId
                }
            } else {
                Write-Warning "Invalid CustomSiteDesignId format, using Blank design"
                $SiteDesignId = $DefaultSiteDesignIds['Blank']
            }
        } elseif ($DefaultSiteDesignIds.ContainsKey($SiteDesign)) {
            $SiteDesignId = $DefaultSiteDesignIds[$SiteDesign]
        } else {
            $SiteDesignId = $DefaultSiteDesignIds['Blank']
        }
    }
    # Team sites don't use site designs in the same way

    # Create the request body
    $Request = @{
        Title                  = $SiteName
        Url                    = $SiteUrl
        Lcid                   = $Lcid
        ShareByEmailEnabled    = $ShareByEmailEnabled
        Description            = $SiteDescription
        WebTemplate            = $WebTemplate
        SiteDesignId           = $SiteDesignId
        Owner                  = $SiteOwner
        WebTemplateExtensionId = $WebTemplateExtensionId
    }

    # Add optional parameters
    if ($SensitivityLabel) {
        $Request.SensitivityLabel = $SensitivityLabel
    }
    if ($Classification) {
        $Request.Classification = $Classification
    }
    if ($TimeZoneId) {
        $Request.TimeZoneId = $TimeZoneId
    }
    if ($StorageQuota -and $StorageQuota -gt 0) {
        $Request.StorageMaximumLevel = $StorageQuota
    }
    if ($HubSiteId -and $HubSiteId -ne '00000000-0000-0000-0000-000000000000') {
        $Request.HubSiteId = $HubSiteId
    }

    Write-Verbose (ConvertTo-Json -InputObject $Request -Compress -Depth 10)

    $body = @{
        request = $Request
    }

    # Create the site
    if ($PSCmdlet.ShouldProcess($SiteName, 'Create new SharePoint site')) {
        $AddedHeaders = @{
            'accept'        = 'application/json;odata.metadata=none'
            'odata-version' = '4.0'
        }
        try {
            $Results = New-GraphPOSTRequest -scope "$($SharePointInfo.AdminUrl)/.default" -uri "$($SharePointInfo.AdminUrl)/_api/SPSiteManager/create" -body (ConvertTo-Json -Depth 10 -InputObject $body) -tenantid $TenantFilter -AddedHeaders $AddedHeaders
        } catch {
            $ErrorMessage = Get-CippException -Exception $_
            $Result = "Failed to create new SharePoint site $SiteName with URL $SiteUrl. Error: $($ErrorMessage.NormalizedError)"
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error -LogData $ErrorMessage
            throw $Result
        }
    }

    # Check the results. This response is weird. https://learn.microsoft.com/en-us/sharepoint/dev/apis/site-creation-rest
    switch ($Results.SiteStatus) {
        '0' {
            $Result = "Failed to create new SharePoint site $SiteName with URL $SiteUrl. The site doesn't exist."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error
            throw $Result
        }
        '1' {
            $Result = "Successfully created new SharePoint site $SiteName with URL $SiteUrl. The site is however currently being provisioned. Please wait for it to finish."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info
            return $Result
        }
        '2' {
            $Result = "Successfully created new SharePoint site $SiteName with URL $SiteUrl"
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info
            return $Result
        }
        '3' {
            $Result = "Failed to create new SharePoint site $SiteName with URL $SiteUrl. An error occurred while provisioning the site."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error
            throw $Result
        }
        '4' {
            $Result = "Failed to create new SharePoint site $SiteName with URL $SiteUrl. The site already exists."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error
            throw $Result
        }
        default {}
    }
}
