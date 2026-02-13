function Invoke-ListCrossTenantTemplates {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint

    try {
        $Table = Get-CippTable -tablename 'templates'
        $Filter = "PartitionKey eq 'CrossTenantTemplate'"
        $Templates = Get-CIPPAzDataTableEntity @Table -Filter $Filter

        $Results = foreach ($Template in $Templates) {
            $TemplateData = $Template.JSON | ConvertFrom-Json
            [PSCustomObject]@{
                GUID            = $Template.RowKey
                templateName    = $TemplateData.templateName
                description     = $TemplateData.description
                createdAt       = $TemplateData.createdAt
                updatedAt       = $TemplateData.updatedAt
                updatedBy       = $TemplateData.updatedBy
                settings        = $TemplateData.settings
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = @($Results)
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -message "Failed to list cross-tenant templates: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{
            Results = "Failed to list cross-tenant templates: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
