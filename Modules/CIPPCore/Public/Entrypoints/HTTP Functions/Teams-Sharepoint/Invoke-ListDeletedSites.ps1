function Invoke-ListDeletedSites {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $TenantFilter = $Request.Query.TenantFilter

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'TenantFilter is required'
        })
    }

    try {
        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter

        # Use CSOM ProcessQuery to call Tenant.GetDeletedSitePropertiesFromSharePoint
        # This is the same pattern used in Set-CIPPSharePointPerms.ps1
        $XML = @"
<Request xmlns="http://schemas.microsoft.com/sharepoint/clientquery/2009" AddExpandoFieldTypeSuffix="true" SchemaVersion="15.0.0.0" LibraryVersion="16.0.0.0" ApplicationName=".NET Library">
  <Actions>
    <ObjectPath Id="2" ObjectPathId="1" />
    <ObjectPath Id="4" ObjectPathId="3" />
    <Query Id="5" ObjectPathId="3">
      <Query SelectAllProperties="true">
        <Properties />
      </Query>
      <ChildItemQuery SelectAllProperties="true">
        <Properties />
      </ChildItemQuery>
    </Query>
  </Actions>
  <ObjectPaths>
    <Constructor Id="1" TypeId="{268004ae-ef6b-4e9b-8425-127220d84719}" />
    <Method Id="3" ParentId="1" Name="GetDeletedSitePropertiesFromSharePoint">
      <Parameters>
        <Parameter Type="String">0</Parameter>
      </Parameters>
    </Method>
  </ObjectPaths>
</Request>
"@

        $Result = New-GraphPostRequest `
            -scope "$($SharePointInfo.AdminUrl)/.default" `
            -tenantid $TenantFilter `
            -Uri "$($SharePointInfo.AdminUrl)/_vti_bin/client.svc/ProcessQuery" `
            -Type POST `
            -Body $XML `
            -ContentType 'text/xml'

        # Check for CSOM errors
        $ErrorInfo = $Result | Where-Object { $_.ErrorInfo } | Select-Object -First 1
        if ($ErrorInfo.ErrorInfo.ErrorMessage) {
            throw "SharePoint API error: $($ErrorInfo.ErrorInfo.ErrorMessage)"
        }

        # Extract child items from the query result
        $DeletedSiteData = @()
        foreach ($Item in $Result) {
            if ($Item._Child_Items_) {
                $DeletedSiteData = $Item._Child_Items_
                break
            }
        }

        $Now = Get-Date
        $GraphRequest = foreach ($Site in $DeletedSiteData) {
            # DaysRemaining is provided directly by the CSOM API
            $DaysRemaining = if ($null -ne $Site.DaysRemaining) {
                [int]$Site.DaysRemaining
            } elseif ($Site.DeletionTime) {
                $DeletedDate = [datetime]$Site.DeletionTime
                $ExpiryDate = $DeletedDate.AddDays(93)
                [math]::Max(0, [math]::Ceiling(($ExpiryDate - $Now).TotalDays))
            } else {
                0
            }

            # Extract a display name from the URL (last segment)
            $Url = $Site.Url
            $DisplayName = if ($Url) {
                $UrlParts = $Url.TrimEnd('/') -split '/'
                $UrlParts[-1] -replace '%20', ' '
            } else {
                'Unknown'
            }

            [PSCustomObject]@{
                siteId          = $Site.SiteId
                displayName     = $DisplayName
                webUrl          = $Url
                deletedDateTime = $Site.DeletionTime
                daysRemaining   = $DaysRemaining
                status          = $Site.Status
                storageQuota    = $Site.StorageMaximumLevel
                resourceQuota   = $Site.ResourceQuota
            }
        }

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $GraphRequest = $ErrorMessage
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @($GraphRequest | Sort-Object -Property deletedDateTime -Descending)
    })
}
