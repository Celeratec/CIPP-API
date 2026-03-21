function Invoke-ExecEdiscoveryCase {
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

    $BaseUri = 'https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases'

    try {
        switch ($Action) {
            'create' {
                $RequestBody = @{
                    displayName = $Request.Body.displayName
                    description = $Request.Body.description
                    externalId  = $Request.Body.externalId
                } | ConvertTo-Json -Compress

                $Result = New-GraphPostRequest -uri $BaseUri -tenantid $TenantFilter -body $RequestBody -type POST -AsApp $true
                $ResponseBody = "Successfully created eDiscovery case '$($Request.Body.displayName)'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'update' {
                $RequestBody = @{}
                if ($Request.Body.displayName) { $RequestBody.displayName = $Request.Body.displayName }
                if ($Request.Body.description) { $RequestBody.description = $Request.Body.description }
                $RequestBody = $RequestBody | ConvertTo-Json -Compress

                New-GraphPostRequest -uri "$BaseUri/$CaseId" -tenantid $TenantFilter -body $RequestBody -type PATCH -AsApp $true
                $ResponseBody = "Successfully updated eDiscovery case '$CaseId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'close' {
                New-GraphPostRequest -uri "$BaseUri/$CaseId/close" -tenantid $TenantFilter -body '{}' -type POST -AsApp $true
                $ResponseBody = "Successfully closed eDiscovery case '$CaseId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'reopen' {
                New-GraphPostRequest -uri "$BaseUri/$CaseId/reopen" -tenantid $TenantFilter -body '{}' -type POST -AsApp $true
                $ResponseBody = "Successfully reopened eDiscovery case '$CaseId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'delete' {
                New-GraphPostRequest -uri "$BaseUri/$CaseId" -tenantid $TenantFilter -type DELETE -AsApp $true
                $ResponseBody = "Successfully deleted eDiscovery case '$CaseId'"
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
        $Result = "Failed to $Action eDiscovery case: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
