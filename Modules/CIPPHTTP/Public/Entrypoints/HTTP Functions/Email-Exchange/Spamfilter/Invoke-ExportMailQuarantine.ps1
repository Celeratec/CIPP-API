function Invoke-ExportMailQuarantine {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.Read
    .DESCRIPTION
        Exports filtered quarantine results as CSV or JSON for admin download.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Body.tenantFilter
    $Format = ($Request.Body.format ?? 'csv').ToString().ToLowerInvariant()
    $MaxRows = 5000

    try {
        $Input = @{}
        foreach ($Key in @('days', 'startDate', 'endDate', 'sender', 'recipient', 'messageId', 'subject', 'subjectExact', 'quarantineType', 'releaseStatus', 'policyTypes', 'policyName', 'senderDomain', 'recipientDomain', 'entityType')) {
            if ($null -ne $Request.Body.$Key) {
                $Input[$Key] = $Request.Body.$Key
            }
        }
        $Input.pageSize = 1000

        $Query = Build-CIPPQuarantineQueryParams -QueryInput $Input -ApplyDefaultDateRange
        $AllMessages = [System.Collections.Generic.List[object]]::new()
        $Page = 1
        do {
            $Query.CmdParams.Page = $Page
            $PageResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantFilter -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
                Select-Object -ExcludeProperty *data.type*)
            if ($PageResults) { $AllMessages.AddRange($PageResults) }
            $Page++
        } while ($PageResults.Count -eq $Query.CmdParams.PageSize -and $AllMessages.Count -lt $MaxRows -and $Page -le 1000)

        $Filtered = Apply-CippQuarantinePostFilters -Messages $AllMessages -PostFilters $Query.PostFilters
        $Display = @($Filtered | ConvertTo-CippQuarantineDisplayObject | Sort-Object ReceivedTime -Descending)
        $Truncated = $AllMessages.Count -ge $MaxRows

        if ($Format -eq 'json') {
            $ExportBody = @{
                Results  = $Display
                Metadata = @{
                    count                       = $Display.Count
                    truncated                   = $Truncated
                    format                      = 'json'
                    HasPostFilters              = ($Query.PostFilters.Count -gt 0)
                    RawRowsScanned              = $AllMessages.Count
                    FilteredRowsReturned        = $Display.Count
                    PostFilterPaginationLimited = $Truncated
                }
            }
        } else {
            $CsvRows = foreach ($Row in $Display) {
                [PSCustomObject]@{
                    ReceivedTime     = $Row.ReceivedTime
                    Subject          = $Row.Subject
                    SenderAddress    = $Row.SenderAddress
                    RecipientAddress = $Row.RecipientAddress
                    Type             = $Row.Type
                    ReleaseStatus    = $Row.ReleaseStatus
                    PolicyName       = $Row.PolicyName
                    PolicyType       = $Row.PolicyType
                    Expires          = $Row.Expires
                    MessageId        = $Row.MessageId
                    Identity         = $Row.Identity
                }
            }
            $ExportBody = @{
                Results  = ($CsvRows | ConvertTo-Csv -NoTypeInformation) -join "`n"
                Metadata = @{
                    count                       = $Display.Count
                    truncated                   = $Truncated
                    format                      = 'csv'
                    HasPostFilters              = ($Query.PostFilters.Count -gt 0)
                    RawRowsScanned              = $AllMessages.Count
                    FilteredRowsReturned        = $Display.Count
                    PostFilterPaginationLimited = $Truncated
                }
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = $ExportBody
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
