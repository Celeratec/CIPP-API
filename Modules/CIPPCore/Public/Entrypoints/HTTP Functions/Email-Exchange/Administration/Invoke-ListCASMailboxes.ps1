function Invoke-ListCASMailboxes {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter

    try {
        $APIName = $Request.Params.CIPPEndpoint
        Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

        # Get CAS mailbox settings for all mailboxes
        $Select = 'Identity,PrimarySmtpAddress,ImapEnabled,PopEnabled,EwsEnabled,MAPIEnabled,OWAEnabled,ActiveSyncEnabled'

        $ExoRequest = @{
            tenantid  = $TenantFilter
            cmdlet    = 'Get-CASMailbox'
            cmdParams = @{
                ResultSize = 'Unlimited'
            }
            Select    = $Select
        }

        $CASMailboxes = New-ExoRequest @ExoRequest | Select-Object `
            @{ Name = 'userPrincipalName'; Expression = { $_.PrimarySmtpAddress } },
            @{ Name = 'ImapEnabled'; Expression = { $_.ImapEnabled } },
            @{ Name = 'PopEnabled'; Expression = { $_.PopEnabled } },
            @{ Name = 'EwsEnabled'; Expression = { $_.EwsEnabled } },
            @{ Name = 'MAPIEnabled'; Expression = { $_.MAPIEnabled } },
            @{ Name = 'OWAEnabled'; Expression = { $_.OWAEnabled } },
            @{ Name = 'ActiveSyncEnabled'; Expression = { $_.ActiveSyncEnabled } },
            @{ Name = 'LegacyProtocolsEnabled'; Expression = { $_.ImapEnabled -or $_.PopEnabled } }

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = @($CASMailboxes) }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Request.Headers -API $APINAME -message "Failed to get CAS mailboxes: $ErrorMessage" -Sev 'Error' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = @{ Results = @(); Error = $ErrorMessage }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
