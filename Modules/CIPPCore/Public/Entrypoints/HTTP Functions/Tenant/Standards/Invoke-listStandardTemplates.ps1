function Invoke-listStandardTemplates {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Standards.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    # Interact with query parameters or the body of the request.
    $ID = $Request.Query.id
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
