function Invoke-GetMailQuarantineMessage {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.Read
    .DESCRIPTION
        Returns detailed metadata for a single quarantined message (without exporting EML).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter
    $Identity = $Request.Query.Identity

    try {
        if ([string]::IsNullOrWhiteSpace($Identity)) {
            throw 'Identity is required.'
        }

        $Message = Invoke-CippQuarantineExoRequest -TenantId $TenantFilter -Cmdlet 'Get-QuarantineMessage' -CmdParams @{ Identity = $Identity }
        $Display = ConvertTo-CippQuarantineDisplayObject -Message $Message

        $AuthSummary = $null
        if ($Display.MessageId) {
            try {
                $TraceParams = @{ MessageId = $Display.MessageId }
                $Trace = New-ExoRequest -TenantId $TenantFilter -Cmdlet 'Get-MessageTraceV2' -CmdParams $TraceParams | Select-Object -First 1
                if ($Trace) {
                    $TraceDetail = New-ExoRequest -TenantId $TenantFilter -Cmdlet 'Get-MessageTraceDetailV2' -CmdParams @{
                        MessageTraceId   = $Trace.MessageTraceId
                        RecipientAddress = $Trace.RecipientAddress
                    }
                    if ($TraceDetail) {
                        $DetailEvents = @($TraceDetail)
                        $AuthSummary = ConvertTo-AuthenticationSummary -DetailEntries ($DetailEvents | ForEach-Object { $_.Detail } | Where-Object { $_ })
                    }
                }
            } catch {
                # Auth enrichment is optional; list/detail still succeeds without it.
            }
        }

        $Body = @{
            Results  = $Display
            Metadata = @{
                authSummaryAvailable = [bool]$AuthSummary
            }
            AuthSummary = $AuthSummary
        }
        $StatusCode = [HttpStatusCode]::OK
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
