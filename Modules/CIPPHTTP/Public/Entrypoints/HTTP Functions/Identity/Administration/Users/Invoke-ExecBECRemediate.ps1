function Invoke-ExecBECRemediate {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers


    $TenantFilter = $Request.Body.tenantFilter
    $SuspectUser = $Request.Body.userid
    $Username = $Request.Body.username
    # Prefer Entra object ID for Graph paths. UPNs with #EXT# break URL fragments.
    $GraphUserId = if ($SuspectUser) { $SuspectUser } else { $Username }
    Write-Host $TenantFilter
    Write-Host $SuspectUser

    $Results = try {
        $AllResults = [System.Collections.Generic.List[object]]::new()

        # Step 1: Reset Password
        $Step = 'Reset Password'
        try {
            $PasswordResult = Set-CIPPResetPassword -UserID $GraphUserId -tenantFilter $TenantFilter -APIName $APIName -Headers $Headers
            $AllResults.Add($PasswordResult)
        } catch {
            $AllResults.Add([pscustomobject]@{
                    resultText = "Failed to reset password: $($_.Exception.Message)"
                    state      = 'error'
                })
        }

        # Step 2: Disable Account
        $Step = 'Disable Account'
        try {
            $DisableResult = Set-CIPPSignInState -userid $GraphUserId -AccountEnabled $false -tenantFilter $TenantFilter -APIName $APIName -Headers $Headers
            $AllResults.Add([pscustomobject]@{
                    resultText = $DisableResult
                    state      = if ($DisableResult -like '*WARNING*') { 'warning' } else { 'success' }
                })
        } catch {
            $AllResults.Add([pscustomobject]@{
                    resultText = "Failed to disable account: $($_.Exception.Message)"
                    state      = 'error'
                })
        }

        # Step 3: Revoke Sessions
        $Step = 'Revoke Sessions'
        try {
            $SessionResult = Revoke-CIPPSessions -userid $GraphUserId -username $Username -Headers $Headers -APIName $APIName -tenantFilter $TenantFilter
            $AllResults.Add([pscustomobject]@{
                    resultText = $SessionResult
                    state      = if ($SessionResult -like '*Failed*') { 'error' } else { 'success' }
                })
        } catch {
            $AllResults.Add([pscustomobject]@{
                    resultText = "Failed to revoke sessions: $($_.Exception.Message)"
                    state      = 'error'
                })
        }

        # Step 4: Remove MFA methods
        $Step = 'Remove MFA methods'
        try {
            $MFAResult = Remove-CIPPUserMFA -UserPrincipalName $GraphUserId -TenantFilter $TenantFilter -Headers $Headers
            $AllResults.Add([pscustomobject]@{
                    resultText = $MFAResult
                    state      = if ($MFAResult -like '*No MFA methods*') { 'info' } elseif ($MFAResult -like '*Successfully*') { 'success' } else { 'error' }
                })
        } catch {
            $AllResults.Add([pscustomobject]@{
                    resultText = "Failed to remove MFA methods: $($_.Exception.Message)"
                    state      = 'error'
                })
        }

        # Step 5: Queue inbox-rule work. Get-InboxRule + per-rule Disable-InboxRule
        # regularly exceeds the Azure Static Web Apps ~45s proxy limit and returns
        # "Backend call failure" even though containment already succeeded.
        $Step = 'Queue Inbox Rules'
        try {
            $TaskResult = Add-CIPPScheduledTask -RunNow -Headers $Headers -Task ([PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Name         = "BEC Remediate inbox rules: $Username"
                    Command      = @{ value = 'Disable-CIPPUserInboxRules' }
                    Parameters   = [pscustomobject]@{
                        Username = $Username
                        APIName  = $APIName
                    }
                })
            $AllResults.Add([pscustomobject]@{
                    resultText = "Inbox rules for $Username queued for background processing. $TaskResult"
                    state      = 'info'
                })
        } catch {
            $AllResults.Add([pscustomobject]@{
                    resultText = "Failed to queue inbox rule processing: $($_.Exception.Message)"
                    state      = 'error'
                })
        }

        $StatusCode = [HttpStatusCode]::OK
        Write-LogMessage -API 'BECRemediate' -tenant $TenantFilter -message "Executed Remediation for $Username" -sev 'Info' -LogData @($AllResults)

        # Return the results array
        $AllResults.ToArray()

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorList = [System.Collections.Generic.List[object]]::new()
        $ErrorList.Add([pscustomobject]@{
                resultText = "Failed to execute remediation at step '$Step'. $($ErrorMessage.NormalizedError)"
                state      = 'error'
            })
        Write-LogMessage -API 'BECRemediate' -tenant $TenantFilter -message "Executed Remediation for $Username failed at the $Step step" -sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError

        # Return the error array
        $ErrorList.ToArray()
    }

    # Create the final response structure
    $ResponseBody = [pscustomobject]@{'Results' = @($Results) }

    # Associate values to output bindings
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $ResponseBody
        })

}
