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
    $Enable = ($Request.Body.Enable -eq $true)

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
                $AllRules = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-TransportRule' -useSystemMailbox $true
                $ExistingRule = $AllRules | Where-Object -Property Identity -EQ $TransportRuleName

                if ($Enable) {
                    if (-not $ExistingRule) {
                        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-TransportRule' -cmdParams @{
                            Name                            = $TransportRuleName
                            From                            = @($UserId)
                            SentToScope                     = 'NotInOrganization'
                            RejectMessageReasonText         = 'This mailbox is restricted from sending to external recipients.'
                            RejectMessageEnhancedStatusCode = '5.7.1'
                            Comments                        = 'Auto-created by Manage365. Blocks external outbound for listed senders.'
                        } -useSystemMailbox $true
                        $null = $ResultMessages.Add("Created transport rule and blocked external outbound mail for $UserId.")
                    } else {
                        $CurrentFrom = @($ExistingRule.From | ForEach-Object { $_ })
                        if ($UserId -notin $CurrentFrom) {
                            $UpdatedFrom = @($CurrentFrom) + @($UserId)
                            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-TransportRule' -cmdParams @{
                                Identity = $TransportRuleName
                                From     = $UpdatedFrom
                            } -useSystemMailbox $true
                        }
                        $null = $ResultMessages.Add("Blocked external outbound mail for $UserId.")
                    }
                } else {
                    if ($ExistingRule) {
                        $CurrentFrom = @($ExistingRule.From | ForEach-Object { $_ })
                        $UpdatedFrom = @($CurrentFrom | Where-Object { $_ -ne $UserId })

                        if ($UpdatedFrom.Count -eq 0) {
                            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-TransportRule' -cmdParams @{
                                Identity = $TransportRuleName
                                Confirm  = $false
                            } -useSystemMailbox $true
                            $null = $ResultMessages.Add("Allowed external outbound mail for $UserId. Transport rule removed (no remaining blocked senders).")
                        } else {
                            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-TransportRule' -cmdParams @{
                                Identity = $TransportRuleName
                                From     = $UpdatedFrom
                            } -useSystemMailbox $true
                            $null = $ResultMessages.Add("Allowed external outbound mail for $UserId.")
                        }
                    } else {
                        $null = $ResultMessages.Add("External outbound mail is already allowed for $UserId.")
                    }
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
