function Disable-CIPPUserInboxRules {
    <#
    .SYNOPSIS
        Disable processable inbox rules for a user.

    .DESCRIPTION
        Used by BEC remediator as a background scheduled task so Exchange Online
        work does not run inside the SWA HTTP request (45s proxy limit).

    .PARAMETER Username
        User principal name of the mailbox.

    .PARAMETER TenantFilter
        Tenant default domain or customer ID.

    .PARAMETER APIName
        Calling API name for log attribution.

    .PARAMETER Headers
        Request headers for log attribution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        $APIName = 'Disable Inbox Rules',

        [Parameter(Mandatory = $false)]
        $Headers
    )

    $AllResults = [System.Collections.Generic.List[object]]::new()

    try {
        Write-LogMessage -headers $Headers -API $APIName -message "Starting inbox rules processing for user: $Username" -Sev 'Info' -tenant $TenantFilter
        $Rules = New-ExoRequest -anchor $Username -tenantid $TenantFilter -cmdlet 'Get-InboxRule' -cmdParams @{Mailbox = $Username; IncludeHidden = $true }
        Write-LogMessage -headers $Headers -API $APIName -message "Retrieved $(($Rules | Measure-Object).Count) total rules for $Username" -Sev 'Info' -tenant $TenantFilter
        $RuleDisabled = 0
        $RuleFailed = 0
        $DelegateRulesSkipped = 0
        $RuleMessages = [System.Collections.Generic.List[string]]::new()

        if (($Rules | Measure-Object).Count -eq 0) {
            $AllResults.Add([pscustomobject]@{
                    resultText = "No Inbox Rules found for $Username."
                    state      = 'info'
                })
        } else {
            $ProcessableRules = $Rules | Where-Object {
                $_.Name -ne 'Junk E-Mail Rule' -and
                $_.Name -notlike 'Microsoft.Exchange.OOF.*'
            }

            if (($ProcessableRules | Measure-Object).Count -eq 0) {
                $AllResults.Add([pscustomobject]@{
                        resultText = "Found $(($Rules | Measure-Object).Count) inbox rules for $Username, but none require disabling (only system rules found)."
                        state      = 'info'
                    })
            } else {
                $ProcessableRules | ForEach-Object {
                    $CurrentRule = $_
                    Write-LogMessage -headers $Headers -API $APIName -message "Processing rule: Name='$($CurrentRule.Name)', Identity='$($CurrentRule.Identity)'" -Sev 'Info' -tenant $TenantFilter

                    try {
                        Set-CIPPMailboxRule -Username $Username -UserId $Username -TenantFilter $TenantFilter -RuleId $CurrentRule.Identity -RuleName $CurrentRule.Name -Disable -APIName $APIName -Headers $Headers

                        Write-LogMessage -headers $Headers -API $APIName -message "Successfully disabled rule: $($CurrentRule.Name)" -Sev 'Info' -tenant $TenantFilter
                        $RuleDisabled++
                    } catch {
                        if ($CurrentRule.Name -match '^Delegate Rule -\d+$') {
                            Write-LogMessage -headers $Headers -API $APIName -message "Skipping delegate rule '$($CurrentRule.Name)' - unable to disable (expected behavior)" -Sev 'Info' -tenant $TenantFilter
                            $DelegateRulesSkipped++
                        } else {
                            $ErrorMsg = "Could not disable rule '$($CurrentRule.Name)': $($_.Exception.Message)"
                            Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev 'Error' -tenant $TenantFilter
                            $RuleMessages.Add($ErrorMsg)
                            $RuleFailed++
                        }
                    }
                }

                if ($RuleDisabled -gt 0) {
                    $AllResults.Add([pscustomobject]@{
                            resultText = "Successfully disabled $RuleDisabled inbox rules for $Username"
                            state      = 'success'
                        })
                } elseif ($DelegateRulesSkipped -gt 0 -and $RuleDisabled -eq 0 -and $RuleFailed -eq 0) {
                    $AllResults.Add([pscustomobject]@{
                            resultText = "No processable inbox rules found for $Username"
                            state      = 'info'
                        })
                }

                if ($RuleFailed -gt 0) {
                    $AllResults.Add([pscustomobject]@{
                            resultText = "Failed to process $RuleFailed inbox rules for $Username"
                            state      = 'warning'
                        })

                    foreach ($RuleMessage in $RuleMessages) {
                        $AllResults.Add([pscustomobject]@{
                                resultText = $RuleMessage
                                state      = 'error'
                            })
                    }
                }
            }
        }

        $TotalProcessed = $RuleDisabled + $RuleFailed + $DelegateRulesSkipped
        Write-LogMessage -headers $Headers -API $APIName -message "Completed inbox rules processing for $Username. Total rules: $(($Rules | Measure-Object).Count), Processed: $TotalProcessed, Disabled: $RuleDisabled, Failed: $RuleFailed, Delegate rules skipped: $DelegateRulesSkipped" -Sev 'Info' -tenant $TenantFilter
    } catch {
        $ErrorMsg = "Failed to process inbox rules: $($_.Exception.Message)"
        Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev 'Error' -tenant $TenantFilter
        $AllResults.Add([pscustomobject]@{
                resultText = $ErrorMsg
                state      = 'error'
            })
    }

    return $AllResults.ToArray()
}
