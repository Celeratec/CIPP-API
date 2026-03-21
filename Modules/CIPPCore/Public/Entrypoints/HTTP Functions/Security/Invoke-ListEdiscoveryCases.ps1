function Invoke-ListEdiscoveryCases {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter

    try {
        $Uri = 'https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases'
        $Cases = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true

        $GraphRequest = foreach ($Case in $Cases) {
            [PSCustomObject]@{
                id            = $Case.id
                displayName   = $Case.displayName
                description   = $Case.description
                status        = $Case.status
                createdBy     = $Case.createdBy.user.displayName
                createdDate   = $Case.createdDateTime
                lastModified  = $Case.lastModifiedDateTime
                closedBy      = $Case.closedBy.user.displayName
                closedDate    = $Case.closedDateTime
                externalId    = $Case.externalId
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = @($GraphRequest)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve eDiscovery cases: $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery cases: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
