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
        $TraceError = "Message trace failed: $($_.Exception.Message)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $TraceError -Sev 'Error'
    }

    $QuarantineParams = @{ 'PageSize' = 1000 }
    if ($SenderApi) { $QuarantineParams['SenderAddress'] = @($SenderApi) }
    if ($Request.Body.days) {
        $QuarantineParams['StartReceivedDate'] = (Get-Date).AddDays(-[int]$Request.Body.days).ToUniversalTime()
        $QuarantineParams['EndReceivedDate'] = (Get-Date).ToUniversalTime()
    } elseif ($Request.Body.startDate) {
        if ($Request.Body.startDate -match '^\d+$') {
            $QuarantineParams['StartReceivedDate'] = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Request.Body.startDate).UtcDateTime
        } else {
            $QuarantineParams['StartReceivedDate'] = [DateTime]::Parse($Request.Body.startDate).ToUniversalTime()
        }
        if ($Request.Body.endDate) {
            if ($Request.Body.endDate -match '^\d+$') {
                $QuarantineParams['EndReceivedDate'] = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Request.Body.endDate).UtcDateTime
            } else {
                $QuarantineParams['EndReceivedDate'] = [DateTime]::Parse($Request.Body.endDate).ToUniversalTime()
            }
        } else {
            $QuarantineParams['EndReceivedDate'] = (Get-Date).ToUniversalTime()
        }
    }
    if ($Request.Body.quarantineType) {
        $QuarantineParams['QuarantineTypes'] = $Request.Body.quarantineType
    }

    try {
        $QuarantineResults = @(New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams $QuarantineParams |
            Select-Object -ExcludeProperty *data.type*)

        if ($RecipientValue) {
            $QuarantineResults = $QuarantineResults | Where-Object { $_.RecipientAddress -like "*$RecipientValue*" }
        }
        if ($Request.Body.subject) {
            $QuarantineResults = $QuarantineResults | Where-Object { $_.Subject -like "*$($Request.Body.subject)*" }
        }
    } catch {
        $QuarantineError = "Quarantine search failed: $($_.Exception.Message)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $QuarantineError -Sev 'Error'
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
