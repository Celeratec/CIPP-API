function Invoke-ExecDeleteIntegrationApp {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $Username = $Request.Headers.'x-ms-client-principal-name'

    try {
        $TenantFilter = $Request.Body.tenantFilter
        $AppId = $Request.Body.appId
        $AppObjectId = $Request.Body.appObjectId

        if (-not $TenantFilter) {
            throw 'Tenant filter is required'
        }
        if (-not $AppObjectId -and -not $AppId) {
            throw 'Either appId or appObjectId is required'
        }

        # If we only have appId, get the object ID
        if (-not $AppObjectId -and $AppId) {
            $App = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$AppId'" -tenantid $TenantFilter -AsApp $true
            if ($App.value -and $App.value.Count -gt 0) {
                $AppObjectId = $App.value[0].id
                $AppDisplayName = $App.value[0].displayName
            } else {
                throw "Application with appId '$AppId' not found"
            }
        } else {
            # Get app details for logging
            try {
                $App = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId" -tenantid $TenantFilter -AsApp $true
                $AppDisplayName = $App.displayName
                $AppId = $App.appId
            } catch {
                $AppDisplayName = 'Unknown'
            }
        }

        # Delete the service principal first (if exists and we have appId)
        if ($AppId) {
            try {
                $SP = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$AppId'" -tenantid $TenantFilter -AsApp $true
                if ($SP.value -and $SP.value.Count -gt 0) {
                    $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($SP.value[0].id)" -type DELETE -tenantid $TenantFilter -AsApp $true
                    Write-LogMessage -headers $Headers -API $APIName -user $Username -tenant $TenantFilter -message "Deleted service principal for app '$AppDisplayName'" -Sev 'Info'
                }
            } catch {
                Write-LogMessage -headers $Headers -API $APIName -user $Username -tenant $TenantFilter -message "Warning: Could not delete service principal: $($_.Exception.Message)" -Sev 'Warning'
            }
        }

        # Delete the application
        $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId" -type DELETE -tenantid $TenantFilter -AsApp $true

        Write-LogMessage -headers $Headers -API $APIName -user $Username -tenant $TenantFilter -message "Deleted integration app '$AppDisplayName' (AppId: $AppId)" -Sev 'Info'

        $Results = @{
            Results = "Successfully deleted application '$AppDisplayName'"
            AppId   = $AppId
            Tenant  = $TenantFilter
        }
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        Write-LogMessage -headers $Headers -API $APIName -user $Username -message "Failed to delete integration app: $($_.Exception.Message)" -Sev 'Error'
        $Results = @{
            Results = "Failed to delete application: $($_.Exception.Message)"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = ConvertTo-Json -Depth 10 -InputObject $Results
        })
}
