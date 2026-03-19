function Invoke-ExecDeployIntegrationApp {
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
        $TemplateId = $Request.Body.templateId
        $Tenants = $Request.Body.tenants
        $Customizations = $Request.Body.customizations

        if (-not $TemplateId) {
            throw 'Template ID is required'
        }
        if (-not $Tenants -or $Tenants.Count -eq 0) {
            throw 'At least one tenant is required'
        }

        # Load the template (built-in or custom)
        $Template = $null

        # Check built-in templates first
        $BuiltInTemplatesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\..\..\..\lib\data\IntegrationTemplates.json'
        if (Test-Path $BuiltInTemplatesPath) {
            $BuiltInTemplates = Get-Content -Path $BuiltInTemplatesPath -Raw | ConvertFrom-Json
            $Template = $BuiltInTemplates | Where-Object { $_.id -eq $TemplateId }
        }

        # Check custom templates if not found in built-in
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

        # Apply customizations if provided
        if ($Customizations) {
            if ($Customizations.appNamePattern) {
                $Template.appNamePattern = $Customizations.appNamePattern
            }
            if ($Customizations.secretExpirationDays) {
                $Template.secretExpirationDays = $Customizations.secretExpirationDays
            }
        }

        # Create deployment tracking entry
        $DeploymentId = [guid]::NewGuid().ToString()
        $DeploymentTable = Get-CIPPTable -TableName 'IntegrationDeployments'

        $TenantCount = ($Tenants | Measure-Object).Count
        $Queue = New-CippQueueEntry -Name "Integration App Deployment: $($Template.name)" -TotalTasks $TenantCount

        # Create batch for orchestrator
        $Batch = foreach ($Tenant in $Tenants) {
            [pscustomobject]@{
                FunctionName   = 'DeployIntegrationApp'
                Tenant         = $Tenant.value
                TenantName     = $Tenant.label
                DeploymentId   = $DeploymentId
                TemplateId     = $TemplateId
                TemplateName   = $Template.name
                AppNamePattern = $Template.appNamePattern
                Permissions    = $Template.permissions
                GenerateSecret = $Template.generateSecret
                SecretExpDays  = $Template.secretExpirationDays
                RedirectUris   = $Template.redirectUris
                QueueId        = $Queue.RowKey
            }
        }

        # Store deployment metadata
        $DeploymentEntity = @{
            PartitionKey  = 'IntegrationDeployment'
            RowKey        = $DeploymentId
            QueueId       = $Queue.RowKey
            TemplateName  = $Template.name
            TemplateId    = $TemplateId
            TenantCount   = $TenantCount
            Status        = 'InProgress'
            StartedBy     = $Username
            StartedAt     = (Get-Date).ToUniversalTime().ToString('o')
            Results       = '[]'
        }
        Add-CIPPAzDataTableEntity @DeploymentTable -Entity $DeploymentEntity -Force

        # Start orchestrator
        $InputObject = @{
            OrchestratorName = 'IntegrationAppDeploymentOrchestrator'
            Batch            = @($Batch)
            SkipLog          = $true
        }
        $null = Start-CIPPOrchestrator -InputObject $InputObject

        Write-LogMessage -headers $Headers -API $APIName -user $Username -message "Started integration app deployment: $($Template.name) to $TenantCount tenant(s)" -Sev 'Info'

        $Results = @{
            Results      = "Deployment started for $($Template.name) to $TenantCount tenant(s)"
            DeploymentId = $DeploymentId
            QueueId      = $Queue.RowKey
        }
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        Write-LogMessage -headers $Headers -API $APIName -user $Username -message "Integration app deployment failed: $($_.Exception.Message)" -Sev 'Error'
        $Results = @{
            Results = "Deployment failed: $($_.Exception.Message)"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = ConvertTo-Json -Depth 10 -InputObject $Results
        })
}
