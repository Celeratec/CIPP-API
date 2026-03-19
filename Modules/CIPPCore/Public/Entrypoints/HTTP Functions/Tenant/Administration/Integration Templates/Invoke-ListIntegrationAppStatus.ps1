function Invoke-ListIntegrationAppStatus {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    try {
        $TemplateId = $Request.Body.templateId ?? $Request.Query.templateId
        $Tenants = $Request.Body.tenants ?? @()

        if (-not $TemplateId) {
            throw 'Template ID is required'
        }

        # Load the template to get the app name pattern
        $Template = $null

        $BuiltInTemplatesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\..\..\..\lib\data\IntegrationTemplates.json'
        if (Test-Path $BuiltInTemplatesPath) {
            $BuiltInTemplates = Get-Content -Path $BuiltInTemplatesPath -Raw | ConvertFrom-Json
            $Template = $BuiltInTemplates | Where-Object { $_.id -eq $TemplateId }
        }

        if (-not $Template) {
            $TemplateTable = Get-CIPPTable -TableName 'templates'
            $Filter = "PartitionKey eq 'IntegrationTemplate' and RowKey eq '$TemplateId'"
            $CustomTemplate = Get-CIPPAzDataTableEntity @TemplateTable -Filter $Filter
            if ($CustomTemplate -and $CustomTemplate.JSON) {
                $Template = $CustomTemplate.JSON | ConvertFrom-Json
            }
        }

        if (-not $Template) {
            throw "Template not found: $TemplateId"
        }

        $Results = @()

        foreach ($Tenant in $Tenants) {
            $TenantDomain = $Tenant.value
            $TenantLabel = $Tenant.label

            try {
                # Get tenant info for name pattern
                $TenantInfo = Get-Tenants -TenantFilter $TenantDomain
                $DisplayTenantName = $TenantLabel
                if ($TenantInfo.displayName) {
                    $DisplayTenantName = $TenantInfo.displayName
                }

                # Build expected app name
                $ExpectedAppName = $Template.appNamePattern -replace '\{TenantName\}', $DisplayTenantName

                # Search for existing apps matching the name (escape single quotes for OData)
                $EscapedTemplateName = $Template.name -replace "'", "''"
                $ExistingApps = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications?`$filter=startswith(displayName,'$EscapedTemplateName')" -tenantid $TenantDomain -AsApp $true

                $MatchingApps = @()
                if ($ExistingApps.value) {
                    foreach ($App in $ExistingApps.value) {
                        # Check if app name matches our pattern (exact or similar)
                        if ($App.displayName -eq $ExpectedAppName -or $App.displayName -like "$($Template.name)*") {
                            # Get additional details
                            $AppDetails = @{
                                id              = $App.id
                                appId           = $App.appId
                                displayName     = $App.displayName
                                createdDateTime = $App.createdDateTime
                            }

                            # Check for service principal
                            try {
                                $SP = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($App.appId)'" -tenantid $TenantDomain -AsApp $true
                                $AppDetails.hasServicePrincipal = ($SP.value -and $SP.value.Count -gt 0)
                                if ($AppDetails.hasServicePrincipal) {
                                    $AppDetails.servicePrincipalId = $SP.value[0].id
                                }
                            } catch {
                                $AppDetails.hasServicePrincipal = $false
                            }

                            # Check for secrets
                            try {
                                $AppDetails.secretCount = ($App.passwordCredentials | Measure-Object).Count
                            } catch {
                                $AppDetails.secretCount = 0
                            }

                            $MatchingApps += $AppDetails
                        }
                    }
                }

                $Results += @{
                    tenant           = $TenantDomain
                    tenantName       = $TenantLabel
                    displayName      = $DisplayTenantName
                    expectedAppName  = $ExpectedAppName
                    existingApps     = $MatchingApps
                    hasExistingApps  = ($MatchingApps.Count -gt 0)
                    existingAppCount = $MatchingApps.Count
                }

            } catch {
                $Results += @{
                    tenant           = $TenantDomain
                    tenantName       = $TenantLabel
                    error            = $_.Exception.Message
                    hasExistingApps  = $false
                    existingAppCount = 0
                }
            }
        }

        $Body = @{
            Results      = $Results
            TemplateName = $Template.name
        }
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        Write-LogMessage -headers $Headers -API $APIName -message "Failed to check integration app status: $($_.Exception.Message)" -Sev 'Error'
        $Body = @{
            Results = "Failed to check app status: $($_.Exception.Message)"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = ConvertTo-Json -Depth 10 -InputObject $Body
        })
}
