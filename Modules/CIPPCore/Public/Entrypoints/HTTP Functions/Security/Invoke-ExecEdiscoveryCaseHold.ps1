function Invoke-ExecEdiscoveryCaseHold {
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
    $HoldId = $Request.Body.holdId

    $BaseUri = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/legalHolds"

    try {
        switch ($Action) {
            'create' {
                $HoldBody = @{
                    displayName  = $Request.Body.displayName
                    description  = $Request.Body.description
                    contentQuery = $Request.Body.contentQuery
                }

                if ($Request.Body.userSources) {
                    $HoldBody.userSources = @(
                        foreach ($UserSource in $Request.Body.userSources) {
                            @{
                                email           = $UserSource.email
                                includedSources = $UserSource.includedSources ?? 'mailbox,site'
                            }
                        }
                    )
                }

                if ($Request.Body.siteSources) {
                    $HoldBody.siteSources = @(
                        foreach ($SiteSource in $Request.Body.siteSources) {
                            @{ siteWebUrl = $SiteSource.siteWebUrl }
                        }
                    )
                }

                $RequestBody = $HoldBody | ConvertTo-Json -Depth 5 -Compress
                $Result = New-GraphPostRequest -uri $BaseUri -tenantid $TenantFilter -body $RequestBody -type POST -AsApp $true
                $ResponseBody = "Successfully created legal hold '$($Request.Body.displayName)'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'update' {
                $UpdateBody = @{}
                if ($Request.Body.displayName) { $UpdateBody.displayName = $Request.Body.displayName }
                if ($Request.Body.description) { $UpdateBody.description = $Request.Body.description }
                if ($null -ne $Request.Body.contentQuery) { $UpdateBody.contentQuery = $Request.Body.contentQuery }
                $RequestBody = $UpdateBody | ConvertTo-Json -Compress

                New-GraphPostRequest -uri "$BaseUri/$HoldId" -tenantid $TenantFilter -body $RequestBody -type PATCH -AsApp $true
                $ResponseBody = "Successfully updated legal hold '$HoldId'"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            }
            'remove' {
                New-GraphPostRequest -uri "$BaseUri/$HoldId" -tenantid $TenantFilter -type DELETE -AsApp $true
                $ResponseBody = "Successfully removed legal hold '$HoldId'"
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
        $Result = "Failed to $Action legal hold: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
