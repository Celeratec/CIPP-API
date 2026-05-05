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

        # Keep this endpoint lean for Users page badges: only fields needed for IMAP/POP checks.
        $Select = 'PrimarySmtpAddress,ImapEnabled,PopEnabled'

        $ExoRequest = @{
            tenantid  = $TenantFilter
            cmdlet    = 'Get-CASMailbox'
            cmdParams = @{
                ResultSize = 'Unlimited'
            }
            Select    = $Select
        }

        $CASMailboxes = New-ExoRequest @ExoRequest |
            Where-Object { $_.ImapEnabled -or $_.PopEnabled } |
            Select-Object `
            @{ Name = 'userPrincipalName'; Expression = { $_.PrimarySmtpAddress } },
            @{ Name = 'ImapEnabled'; Expression = { $_.ImapEnabled } },
            @{ Name = 'PopEnabled'; Expression = { $_.PopEnabled } },
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
