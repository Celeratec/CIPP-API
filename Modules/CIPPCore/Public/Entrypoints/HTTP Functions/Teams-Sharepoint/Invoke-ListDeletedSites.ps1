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
        $DeletedSites = New-GraphGetRequest `
            -uri 'https://graph.microsoft.com/v1.0/admin/sharepoint/deletedSites?$select=id,displayName,webUrl,deletedDateTime,siteCollection&$top=999' `
            -tenantid $TenantFilter `
            -asApp $true

        $Now = Get-Date
        $GraphRequest = foreach ($Site in $DeletedSites) {
            $DeletedDate = if ($Site.deletedDateTime) { [datetime]$Site.deletedDateTime } else { $null }
            $DaysRemaining = if ($DeletedDate) {
                $ExpiryDate = $DeletedDate.AddDays(93)
                [math]::Max(0, [math]::Ceiling(($ExpiryDate - $Now).TotalDays))
            } else {
                'Unknown'
            }

            [PSCustomObject]@{
                siteId          = $Site.id
                displayName     = $Site.displayName
                webUrl          = $Site.webUrl
                deletedDateTime = $Site.deletedDateTime
                daysRemaining   = $DaysRemaining
                siteCollection  = $Site.siteCollection
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
