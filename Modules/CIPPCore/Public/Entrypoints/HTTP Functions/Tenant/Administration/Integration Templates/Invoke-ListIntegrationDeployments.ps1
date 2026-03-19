function Invoke-ListIntegrationDeployments {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.Application.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    try {
        $DeploymentId = $Request.Query.deploymentId
        $DeploymentTable = Get-CIPPTable -TableName 'IntegrationDeployments'

        if ($DeploymentId) {
            # Get specific deployment and its results
            $DeploymentFilter = "PartitionKey eq 'IntegrationDeployment' and RowKey eq '$DeploymentId'"
            $Deployment = Get-CIPPAzDataTableEntity @DeploymentTable -Filter $DeploymentFilter

            if (-not $Deployment) {
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::NotFound
                        Body       = ConvertTo-Json -InputObject @{ Results = "Deployment not found: $DeploymentId" }
                    })
            }

            # Get all results for this deployment
            $ResultsFilter = "PartitionKey eq 'IntegrationDeploymentResult' and DeploymentId eq '$DeploymentId'"
            $Results = Get-CIPPAzDataTableEntity @DeploymentTable -Filter $ResultsFilter

            $ProcessedResults = @($Results | ForEach-Object {
                    [PSCustomObject]@{
                        tenant           = $_.Tenant
                        tenantName       = $_.TenantName
                        displayName      = $_.DisplayName
                        appName          = $_.AppName
                        appId            = $_.AppId
                        tenantId         = $_.TenantId
                        clientSecret     = $_.ClientSecret
                        secretExpiration = $_.SecretExpiration
                        status           = $_.Status
                        message          = $_.Message
                        completedAt      = $_.CompletedAt
                    }
                })

            # Check if deployment is complete
            $CompletedCount = ($ProcessedResults | Measure-Object).Count
            $TotalCount = $Deployment.TenantCount
            $IsComplete = $CompletedCount -ge $TotalCount
            $SuccessCount = ($ProcessedResults | Where-Object { $_.status -eq 'Success' } | Measure-Object).Count
            $FailedCount = ($ProcessedResults | Where-Object { $_.status -eq 'Failed' } | Measure-Object).Count

            # Update deployment status if complete
            if ($IsComplete -and $Deployment.Status -ne 'Complete') {
                $Deployment.Status = 'Complete'
                $Deployment.CompletedAt = (Get-Date).ToUniversalTime().ToString('o')
                Add-CIPPAzDataTableEntity @DeploymentTable -Entity $Deployment -Force
            }

            $Body = @{
                deploymentId  = $DeploymentId
                templateName  = $Deployment.TemplateName
                status        = if ($IsComplete) { 'Complete' } else { 'InProgress' }
                totalCount    = $TotalCount
                completedCount = $CompletedCount
                successCount  = $SuccessCount
                failedCount   = $FailedCount
                startedBy     = $Deployment.StartedBy
                startedAt     = $Deployment.StartedAt
                completedAt   = $Deployment.CompletedAt
                results       = $ProcessedResults
            }

        } else {
            # List recent deployments
            $Filter = "PartitionKey eq 'IntegrationDeployment'"
            $Deployments = Get-CIPPAzDataTableEntity @DeploymentTable -Filter $Filter

            $Body = @($Deployments | Sort-Object -Property Timestamp -Descending | Select-Object -First 50 | ForEach-Object {
                    [PSCustomObject]@{
                        deploymentId = $_.RowKey
                        templateName = $_.TemplateName
                        templateId   = $_.TemplateId
                        tenantCount  = $_.TenantCount
                        status       = $_.Status
                        startedBy    = $_.StartedBy
                        startedAt    = $_.StartedAt
                        completedAt  = $_.CompletedAt
                    }
                })
        }

        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = ConvertTo-Json -Depth 10 -InputObject $Body
            })

    } catch {
        Write-LogMessage -headers $Headers -API $APIName -message "Failed to list integration deployments: $($_.Exception.Message)" -Sev 'Error'
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = ConvertTo-Json -InputObject @{ Results = "Failed to list deployments: $($_.Exception.Message)" }
            })
    }
}
