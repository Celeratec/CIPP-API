function Invoke-ExecEdiscoveryCaseSearch {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $Action = $Request.Body.action
    $CaseId = $Request.Body.caseId
    $SearchId = $Request.Body.searchId

    $BaseUri = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/searches"

    try {
        switch ($Action) {
            'create' {
                $SearchBody = @{
                    displayName    = $Request.Body.displayName
                    description    = $Request.Body.description
                    contentQuery   = $Request.Body.contentQuery
                }

                if ($Request.Body.dataSourceScopes) {
                    $SearchBody.dataSourceScopes = $Request.Body.dataSourceScopes
                }

                $RequestBody = $SearchBody | ConvertTo-Json -Depth 5 -Compress
                $Result = New-GraphPostRequest -uri $BaseUri -tenantid $TenantFilter -body $RequestBody -type POST -AsApp $true
                $ResponseBody = "Successfully created eDiscovery search '$($Request.Body.displayName)'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'update' {
                $UpdateBody = @{}
                if ($Request.Body.displayName) { $UpdateBody.displayName = $Request.Body.displayName }
                if ($Request.Body.description) { $UpdateBody.description = $Request.Body.description }
                if ($null -ne $Request.Body.contentQuery) { $UpdateBody.contentQuery = $Request.Body.contentQuery }
                $RequestBody = $UpdateBody | ConvertTo-Json -Compress

                New-GraphPostRequest -uri "$BaseUri/$SearchId" -tenantid $TenantFilter -body $RequestBody -type PATCH -AsApp $true
                $ResponseBody = "Successfully updated eDiscovery search '$SearchId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'estimateStatistics' {
                New-GraphPostRequest -uri "$BaseUri/$SearchId/estimateStatistics" -tenantid $TenantFilter -body '{}' -type POST -AsApp $true
                $ResponseBody = "Search estimate started for '$SearchId'. This may take several minutes to complete."
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'delete' {
                New-GraphPostRequest -uri "$BaseUri/$SearchId" -tenantid $TenantFilter -type DELETE -AsApp $true
                $ResponseBody = "Successfully deleted eDiscovery search '$SearchId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            default {
                throw "Unknown action: $Action"
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{ Results = $ResponseBody }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action eDiscovery search: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
