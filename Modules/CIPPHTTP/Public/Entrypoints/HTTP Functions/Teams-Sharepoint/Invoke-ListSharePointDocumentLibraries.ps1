function Invoke-ListSharePointDocumentLibraries {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.TenantFilter
    if (-not $TenantFilter) { $TenantFilter = $Request.Body.TenantFilter }
    $SiteId = $Request.Query.SiteId
    if (-not $SiteId) { $SiteId = $Request.Body.SiteId }

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
        $Drives = New-GraphGetRequest `
            -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drives?`$select=id,name,driveType,webUrl,quota" `
            -tenantid $TenantFilter -asApp $true

        $GraphRequest = foreach ($Drive in @($Drives | Where-Object { $_.id })) {
            [PSCustomObject]@{
                id        = $Drive.id
                name      = $Drive.name
                driveType = $Drive.driveType
                webUrl    = $Drive.webUrl
                usedBytes = $Drive.quota.used
                totalBytes = $Drive.quota.total
            }
        }
        $GraphRequest = @($GraphRequest | Where-Object { $_.driveType -eq 'documentLibrary' } | Sort-Object -Property name)
        if (-not $GraphRequest -or $GraphRequest.Count -eq 0) {
            # Fall back to all drives if none are flagged documentLibrary.
            $GraphRequest = @($Drives | Where-Object { $_.id } | ForEach-Object {
                    [PSCustomObject]@{ id = $_.id; name = $_.name; driveType = $_.driveType; webUrl = $_.webUrl; usedBytes = $_.quota.used; totalBytes = $_.quota.total }
                } | Sort-Object -Property name)
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to list document libraries: $ErrorMessage" -Sev Error
        $StatusCode = [HttpStatusCode]::Forbidden
        $GraphRequest = $ErrorMessage
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @($GraphRequest)
    })
}
