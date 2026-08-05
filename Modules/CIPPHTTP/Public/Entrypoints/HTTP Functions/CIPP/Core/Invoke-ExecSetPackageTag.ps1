function Invoke-ExecSetPackageTag {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $Table = Get-CippTable -tablename 'templates'

    try {
        # multiPost bulk actions POST an array of template objects. Do not read
        # $Request.Body.Remove on an array — that resolves to Array.Remove (method),
        # not the NoteProperty, so Remove bulk incorrectly takes the Add path.
        $Items = if ($Request.Body -is [array]) { @($Request.Body) } else { @($Request.Body) }
        $First = $Items | Select-Object -First 1
        $GUIDS = @(
            $Items |
                ForEach-Object { $_.GUID } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $Remove = $false
        if ($null -ne $First -and ($First.PSObject.Properties.Name -contains 'Remove')) {
            $Remove = [boolean]$First.Remove
        }

        if ($Remove -eq $true) {
            # Remove package tag by setting it to null/empty
            $PackageValue = $null
            $LogMessage = 'Successfully removed package tag from template with GUID'
            $SuccessMessage = 'Successfully removed package tag from template(s)'
        } else {
            # Add package tag (existing logic)
            $PackageValue = [string]$First.Package
            $LogMessage = 'Successfully updated template with GUID'
            $SuccessMessage = "Successfully updated template(s) with package tag: $PackageValue"
        }

        foreach ($GUID in $GUIDS) {
            $SafeGUID = ConvertTo-CIPPODataFilterValue -Value $GUID -Type String
            $Filter = "RowKey eq '$SafeGUID'"
            $Template = Get-CIPPAzDataTableEntity @Table -Filter $Filter
            $Entity = @{
                JSON         = $Template.JSON
                RowKey       = "$GUID"
                PartitionKey = $Template.PartitionKey
                GUID         = "$GUID"
                Package      = $PackageValue
                SHA          = $Template.SHA ?? $null
                Source       = $Template.Source ?? $null
            }

            Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force

            if ($Remove -eq $true) {
                Write-LogMessage -headers $Headers -API $APIName -message "$LogMessage $GUID" -Sev 'Info'
            } else {
                Write-LogMessage -headers $Headers -API $APIName -message "$LogMessage $GUID with package tag: $PackageValue" -Sev 'Info'
            }
        }

        $body = [pscustomobject]@{ 'Results' = $SuccessMessage }

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        if ($Remove -eq $true) {
            Write-LogMessage -headers $Headers -API $APIName -message "Failed to remove package tag: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
            $body = [pscustomobject]@{'Results' = "Failed to remove package tag: $($ErrorMessage.NormalizedError)" }
        } else {
            Write-LogMessage -headers $Headers -API $APIName -message "Failed to set package tag: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
            $body = [pscustomobject]@{'Results' = "Failed to set package tag: $($ErrorMessage.NormalizedError)" }
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $body
        })
}
