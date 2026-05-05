function Invoke-ExecRemoveDeletedSite {
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
    $SiteUrl = $Request.Body.SiteUrl
    $DisplayName = $Request.Body.DisplayName

    try {
        if (-not $SiteUrl) {
            throw 'SiteUrl is required'
        }
        if (-not $TenantFilter) {
            throw 'TenantFilter is required'
        }

        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
        $ExtraHeaders = @{
            'accept'       = 'application/json'
            'content-type' = 'application/json'
            'odata-version' = '4.0'
        }

        $Body = @{ siteUrl = $SiteUrl } | ConvertTo-Json -Depth 5
        $RemoveUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/RemoveDeletedSite"

        $null = New-GraphPOSTRequest `
            -scope "$($SharePointInfo.AdminUrl)/.default" `
            -uri $RemoveUri `
            -body $Body `
            -tenantid $TenantFilter `
            -AddedHeaders $ExtraHeaders

        $SiteLabel = if ($DisplayName) { $DisplayName } else { $SiteUrl }
        $Results = "Successfully permanently deleted SharePoint site '$SiteLabel'. This action cannot be undone."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Results }
        })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = $ErrorMessage.NormalizedError
        $Results = "Failed to permanently delete SharePoint site '$SiteUrl'. Error: $ErrorText"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = $Results }
        })
    }
}
