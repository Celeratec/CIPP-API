function Invoke-ExecMailboxSafeSender {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Adds a sender to a mailbox trusted/safe senders list via Set-MailboxJunkEmailConfiguration.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $Mailbox = Get-CippQuarantineInputValue $Request.Body.mailbox
    $Sender = Get-CippQuarantineInputValue $Request.Body.sender

    try {
        if ([string]::IsNullOrWhiteSpace($Mailbox)) { throw 'mailbox is required.' }
        if ([string]::IsNullOrWhiteSpace($Sender)) { throw 'sender is required.' }

        New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-MailboxJunkEmailConfiguration' -cmdParams @{
            Identity            = $Mailbox
            TrustedSendersToAdd = @($Sender)
            TrustedListsOnly    = $false
            ContactsTrusted     = $false
        }

        $Result = "Added $Sender to the safe senders list for $Mailbox."
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to add safe sender for $Mailbox`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
