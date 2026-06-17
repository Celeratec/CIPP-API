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
    $AllowDomain = [boolean]$Request.Body.AllowDomain
    $BlockDomain = [boolean]$Request.Body.BlockDomain
    $ReportFalsePositive = [boolean]$Request.Body.ReportFalsePositive
    $ReleaseToUsers = @(
        ConvertTo-CippQuarantineStringArray $Request.Body.releaseToUsers |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $RecipientAddresses = @($Request.Body.RecipientAddress | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $UserRecipients = @(
        $RecipientAddresses |
            ForEach-Object { $_ -split '[,;]' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

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

    function Get-QuarantineActionResultMessage {
        param(
            $Entry,
            [string]$ActionType
        )

        $AllowBlockOnly = $ActionType -in @('AllowDomain', 'BlockDomain', 'AllowSenderOnly', 'BlockSenderOnly')
        if ($AllowBlockOnly) {
            if ($Entry.AllowEntryResult -eq 'Success') {
                return switch ($ActionType) {
                    'AllowDomain' { 'Sender domain added to the tenant allow list.' }
                    'BlockDomain' { 'Sender domain added to the tenant block list.' }
                    'AllowSenderOnly' { 'Sender added to the tenant allow list.' }
                    'BlockSenderOnly' { 'Sender added to the tenant block list.' }
                    default { 'Allow/block entry updated successfully.' }
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($Entry.AllowEntryResult)) {
                return $Entry.AllowEntryResult
            }
            if (-not [string]::IsNullOrWhiteSpace($Entry.ReleaseResult)) {
                return $Entry.ReleaseResult
            }
            return 'No result was returned for the allow/block action.'
        }

        if ($Entry.ReleaseResult -eq 'Success') {
            return 'Success'
        }
        return $Entry.ReleaseResult
    }

    foreach ($Id in $Identities) {
        $Entry = [PSCustomObject]@{
            Identity         = $Id
            ReleaseResult    = $null
            AllowEntryResult = $null
        }

        $InternetMessageIdPattern = '^(?:ID=)?<.+>$'

        $ActionVerb = switch -Wildcard ($ActionType) {
            'Release' { 'release' }
            'Deny'    { 'deny' }
            'Delete'  { 'delete' }
            default   { 'process' }
        }

        if ($ActionType -eq 'Delete') {
            try {
                Invoke-CippQuarantineExoRequest -TenantId $TenantFilter -Cmdlet 'Delete-QuarantineMessage' -CmdParams @{ Identity = $Id }
                $Entry.ReleaseResult = 'Success'
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Successfully deleted Quarantine ID $Id" -Sev 'Info'
            } catch {
                $Entry.ReleaseResult = Format-QuarantineError -Message $_.Exception.Message -Action 'delete' -IdentityValue $Id
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine delete failed for $Id`: $($_.Exception.Message)" -Sev 'Error' -LogData $_
            }
            $ResultsList.Add($Entry)
            continue
        }

        if ($ActionType -in @('AllowDomain', 'BlockDomain', 'AllowSenderOnly', 'BlockSenderOnly')) {
            try {
                $LookupId = $Id
                if ($Id -match $InternetMessageIdPattern) {
                    $LookupMessageId = $Id -replace '^ID=', ''
                    $QuarantineLookup = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ MessageId = $LookupMessageId }
                    $ResolvedQuarantine = @($QuarantineLookup) | Where-Object { $_.Identity } | Sort-Object -Property ReceivedTime -Descending | Select-Object -First 1
                    if ($ResolvedQuarantine) { $LookupId = $ResolvedQuarantine.Identity }
                }
                $QMsg = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ Identity = $LookupId }
                $SenderAddr = $QMsg.SenderAddress | Select-Object -First 1
                if (-not $SenderAddr) {
                    $Entry.AllowEntryResult = 'Sender address was not available for this quarantine entry.'
                } elseif ($ActionType -in @('AllowDomain', 'BlockDomain')) {
                    $DomainEntry = ($SenderAddr -split '@')[-1]
                    $DomainParams = @{
                        Entries  = @($DomainEntry)
                        ListType = 'Sender'
                        Notes    = if ($ActionType -eq 'AllowDomain') { 'Allowed domain via Quarantine Management' } else { 'Blocked domain via Quarantine Management' }
                    }
                    if ($ActionType -eq 'AllowDomain') {
                        $DomainParams.Allow = $true
                        $DomainParams.RemoveAfter = 45
                    } else {
                        $DomainParams.Block = $true
                        $DomainParams.NoExpiration = $true
                    }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TenantAllowBlockListItems' -cmdParams $DomainParams
                    $Entry.AllowEntryResult = 'Success'
                    $Entry.ReleaseResult = 'Success'
                } else {
                    $ListParams = @{
                        Entries  = @($SenderAddr)
                        ListType = 'Sender'
                        Notes    = if ($ActionType -eq 'AllowSenderOnly') { 'Allowed sender via Quarantine Management' } else { 'Blocked sender via Quarantine Management' }
                    }
                    if ($ActionType -eq 'AllowSenderOnly') {
                        $ListParams.Allow = $true
                        $ListParams.RemoveAfter = 45
                    } else {
                        $ListParams.Block = $true
                        $ListParams.NoExpiration = $true
                    }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TenantAllowBlockListItems' -cmdParams $ListParams
                    $Entry.AllowEntryResult = 'Success'
                    $Entry.ReleaseResult = 'Success'
                }
            } catch {
                $Entry.AllowEntryResult = "Failed: $(($_.Exception.Message -replace '^\|[^|]+\|', '').Trim())"
                $Entry.ReleaseResult = $Entry.AllowEntryResult
            }
            $ResultsList.Add($Entry)
            continue
        }

        # Release-QuarantineMessage requires the quarantine Identity (GUID-style),
        # not an InternetMessageId. When callers (e.g. the Email Troubleshooter
        # message trace) pass an InternetMessageId, resolve it to the quarantine
        # Identity via Get-QuarantineMessage first.
        $ResolvedId = $Id
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
                ActionType = $ActionType
                Identity   = $ResolvedId
            }
            if ($ReleaseToUsers.Count -gt 0 -and $ActionType -eq 'Release') {
                $ReleaseParams['User'] = $ReleaseToUsers
            } else {
                $ReleaseParams['ReleaseToAll'] = $true
            }
            if ($ActionType -eq 'Deny' -and $UserRecipients.Count -gt 0) {
                $ReleaseParams['User'] = $UserRecipients
            }
            if ($ReportFalsePositive -and $ActionType -eq 'Release') {
                $ReleaseParams['ReportFalsePositive'] = $true
            }
            Invoke-CippQuarantineExoRequest -TenantId $TenantFilter -Cmdlet 'Release-QuarantineMessage' -CmdParams $ReleaseParams
            $Entry.ReleaseResult = 'Success'
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Successfully processed Quarantine ID $ResolvedId" -Sev 'Info'
        } catch {
            $Entry.ReleaseResult = Format-QuarantineError -Message $_.Exception.Message -Action $ActionVerb -IdentityValue $ResolvedId
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine $ActionVerb failed for $ResolvedId`: $($_.Exception.Message)" -Sev 'Error' -LogData $_
        }

        if (($AllowEntry -or $AllowDomain -or $BlockDomain) -and $Entry.ReleaseResult -eq 'Success') {
            try {
                $QMsg = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ Identity = $ResolvedId }
                $SenderAddr = $QMsg.SenderAddress | Select-Object -First 1
                if ($SenderAddr) {
                    if ($AllowDomain -or $BlockDomain) {
                        $DomainEntry = ($SenderAddr -split '@')[-1]
                        if ($DomainEntry) {
                            $DomainParams = @{
                                Entries  = @($DomainEntry)
                                ListType = 'Sender'
                                Notes    = if ($AllowDomain) { 'Allowed domain via Quarantine Management' } else { 'Blocked domain via Quarantine Management' }
                            }
                            if ($AllowDomain) {
                                $DomainParams.Allow = $true
                                $DomainParams.RemoveAfter = 45
                            } else {
                                $DomainParams.Block = $true
                                $DomainParams.NoExpiration = $true
                            }
                            New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TenantAllowBlockListItems' -cmdParams $DomainParams
                            $Entry.AllowEntryResult = 'Success'
                        } else {
                            $Entry.AllowEntryResult = 'Processed, but could not determine sender domain for allow/block entry.'
                        }
                    } elseif ($AllowEntry) {
                        New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TenantAllowBlockListItems' -cmdParams @{
                            Entries     = @($SenderAddr)
                            ListType    = 'Sender'
                            Allow       = $true
                            RemoveAfter = 45
                            Notes       = 'Allowed via Quarantine Management'
                        }
                        $Entry.AllowEntryResult = 'Success'
                    }
                } else {
                    $Entry.AllowEntryResult = 'Processed, but the sender address was not available, so no allow/block entry was added.'
                }
            } catch {
                $Entry.AllowEntryResult = "Processed, but could not update the Tenant Allow/Block List: $(($_.Exception.Message -replace '^\|[^|]+\|', '').Trim())"
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Allow/block entry failed for $ResolvedId`: $($_.Exception.Message)" -Sev 'Error'
            }
        } elseif ($AllowEntry -or $AllowDomain -or $BlockDomain) {
            $Entry.AllowEntryResult = 'Skipped - the message was not released, so the sender was not added to the allow list.'
        }

        $ResultsList.Add($Entry)
    }

    $AllowBlockOnlyActions = @('AllowDomain', 'BlockDomain', 'AllowSenderOnly', 'BlockSenderOnly')
    $SuccessCount = @($ResultsList | Where-Object {
            ($_.ReleaseResult -eq 'Success') -or (
                $ActionType -in $AllowBlockOnlyActions -and $_.AllowEntryResult -eq 'Success'
            )
        }).Count
    $FailureCount = $ResultsList.Count - $SuccessCount
    $PastTense = switch -Wildcard ($ActionType) {
        'Release' { 'released' }
        'Deny'    { 'denied' }
        'Delete'  { 'deleted' }
        'AllowDomain' { 'allowed at domain level' }
        'BlockDomain' { 'blocked at domain level' }
        'AllowSenderOnly' { 'allowed at sender level' }
        'BlockSenderOnly' { 'blocked at sender level' }
        default   { 'processed' }
    }

    $Body = [pscustomobject]@{
        Results = if ($ResultsList.Count -eq 1) {
            $SingleResult = Get-QuarantineActionResultMessage -Entry $ResultsList[0] -ActionType $ActionType
            if ($SingleResult -eq 'Success') { "Message $PastTense successfully." }
            else { $SingleResult }
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
