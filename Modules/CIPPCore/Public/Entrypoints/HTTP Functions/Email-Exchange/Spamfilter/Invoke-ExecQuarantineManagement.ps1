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

    foreach ($Id in $Identities) {
        $Entry = [PSCustomObject]@{
            Identity         = $Id
            ReleaseResult    = $null
            AllowEntryResult = $null
        }

        try {
            $ReleaseParams = @{
                ReleaseToAll = $true
                ActionType   = $ActionType
                Identity     = $Id
            }
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Release-QuarantineMessage' -cmdParams $ReleaseParams
            $Entry.ReleaseResult = 'Success'
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Successfully processed Quarantine ID $Id" -Sev 'Info'
        } catch {
            $Entry.ReleaseResult = "Failed: $($_.Exception.Message)"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Quarantine release failed for $Id`: $($_.Exception.Message)" -Sev 'Error' -LogData $_
        }

        if ($AllowEntry -and $Entry.ReleaseResult -eq 'Success') {
            try {
                $QMsg = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-QuarantineMessage' -cmdParams @{ Identity = $Id }
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
                    $Entry.AllowEntryResult = 'Skipped: sender address not found'
                }
            } catch {
                $Entry.AllowEntryResult = "Failed: $($_.Exception.Message)"
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Allow entry failed for $Id`: $($_.Exception.Message)" -Sev 'Error'
            }
        } elseif ($AllowEntry) {
            $Entry.AllowEntryResult = 'Skipped: release failed'
        }

        $ResultsList.Add($Entry)
    }

    $SuccessCount = @($ResultsList | Where-Object { $_.ReleaseResult -eq 'Success' }).Count
    $Body = [pscustomobject]@{
        Results = if ($ResultsList.Count -eq 1) {
            if ($ResultsList[0].ReleaseResult -eq 'Success') { "Successfully processed $($Identities[0])" }
            else { $ResultsList[0].ReleaseResult }
        } else {
            "$SuccessCount of $($ResultsList.Count) messages processed successfully"
        }
        Details = @($ResultsList)
    }

    return ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
}
