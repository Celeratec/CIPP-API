function Invoke-AddTenantAllowBlockList {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        $BlockListObject = $Request.Body
        $TenantID = $Request.Body.tenantID.value ?? $Request.Body.tenantID

        if ($TenantID -eq 'AllTenants') {
            $Tenants = (Get-Tenants).defaultDomainName
        } elseif ($TenantID -is [array]) {
            $Tenants = $TenantID
        } else {
            $Tenants = @($TenantID)
        }

        $Entries = @()
        if ($BlockListObject.entries -is [array]) {
            $Entries = $BlockListObject.entries
        } else {
            $Entries = @($BlockListObject.entries -split '[,;]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
        }

        $ListMethod = [string]($BlockListObject.listMethod)
        if ([string]::IsNullOrWhiteSpace($ListMethod)) {
            $Results.Add('listMethod (Block or Allow) is required.')
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::BadRequest
                    Body       = @{ 'Results' = @($Results) }
                })
        }

        foreach ($Tenant in $Tenants) {
            try {
                $ExoRequest = @{
                    tenantid  = $Tenant
                    cmdlet    = 'New-TenantAllowBlockListItems'
                    cmdParams = @{
                        Entries    = $Entries
                        ListType   = [string]$BlockListObject.listType
                        Notes      = [string]$BlockListObject.notes
                        $ListMethod = [bool]$true
                    }
                }

                if ($BlockListObject.NoExpiration -eq $true) {
                    $ExoRequest.cmdParams.NoExpiration = $true
                } elseif ($BlockListObject.RemoveAfter -eq $true) {
                    $ExoRequest.cmdParams.RemoveAfter = 45
                }

                New-ExoRequest @ExoRequest
                $Result = "Successfully added $($BlockListObject.Entries) as type $($BlockListObject.ListType) to the $($BlockListObject.listMethod) list for $Tenant"
                $Results.Add($Result)
                Write-LogMessage -headers $Headers -API $APIName -tenant $Tenant -message $Result -Sev 'Info'
            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                if ($ErrorMessage.NormalizedError -match '403|Forbidden') {
                    $Result = "Failed to create $($ListMethod.ToLower()) list entry for $Tenant. The CIPP service principal does not have Exchange permissions in this tenant. Run a CPV Refresh from the tenant overview page to push the required permissions."
                } else {
                    $Result = "Failed to create $($ListMethod.ToLower()) list entry for $Tenant. Error: $($ErrorMessage.NormalizedError)"
                }
                $Results.Add($Result)
                Write-LogMessage -headers $Headers -API $APIName -tenant $Tenant -message $Result -Sev 'Error' -LogData $ErrorMessage
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to process allow/block list request. Error: $($ErrorMessage.NormalizedError)"
        $Results.Add($Result)
        Write-LogMessage -headers $Headers -API $APIName -message $Result -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                'Results' = @($Results)
            }
        })
}
