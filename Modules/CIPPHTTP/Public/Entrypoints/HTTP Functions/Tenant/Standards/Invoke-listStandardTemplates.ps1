function Invoke-listStandardTemplates {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.Standards.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    # Interact with query parameters or the body of the request.
    $ID = $Request.Query.id
    $IntuneTemplatesCache = $null
    $CATemplatesCache = $null
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq 'StandardsTemplateV2'"
    $Templates = (Get-CIPPAzDataTableEntity @Table -Filter $Filter) | ForEach-Object {
        $JSON = $_.JSON -replace '"Action":', '"action":'
        try {
            $RowKey = $_.RowKey
            $Data = $JSON | ConvertFrom-Json -Depth 20 -ErrorAction SilentlyContinue

        } catch {
            Write-Host "$($RowKey) standard could not be loaded: $($_.Exception.Message)"
            return
        }
        if ($Data) {
            $Data | Add-Member -NotePropertyName 'GUID' -NotePropertyValue $_.GUID -Force
            $Data | Add-Member -NotePropertyName 'source' -NotePropertyValue $_.Source -Force
            $Data | Add-Member -NotePropertyName 'isSynced' -NotePropertyValue (![string]::IsNullOrEmpty($_.SHA)) -Force

            if (!$Data.excludedTenants) {
                $Data | Add-Member -NotePropertyName 'excludedTenants' -NotePropertyValue @() -Force
            } else {
                # Handle case where excludedTenants is the literal string 'excludedTenants' (data corruption)
                if ($Data.excludedTenants -eq 'excludedTenants') {
                    $Data.excludedTenants = @()
                } else {
                    # Wrap in array and filter out any invalid entries
                    $Data.excludedTenants = @($Data.excludedTenants) | Where-Object {
                        $_ -and $_ -ne 'excludedTenants' -and $_ -ne 'tenantFilter'
                    }
                }
            }

            # Ensure standards key always exists (prevents frontend crash on missing property)
            if (!$Data.standards) {
                $Data | Add-Member -NotePropertyName 'standards' -NotePropertyValue @{} -Force
                Write-Host "Template '$($Data.templateName)' ($RowKey) was missing 'standards' key - auto-initialized"
            } else {
                # Re-expand TemplateList-Tags live so stale addedFields snapshots don't show removed templates
                foreach ($StandardName in $Data.standards.PSObject.Properties.Name) {
                    $StandardConfig = $Data.standards.$StandardName
                    $Items = if ($StandardConfig -is [System.Collections.IEnumerable] -and $StandardConfig -isnot [string]) { $StandardConfig } else { @($StandardConfig) }
                    foreach ($Item in $Items) {
                        if ($Item.'TemplateList-Tags' -and $Item.'TemplateList-Tags'.value) {
                            $PartitionKey = switch ($StandardName) {
                                'ConditionalAccessTemplate' { 'CATemplate' }
                                'IntuneTemplate' { 'IntuneTemplate' }
                                default { 'IntuneTemplate' }
                            }
                            if ($PartitionKey -eq 'CATemplate') {
                                if (-not $CATemplatesCache) {
                                    $CATable = Get-CippTable -tablename 'templates'
                                    $CAFilter = "PartitionKey eq 'CATemplate'"
                                    $CATemplatesCache = Get-CIPPAzDataTableEntity @CATable -Filter $CAFilter
                                }
                                $TemplatesCache = $CATemplatesCache
                            } else {
                                if (-not $IntuneTemplatesCache) {
                                    $IntuneTable = Get-CippTable -tablename 'templates'
                                    $IntuneFilter = "PartitionKey eq 'IntuneTemplate'"
                                    $IntuneTemplatesCache = Get-CIPPAzDataTableEntity @IntuneTable -Filter $IntuneFilter
                                }
                                $TemplatesCache = $IntuneTemplatesCache
                            }
                            $PackageName = $Item.'TemplateList-Tags'.value
                            $LiveExpanded = @($TemplatesCache | Where-Object package -EQ $PackageName | ForEach-Object {
                                    $TplJson = $_.JSON | ConvertFrom-Json -ErrorAction SilentlyContinue
                                    [pscustomobject]@{
                                        GUID        = $_.RowKey
                                        displayName = if ($TplJson.displayName) { $TplJson.displayName } else { $_.RowKey }
                                        name        = if ($TplJson.displayName) { $TplJson.displayName } else { $_.RowKey }
                                    }
                                })
                            if ($Item.'TemplateList-Tags'.addedFields) {
                                $Item.'TemplateList-Tags'.addedFields | Add-Member -NotePropertyName 'templates' -NotePropertyValue $LiveExpanded -Force
                            }
                            if ($Item.'TemplateList-Tags'.rawData) {
                                $Item.'TemplateList-Tags'.rawData | Add-Member -NotePropertyName 'templates' -NotePropertyValue $LiveExpanded -Force
                            }
                            if (-not $Item.'TemplateList-Tags'.addedFields -and -not $Item.'TemplateList-Tags'.rawData) {
                                $Item.'TemplateList-Tags' | Add-Member -NotePropertyName 'addedFields' -NotePropertyValue ([pscustomobject]@{ templates = $LiveExpanded }) -Force
                            }
                        }
                    }
                }
            }

            $Data
        }
    } | Sort-Object -Property templateName

    if ($ID) { $Templates = $Templates | Where-Object GUID -EQ $ID }
    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = @($Templates) }
        })

}
