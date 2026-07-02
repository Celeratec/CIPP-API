function Invoke-ExecEmailTroubleshoot {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.TransportRule.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter

    $TraceResults = @()
    $QuarantineResults = @()
    $TraceError = $null
    $QuarantineError = $null

    $TraceParams = @{}
    if ($Request.Body.messageId) {
        $TraceParams['MessageId'] = $Request.Body.messageId
    } else {
        if ($Request.Body.days) {
            $TraceParams['StartDate'] = (Get-Date).AddDays(-[int]$Request.Body.days).ToUniversalTime().ToString('s')
            $TraceParams['EndDate'] = (Get-Date).ToUniversalTime().ToString('s')
        } elseif ($Request.Body.startDate) {
            if ($Request.Body.startDate -match '^\d+$') {
                $TraceParams['StartDate'] = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Request.Body.startDate).UtcDateTime.ToString('s')
            } else {
                $TraceParams['StartDate'] = $Request.Body.startDate
            }
            if ($Request.Body.endDate) {
                if ($Request.Body.endDate -match '^\d+$') {
                    $TraceParams['EndDate'] = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Request.Body.endDate).UtcDateTime.ToString('s')
                } else {
                    $TraceParams['EndDate'] = $Request.Body.endDate
                }
            }
        }

        if ($Request.Body.status) {
            $StatusValue = if ($Request.Body.status.value) { $Request.Body.status.value } else { $Request.Body.status }
            if ($StatusValue -is [array]) { $StatusValue = $StatusValue[0] }
            $TraceParams['Status'] = $StatusValue
        }
        if (![string]::IsNullOrEmpty($Request.Body.fromIP)) {
            $TraceParams['FromIP'] = $Request.Body.fromIP
        }
        if (![string]::IsNullOrEmpty($Request.Body.toIP)) {
            $TraceParams['ToIP'] = $Request.Body.toIP
        }
    }

    $SenderValue = if ($Request.Body.sender) {
        $s = $Request.Body.sender
        if ($s -is [array]) { ($s[0].value ?? $s[0]) } else { $s.value ?? $s }
    } else { $null }

    $RecipientValue = if ($Request.Body.recipient) {
        $r = $Request.Body.recipient
        if ($r -is [array]) { ($r[0].value ?? $r[0]) } else { $r.value ?? $r }
    } else { $null }

    $SenderApi = if ($SenderValue) { $SenderValue -replace '#', '%23' } else { $null }
    $RecipientApi = if ($RecipientValue) { $RecipientValue -replace '#', '%23' } else { $null }

    if ($SenderApi) { $TraceParams['SenderAddress'] = $SenderApi }
    if ($RecipientApi) { $TraceParams['RecipientAddress'] = $RecipientApi }

    try {
        $TraceResults = @(New-ExoRequest -TenantId $TenantFilter -Cmdlet 'Get-MessageTraceV2' -CmdParams $TraceParams |
            Select-Object MessageTraceId, MessageId, Status, Subject, RecipientAddress, SenderAddress,
                @{ Name = 'Received'; Expression = { $_.Received.ToString('u') } }, FromIP, ToIP)
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message 'Executed message trace via troubleshooter' -Sev 'Info'
    } catch {
        $TraceError = "Message trace failed: $((Get-CippException -Exception $_).NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Message trace failed: $($_.Exception.Message)" -Sev 'Error'
    }

    $QuarantineInput = @{
        days            = $Request.Body.days
        startDate       = $Request.Body.startDate
        endDate         = $Request.Body.endDate
        sender          = $Request.Body.sender
        recipient       = $Request.Body.recipient
        messageId       = $Request.Body.messageId
        subject         = $Request.Body.subject
        subjectExact    = $Request.Body.subjectExact
        quarantineType  = $Request.Body.quarantineType
        releaseStatus   = $Request.Body.releaseStatus
        policyTypes     = $Request.Body.policyTypes
        policyName      = $Request.Body.policyName
        senderDomain    = $Request.Body.senderDomain
        recipientDomain = $Request.Body.recipientDomain
        pageSize        = 1000
    }

    try {
        $ApplyDefaultDate = -not $Request.Body.messageId
        $Query = Build-CIPPQuarantineQueryParams -QueryInput $QuarantineInput -ApplyDefaultDateRange:$ApplyDefaultDate
        $RawResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantFilter -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
            Select-Object -ExcludeProperty *data.type*)
        $Filtered = Apply-CippQuarantinePostFilters -Messages $RawResults -PostFilters $Query.PostFilters
        $QuarantineResults = @($Filtered | ConvertTo-CippQuarantineDisplayObject)
    } catch {
        $QuarantineError = "Quarantine search failed: $((Get-CippException -Exception $_).NormalizedError)"
        if ($_.Exception.Message -match 'is not recognized') {
            $QuarantineError += " Quarantine access requires the SAM user to hold a role that includes Exchange quarantine permissions in this tenant - typically the Security Administrator GDAP role (or an Exchange role group containing the Quarantine role). If the standalone Quarantine Management page works for this tenant, this was a transient Exchange Online error - run the search again."
        }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine search failed: $($_.Exception.Message)" -Sev 'Error'
    }

    $Body = @{
        Results = @{
            MessageTrace     = $TraceResults
            Quarantine       = $QuarantineResults
            TraceError       = $TraceError
            QuarantineError  = $QuarantineError
            Summary          = @{
                traceCount           = $TraceResults.Count
                quarantineCount      = $QuarantineResults.Count
                quarantineUnreleased = @($QuarantineResults | Where-Object { $_.ReleaseStatus -ne 'RELEASED' }).Count
            }
        }
    }

    return ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
}
