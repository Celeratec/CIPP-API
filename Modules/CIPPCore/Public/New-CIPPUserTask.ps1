function New-CIPPUserTask {
    [CmdletBinding()]
    param (
        $UserObj,
        $APIName = 'New User Task',
        $TenantFilter,
        $Headers
    )
    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        $CreationResults = New-CIPPUser -UserObj $UserObj -APIName $APIName -Headers $Headers
        $Results.Add('Created New User.')
        $Results.Add("Username: $($CreationResults.Username)")
        $Results.Add("Password: $($CreationResults.Password)")
    } catch {
        $Results.Add("$($_.Exception.Message)" )
        throw @{'Results' = $Results }
    }

    try {
        if ($UserObj.licenses.value) {
            $LicenseResults = Set-CIPPUserLicense -UserId $CreationResults.Username -TenantFilter $UserObj.tenantFilter -AddLicenses $UserObj.licenses.value -Headers $Headers
                $Results.Add($LicenseResults)
        }
    } catch {
        Write-LogMessage -headers $Headers -API $APIName -tenant $($UserObj.tenantFilter) -message "Failed to assign the license. Error:$($_.Exception.Message)" -Sev 'Error'
        $Results.Add("Failed to assign the license. $($_.Exception.Message)")
    }

    try {
        if ($UserObj.AddedAliases) {
            $AliasResults = Add-CIPPAlias -User $CreationResults.Username -Aliases ($UserObj.AddedAliases -split '\s') -UserPrincipalName $CreationResults.Username -TenantFilter $UserObj.tenantFilter -APIName $APIName -Headers $Headers
            $Results.Add($AliasResults)
        }
    } catch {
        Write-LogMessage -headers $Headers -API $APIName -tenant $($UserObj.tenantFilter) -message "Failed to create the Aliases. Error:$($_.Exception.Message)" -Sev 'Error'
        $Results.Add("Failed to create the Aliases: $($_.Exception.Message)")
    }
    if ($UserObj.copyFrom.value) {
        Write-Host "Copying from $($UserObj.copyFrom.value)"
        $CopyFrom = Set-CIPPCopyGroupMembers -Headers $Headers -CopyFromId $UserObj.copyFrom.value -UserID $CreationResults.Username -TenantFilter $UserObj.tenantFilter
        $CopyFrom.Success | ForEach-Object { $Results.Add($_) }
        $CopyFrom.Error | ForEach-Object { $Results.Add($_) }
    }

    if ($UserObj.setManager) {
        $ManagerResult = Set-CIPPManager -User $CreationResults.Username -Manager $UserObj.setManager.value -TenantFilter $UserObj.tenantFilter -Headers $Headers
        $Results.Add($ManagerResult)
    }

    if ($UserObj.setSponsor) {
        $SponsorResult = Set-CIPPSponsor -User $CreationResults.Username -Sponsor $UserObj.setSponsor.value -TenantFilter $UserObj.tenantFilter -Headers $Headers
        $Results.Add($SponsorResult)
    }

    # Disable legacy protocols (IMAP/POP) if requested
    if ($UserObj.disableLegacyProtocols -eq $true) {
        try {
            # Schedule this for 5 minutes later to allow mailbox provisioning
            $taskObject = [PSCustomObject]@{
                TenantFilter  = $UserObj.tenantFilter
                Name          = "Disable Legacy Protocols: $($CreationResults.Username)"
                Command       = @{
                    value = 'Set-CIPPCASMailbox'
                }
                Parameters    = [pscustomobject]@{
                    Username     = $CreationResults.Username
                    TenantFilter = $UserObj.tenantFilter
                    ImapEnabled  = $false
                    PopEnabled   = $false
                }
                ScheduledTime = (Get-Date).AddMinutes(5).ToUniversalTime()
                PostExecution = @{
                    Webhook = $false
                    Email   = $false
                    PSA     = $false
                }
            }
            Add-CIPPScheduledTask -Task $taskObject -hidden $true -Headers $Headers
            $Results.Add('Scheduled task to disable IMAP and POP protocols (runs in 5 minutes to allow mailbox provisioning)')
            Write-LogMessage -headers $Headers -API $APIName -tenant $($UserObj.tenantFilter) -message "Scheduled task to disable legacy protocols for $($CreationResults.Username)" -Sev 'Info'
        } catch {
            Write-LogMessage -headers $Headers -API $APIName -tenant $($UserObj.tenantFilter) -message "Failed to schedule legacy protocol disable task. Error: $($_.Exception.Message)" -Sev 'Warning'
            $Results.Add("Note: Could not schedule legacy protocol disable task: $($_.Exception.Message)")
        }
    }

    return @{
        Results  = $Results
        Username = $CreationResults.Username
        Password = $CreationResults.Password
        CopyFrom = $CopyFrom
        User     = $CreationResults.User
    }
}
