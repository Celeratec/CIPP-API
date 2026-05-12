function Invoke-ListIntegrationTemplates {
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
        $TemplateId = $Request.Query.id

        # Load built-in templates from the module's data directory
        $BuiltInTemplatesPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\..\..\..\lib\data\IntegrationTemplates.json'
        $BuiltInTemplates = @()
        if (Test-Path $BuiltInTemplatesPath) {
            $BuiltInTemplates = Get-Content -Path $BuiltInTemplatesPath -Raw | ConvertFrom-Json
        }

        # Load custom templates from Azure Table Storage
        $Table = Get-CIPPTable -TableName 'templates'
        $Filter = "PartitionKey eq 'IntegrationTemplate'"
        $CustomTemplates = Get-CIPPAzDataTableEntity @Table -Filter $Filter

        # Process custom templates from storage
        $ProcessedCustomTemplates = $CustomTemplates | ForEach-Object {
            try {
                $TemplateData = $null
                if ($_.JSON) {
                    $TemplateData = $_.JSON | ConvertFrom-Json -ErrorAction Stop
                }

                if ($TemplateData) {
                    $TemplateData | Add-Member -NotePropertyName 'id' -NotePropertyValue $_.RowKey -Force
                    $TemplateData | Add-Member -NotePropertyName 'isBuiltIn' -NotePropertyValue $false -Force
                    $TemplateData | Add-Member -NotePropertyName 'timestamp' -NotePropertyValue $_.Timestamp.DateTime.ToString('yyyy-MM-ddTHH:mm:ssZ') -Force
                    return $TemplateData
                }
            } catch {
                Write-LogMessage -headers $Headers -API $APIName -message "Error processing custom template $($_.RowKey): $($_.Exception.Message)" -Sev 'Error'
            }
            return $null
        } | Where-Object { $null -ne $_ }

        # Merge built-in and custom templates
        $AllTemplates = @($BuiltInTemplates) + @($ProcessedCustomTemplates)

        # Filter by ID if requested
        if ($TemplateId) {
            $AllTemplates = $AllTemplates | Where-Object { $_.id -eq $TemplateId }
        }

        $Body = @($AllTemplates)

    } catch {
        Write-LogMessage -headers $Headers -API $APIName -message "Failed to list integration templates: $($_.Exception.Message)" -Sev 'Error'
        $Body = @{
            Results = "Failed to list integration templates: $($_.Exception.Message)"
        }
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = ConvertTo-Json -Depth 10 -InputObject $Body
            })
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = ConvertTo-Json -Depth 10 -InputObject $Body
        })
}
