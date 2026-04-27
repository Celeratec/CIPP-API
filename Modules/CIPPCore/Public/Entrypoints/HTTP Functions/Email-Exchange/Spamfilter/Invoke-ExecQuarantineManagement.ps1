function Invoke-ExecQuarantineManagement {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $ActionType = $Request.Body.Type | Select-Object -First 1
    # Both AllowSender and AddAllowEntry are routed through the Tenant Allow/Block List
    # because Release-QuarantineMessage -AllowSender chains to Get-HostedContentFilterPolicy
    # on Microsoft's backend, which intermittently fails with a CommandNotFoundException.
    $AllowEntry = [boolean]$Request.Body.AllowSender -or [boolean]$Request.Body.AddAllowEntry

    $Identities = if ($Request.Body.Identity -is [string]) {
        @($Request.Body.Identity)
    } else {
        @($Request.Body.Identity)
    }

    $ResultsList = [System.Collections.Generic.List[object]]::new()

    # Translate common Exchange exceptions into messages a non-Exchange admin can act on.
    function Format-QuarantineError {
        param(
            [string]$Message,
            [string]$Action = 'process',
            [string]$IdentityValue
        )
        $Clean = ($Message -replace '^\|[^|]+\|', '').Trim()
        switch -Wildcard ($Clean) {
            '*is not valid. Please input a valid message identity*' {
                return "Could not $Action this message. The quarantine entry could not be found - it may have already been released, denied, expired (quarantined items are typically retained 15-30 days), or purged. Refresh the quarantine list and try again."
            }
            '*Cannot find an object with identity*' {
                return "Could not $Action this message. The quarantine entry no longer exists. Refresh the quarantine list and try again."
            }
            '*release request*already*' {
                return 'A release request for this message has already been submitted and is awaiting administrator review.'
            }
            '*already*released*' {
                return 'This message has already been released from quarantine.'
            }
            '*already*denied*' {
                return 'This message has already been denied.'
            }
            '*has expired*' {
                return 'This message has expired from quarantine and can no longer be released. The default retention is 15-30 days depending on the policy.'
            }
            { $_ -like '*not authorized*' -or $_ -like '*Access*denied*' -or $_ -like '*Unauthorized*' } {
                return "You are not authorized to $Action quarantined messages for this tenant. Confirm the SAM user has the Exchange.SpamFilter.ReadWrite role and that GDAP grants the Security Administrator (or equivalent) role."
            }
            default {
                return "Failed to $Action the message: $Clean"
            }
        }
    }

    foreach ($Id in $Identities) {
        $Entry = [PSCustomObject]@{
            Identity         = $Id
            ReleaseResult    = $null
            AllowEntryResult = $null
        }

        $ActionVerb = switch -Wildcard ($ActionType) {
            'Release' { 'release' }
            'Deny'    { 'deny' }
            default   { 'process' }
        }

        # Release-QuarantineMessage requires the quarantine Identity (GUID-style),
        # not an InternetMessageId. When callers (e.g. the Email Troubleshooter
        # message trace) pass an InternetMessageId, resolve it to the quarantine
        # Identity via Get-QuarantineMessage first.
        $ResolvedId = $Id
        $InternetMessageIdPattern = '^(?:ID=)?<.+>$'
        if ($Id -match $InternetMessageIdPattern) {
            $LookupMessageId = $Id -replace '^ID=', ''
            try {
                $QuarantineLookup = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ MessageId = $LookupMessageId }
                $ResolvedQuarantine = @($QuarantineLookup) | Where-Object { $_.Identity } | Sort-Object -Property ReceivedTime -Descending | Select-Object -First 1
                if ($ResolvedQuarantine) {
                    $ResolvedId = $ResolvedQuarantine.Identity
                } else {
                    $Entry.ReleaseResult = "This message is not currently in quarantine - it may have been released, denied, or expired already. Open Quarantine Management to confirm its status."
                    Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine release failed: no quarantine entry for MessageId $LookupMessageId" -Sev 'Error'
                    $ResultsList.Add($Entry)
                    continue
                }
            } catch {
                $Entry.ReleaseResult = Format-QuarantineError -Message $_.Exception.Message -Action 'look up' -IdentityValue $LookupMessageId
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine identity lookup failed for $LookupMessageId`: $($_.Exception.Message)" -Sev 'Error' -LogData $_
                $ResultsList.Add($Entry)
                continue
            }
        }

        try {
            $ReleaseParams = @{
                ReleaseToAll = $true
                ActionType   = $ActionType
                Identity     = $ResolvedId
            }
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Release-QuarantineMessage' -cmdParams $ReleaseParams
            $Entry.ReleaseResult = 'Success'
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Successfully processed Quarantine ID $ResolvedId" -Sev 'Info'
        } catch {
            $Entry.ReleaseResult = Format-QuarantineError -Message $_.Exception.Message -Action $ActionVerb -IdentityValue $ResolvedId
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine $ActionVerb failed for $ResolvedId`: $($_.Exception.Message)" -Sev 'Error' -LogData $_
        }

        if ($AllowEntry -and $Entry.ReleaseResult -eq 'Success') {
            try {
                $QMsg = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ Identity = $ResolvedId }
                $SenderAddr = $QMsg.SenderAddress | Select-Object -First 1
                if ($SenderAddr) {
                    New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TenantAllowBlockListItems' -cmdParams @{
                        Entries     = @($SenderAddr)
                        ListType    = 'Sender'
                        Allow       = $true
                        RemoveAfter = 45
                        Notes       = 'Allowed via Email Troubleshooter - Quarantine release'
                    }
                    $Entry.AllowEntryResult = 'Success'
                } else {
                    $Entry.AllowEntryResult = 'Released, but the sender address was not available, so no allow entry was added.'
                }
            } catch {
                $Entry.AllowEntryResult = "Released, but could not add the sender to the Tenant Allow/Block List: $(($_.Exception.Message -replace '^\|[^|]+\|', '').Trim())"
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Allow entry failed for $ResolvedId`: $($_.Exception.Message)" -Sev 'Error'
            }
        } elseif ($AllowEntry) {
            $Entry.AllowEntryResult = 'Skipped - the message was not released, so the sender was not added to the allow list.'
        }

        $ResultsList.Add($Entry)
    }

    $SuccessCount = @($ResultsList | Where-Object { $_.ReleaseResult -eq 'Success' }).Count
    $FailureCount = $ResultsList.Count - $SuccessCount
    $PastTense = switch -Wildcard ($ActionType) {
        'Release' { 'released' }
        'Deny'    { 'denied' }
        default   { 'processed' }
    }

    $Body = [pscustomobject]@{
        Results = if ($ResultsList.Count -eq 1) {
            if ($ResultsList[0].ReleaseResult -eq 'Success') { "Message $PastTense successfully." }
            else { $ResultsList[0].ReleaseResult }
        } elseif ($FailureCount -eq 0) {
            "All $($ResultsList.Count) messages $PastTense successfully."
        } elseif ($SuccessCount -eq 0) {
            "Failed to $($ActionType.ToLower()) any of the $($ResultsList.Count) messages. See details below."
        } else {
            "$SuccessCount of $($ResultsList.Count) messages $PastTense successfully ($FailureCount failed). See details below."
        }
        Details = @($ResultsList)
    }

    return ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
}
