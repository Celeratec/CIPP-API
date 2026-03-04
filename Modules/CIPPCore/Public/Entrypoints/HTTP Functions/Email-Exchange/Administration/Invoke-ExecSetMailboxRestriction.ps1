function Invoke-ExecSetMailboxRestriction {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $TenantFilter = $Request.Body.tenantFilter
    $UserId = $Request.Body.UserId
    $Direction = $Request.Body.Direction
    $Enable = [bool]$Request.Body.Enable

    if (-not $TenantFilter -or -not $UserId -or -not $Direction) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter, UserId, and Direction are required' }
        })
    }

    $TransportRuleName = 'Manage365 - Block External Outbound'

    try {
        $ResultMessages = [System.Collections.ArrayList]::new()

        switch ($Direction) {
            'Inbound' {
                $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-Mailbox' -cmdParams @{
                    Identity                          = $UserId
                    RequireSenderAuthenticationEnabled = $Enable
                } -Anchor $UserId

                if ($Enable) {
                    $null = $ResultMessages.Add("Blocked external inbound mail for $UserId. External senders will receive a non-delivery report.")
                } else {
                    $null = $ResultMessages.Add("Allowed external inbound mail for $UserId.")
                }
            }
            'Outbound' {
                if ($Enable) {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-Mailbox' -cmdParams @{
                        Identity          = $UserId
                        CustomAttribute15 = 'BlockOutbound'
                    } -Anchor $UserId
                    $null = $ResultMessages.Add("Flagged $UserId for external outbound blocking.")

                    $AllRules = New-ExoRequest -ErrorAction SilentlyContinue -tenantid $TenantFilter -cmdlet 'Get-TransportRule' -useSystemMailbox $true
                    $ExistingRule = $AllRules | Where-Object -Property Identity -EQ $TransportRuleName

                    if (-not $ExistingRule) {
                        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TransportRule' -cmdParams @{
                            Name                            = $TransportRuleName
                            SenderADAttributeContainsWords  = @{
                                '@odata.type'    = '#Exchange.GenericHashTable'
                                CustomAttribute15 = 'BlockOutbound'
                            }
                            SentToScope                     = 'NotInOrganization'
                            RejectMessageReasonText         = 'This mailbox is restricted from sending to external recipients.'
                            RejectMessageEnhancedStatusCode = '5.7.1'
                            Comments                        = 'Auto-created by Manage365. Blocks external outbound for mailboxes with CustomAttribute15=BlockOutbound.'
                        } -useSystemMailbox $true
                        $null = $ResultMessages.Add("Created transport rule '$TransportRuleName' to enforce outbound restriction.")
                    }
                } else {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-Mailbox' -cmdParams @{
                        Identity          = $UserId
                        CustomAttribute15 = $null
                    } -Anchor $UserId
                    $null = $ResultMessages.Add("Allowed external outbound mail for $UserId.")
                }
            }
            default {
                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::BadRequest
                    Body       = @{ Results = "Direction must be 'Inbound' or 'Outbound'" }
                })
            }
        }

        $Results = $ResultMessages -join ' '
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results = "Failed to set mailbox restriction ($Direction) for $UserId. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Results }
    })
}
