Function Invoke-ExecRemoveTeamsVoicePhoneNumberAssignment {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Voice.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $TenantFilter = $Request.Body.tenantFilter
    $AssignedTo = $Request.Body.AssignedTo
    # Normalize phone number -- the + prefix can be lost during URL encoding (+ becomes space)
    $PhoneNumber = ($Request.Body.PhoneNumber -replace '^\s+', '') -replace '^ ', ''
    if ($PhoneNumber -and $PhoneNumber -notmatch '^\+') {
        $PhoneNumber = "+$PhoneNumber"
    }
    $PhoneNumberType = $Request.Body.PhoneNumberType

    try {
        $null = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Remove-CsPhoneNumberAssignment' -CmdParams @{Identity = $AssignedTo; PhoneNumber = $PhoneNumber; PhoneNumberType = $PhoneNumberType; ErrorAction = 'Stop' }
        $Result = "Successfully unassigned $PhoneNumber from $AssignedTo"
        Write-LogMessage -headers $Headers -API $APIName -tenant $($TenantFilter) -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $NormError = [string]$ErrorMessage.NormalizedError
        $RawError = [string]$ErrorMessage.Message
        $ErrorText = "Failed to unassign $PhoneNumber from $AssignedTo. $NormError"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ErrorText -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{
            Results  = $ErrorText
            RawError = $RawError
        }

        # --- Root Cause Analysis & Remediation ---
        try {
            $DiagList = [System.Collections.Generic.List[hashtable]]::new()

            # Pattern 1: Number Not Assigned
            if ($NormError -match 'is not assigned' -or $RawError -match 'is not assigned' -or $NormError -match 'not currently assigned' -or $RawError -match 'not currently assigned') {
                $DiagList.Add(@{
                    source       = 'Phone Number Assignment'
                    issue        = 'Phone number is not currently assigned'
                    detail       = "The phone number $PhoneNumber is not currently assigned to any user. It may have already been unassigned."
                    fix          = 'No action is needed. Refresh the page to see the current assignment state.'
                    severity     = 'info'
                    canQuickFix  = $false
                    settingsPage = $null
                    riskLevel    = $null
                    riskWarning  = $null
                })
            }

            # Pattern 2: Wrong User / Identity Mismatch
            elseif ($NormError -match 'does not match' -or $RawError -match 'does not match' -or $NormError -match 'not assigned to' -or $RawError -match 'not assigned to') {
                $ActualAssignee = $null
                $ActualAssigneeDisplay = 'a different user'
                try {
                    $NumberInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsPhoneNumberAssignment' -CmdParams @{TelephoneNumber = $PhoneNumber; ErrorAction = 'Stop' }
                    if ($NumberInfo.AssignedPstnTargetId) {
                        $ActualAssignee = $NumberInfo.AssignedPstnTargetId
                        try {
                            $UserInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsOnlineUser' -CmdParams @{Identity = $NumberInfo.AssignedPstnTargetId; ErrorAction = 'Stop' }
                            $ActualAssigneeDisplay = if ($UserInfo.DisplayName) { "$($UserInfo.DisplayName) ($($UserInfo.UserPrincipalName))" } else { $NumberInfo.AssignedPstnTargetId }
                        } catch {
                            $ActualAssigneeDisplay = $NumberInfo.AssignedPstnTargetId
                        }
                    }
                } catch {
                    # Could not retrieve current assignment
                }
                $DiagList.Add(@{
                    source        = 'Phone Number Assignment'
                    issue         = "Number is assigned to $ActualAssigneeDisplay, not $AssignedTo"
                    detail        = "The phone number $PhoneNumber is currently assigned to $ActualAssigneeDisplay, not to the requested user ($AssignedTo). The assignment data may be stale."
                    fix           = "Unassign the phone number from the correct user ($ActualAssigneeDisplay)."
                    severity      = 'warning'
                    canQuickFix   = $true
                    quickFixAction = 'unassignFromCorrectUser'
                    quickFixData  = @{
                        actualAssignee        = $ActualAssignee
                        actualAssigneeDisplay = $ActualAssigneeDisplay
                        phoneNumber           = $PhoneNumber
                        phoneNumberType       = $PhoneNumberType
                    }
                    riskLevel     = 'high'
                    riskWarning   = "This will remove phone service from $ActualAssigneeDisplay. They will not be able to make or receive calls until a new number is assigned."
                    settingsPage  = $null
                })
            }

            if ($DiagList.Count -gt 0) {
                $Body.Diagnostics = @($DiagList)
            }
        } catch {
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Voice unassignment diagnostics failed: $($_.Exception.Message)" -Sev 'Debug'
        }
    }
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
