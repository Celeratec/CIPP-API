Function Invoke-ExecTeamsVoicePhoneNumberAssignment {
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

    $Identity = $Request.Body.input.value

    $tenantFilter = $Request.Body.TenantFilter
    # Normalize phone number -- the + prefix can be lost during URL encoding (+ becomes space)
    $PhoneNumber = ($Request.Body.PhoneNumber -replace '^\s+', '') -replace '^ ', ''
    if ($PhoneNumber -and $PhoneNumber -notmatch '^\+') {
        $PhoneNumber = "+$PhoneNumber"
    }
    $PhoneNumberType = $Request.Body.PhoneNumberType

    try {
        if ($Request.Body.locationOnly) {
            $null = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsPhoneNumberAssignment' -CmdParams @{LocationId = $Identity; PhoneNumber = $PhoneNumber; ErrorAction = 'stop' }
            $Results = [pscustomobject]@{'Results' = "Successfully assigned emergency location to $($PhoneNumber)" }
        } else {
            $null = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsPhoneNumberAssignment' -CmdParams @{Identity = $Identity; PhoneNumber = $PhoneNumber; PhoneNumberType = $PhoneNumberType; ErrorAction = 'stop' }
            $Results = [pscustomobject]@{'Results' = "Successfully assigned $($PhoneNumber) to $($Identity)" }
        }
        Write-LogMessage -Headers $Headers -API $APINAME -tenant $($TenantFilter) -message $($Results.Results) -Sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $NormError = [string]$ErrorMessage.NormalizedError
        $RawError = [string]$ErrorMessage.Message
        $ErrorText = "Failed to assign $PhoneNumber to $Identity. $NormError"
        Write-LogMessage -Headers $Headers -API $APINAME -tenant $($TenantFilter) -message $ErrorText -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{
            Results  = $ErrorText
            RawError = $RawError
        }

        # --- Root Cause Analysis & Remediation ---
        try {
            $DiagList = [System.Collections.Generic.List[hashtable]]::new()

            # Pattern 1: Missing Capabilities
            if ($NormError -match 'does not have required capabilities' -or $RawError -match 'does not have required capabilities') {
                $TeamsAdminUrl = 'https://admin.teams.microsoft.com/phone-numbers'
                try {
                    $NumberInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsPhoneNumberAssignment' -CmdParams @{TelephoneNumber = $PhoneNumber; ErrorAction = 'Stop' }
                    $AcquiredCaps = if ($NumberInfo.AcquiredCapabilities) { ($NumberInfo.AcquiredCapabilities -join ', ') } else { 'None' }
                    $AvailableCaps = if ($NumberInfo.AvailableCapabilities) { ($NumberInfo.AvailableCapabilities -join ', ') } else { 'None' }
                    $NumberType = $NumberInfo.NumberType
                    $HasUserAssignment = $NumberInfo.AcquiredCapabilities -contains 'UserAssignment'
                    $UserAssignmentAvailable = $NumberInfo.AvailableCapabilities -contains 'UserAssignment'

                    if ($UserAssignmentAvailable -and -not $HasUserAssignment) {
                        $DetailMsg = "This phone number has 'UserAssignment' as an available capability but it has not been acquired. Acquired: $AcquiredCaps. The number type is '$NumberType'. To fix this, the number's usage type may need to be changed from its current type to 'User' in the Teams Admin Center."
                    } else {
                        $DetailMsg = "This phone number currently has acquired capabilities: $AcquiredCaps. Available capabilities: $AvailableCaps. The number type is '$NumberType'. It requires the 'UserAssignment' capability to be assigned to a user."
                    }

                    $DiagList.Add(@{
                        source       = 'Phone Number Capabilities'
                        issue        = 'Number lacks required capabilities for user assignment'
                        detail       = $DetailMsg
                        fix          = "Open the Teams Admin Center > Phone Numbers, find this number, and change its usage type to allow user assignment. If the number was provisioned for service use (auto attendant, call queue), it must be changed to a user number."
                        severity     = 'error'
                        canQuickFix  = $false
                        settingsPage = $TeamsAdminUrl
                        riskLevel    = $null
                        riskWarning  = $null
                    })
                } catch {
                    $DiagList.Add(@{
                        source       = 'Phone Number Capabilities'
                        issue        = 'Number lacks required capabilities for user assignment'
                        detail       = "The phone number does not have the required capabilities to be assigned to a user. The diagnostic lookup failed, so detailed capability information is not available."
                        fix          = "Open the Teams Admin Center > Phone Numbers, find this number, and verify its usage type supports user assignment."
                        severity     = 'error'
                        canQuickFix  = $false
                        settingsPage = $TeamsAdminUrl
                        riskLevel    = $null
                        riskWarning  = $null
                    })
                }
            }

            # Pattern 2: Number Already Assigned to Someone
            elseif ($NormError -match 'is already assigned' -or $RawError -match 'is already assigned') {
                $CurrentAssignee = $null
                $CurrentAssigneeDisplay = 'another user'
                try {
                    $NumberInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsPhoneNumberAssignment' -CmdParams @{TelephoneNumber = $PhoneNumber; ErrorAction = 'Stop' }
                    if ($NumberInfo.AssignedPstnTargetId) {
                        $CurrentAssignee = $NumberInfo.AssignedPstnTargetId
                        try {
                            $UserInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsOnlineUser' -CmdParams @{Identity = $NumberInfo.AssignedPstnTargetId; ErrorAction = 'Stop' }
                            $CurrentAssigneeDisplay = if ($UserInfo.DisplayName) { "$($UserInfo.DisplayName) ($($UserInfo.UserPrincipalName))" } else { $NumberInfo.AssignedPstnTargetId }
                        } catch {
                            $CurrentAssigneeDisplay = $NumberInfo.AssignedPstnTargetId
                        }
                    }
                } catch {
                    # Could not retrieve current assignment
                }
                $DiagList.Add(@{
                    source        = 'Phone Number Assignment'
                    issue         = "Phone number is already assigned to $CurrentAssigneeDisplay"
                    detail        = "The phone number $PhoneNumber is currently assigned to $CurrentAssigneeDisplay. A phone number can only be assigned to one user at a time."
                    fix           = "Unassign the phone number from the current user first, then retry the assignment."
                    severity      = 'warning'
                    canQuickFix   = $true
                    quickFixAction = 'unassignAndRetry'
                    quickFixData  = @{
                        currentAssignee        = $CurrentAssignee
                        currentAssigneeDisplay = $CurrentAssigneeDisplay
                        phoneNumber            = $PhoneNumber
                        phoneNumberType        = $PhoneNumberType
                    }
                    riskLevel     = 'high'
                    riskWarning   = "This will immediately remove phone service from $CurrentAssigneeDisplay. They will not be able to make or receive calls until a new number is assigned."
                    settingsPage  = $null
                })
            }

            # Pattern 3: User Already Has a Phone Number
            elseif ($NormError -match 'already has a phone number' -or $RawError -match 'already has a phone number' -or $NormError -match 'already has a number' -or $RawError -match 'already has a number') {
                $CurrentNumber = $null
                $CurrentNumberType = $null
                $UserDisplay = $Identity
                try {
                    $UserInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsOnlineUser' -CmdParams @{Identity = $Identity; ErrorAction = 'Stop' }
                    $CurrentNumber = $UserInfo.LineUri -replace 'tel:', ''
                    $CurrentNumberType = $UserInfo.FeatureTypes -join ', '
                    if ($UserInfo.DisplayName) { $UserDisplay = "$($UserInfo.DisplayName) ($Identity)" }
                } catch {
                    # Could not retrieve user info
                }
                $DiagList.Add(@{
                    source        = 'User Assignment'
                    issue         = "$UserDisplay already has a phone number assigned"
                    detail        = if ($CurrentNumber) { "$UserDisplay currently has phone number $CurrentNumber assigned. A user can only have one phone number at a time." } else { "$UserDisplay already has a phone number assigned. A user can only have one phone number at a time." }
                    fix           = "Remove the existing phone number from this user first, then assign the new number."
                    severity      = 'warning'
                    canQuickFix   = $true
                    quickFixAction = 'removeUserNumberAndRetry'
                    quickFixData  = @{
                        userIdentity    = $Identity
                        userDisplay     = $UserDisplay
                        currentNumber   = $CurrentNumber
                        currentNumberType = $CurrentNumberType
                        newNumber       = $PhoneNumber
                        newNumberType   = $PhoneNumberType
                    }
                    riskLevel     = 'high'
                    riskWarning   = if ($CurrentNumber) { "This will remove phone number $CurrentNumber from $UserDisplay. They will temporarily lose phone service until the new number ($PhoneNumber) is assigned." } else { "This will remove the current phone number from $UserDisplay. They will temporarily lose phone service until the new number is assigned." }
                    settingsPage  = $null
                })
            }

            # Pattern 4: User Not Licensed / Not Found / Not Enabled for Voice
            elseif ($NormError -match 'not a valid target' -or $NormError -match 'identity not found' -or $NormError -match 'not enabled for Enterprise Voice' -or $RawError -match 'not a valid target' -or $RawError -match 'identity not found' -or $RawError -match 'not enabled for Enterprise Voice' -or $NormError -match 'could not find user' -or $RawError -match 'could not find user') {
                $DiagList.Add(@{
                    source       = 'User Licensing'
                    issue        = 'User is not licensed for Teams Phone or not enabled for Enterprise Voice'
                    detail       = "The user $Identity does not have the required Teams Phone license or is not enabled for Enterprise Voice. Phone numbers can only be assigned to users with an active Teams Phone System license."
                    fix          = "Assign a Microsoft Teams Phone license (Teams Phone Standard, Calling Plan, or Operator Connect add-on) to this user in the Microsoft 365 Admin Center, then wait a few minutes for provisioning and retry."
                    severity     = 'error'
                    canQuickFix  = $false
                    settingsPage = $null
                    riskLevel    = $null
                    riskWarning  = $null
                })
            }

            # Pattern 5: Phone Number Type Mismatch
            elseif ($NormError -match 'not valid for the specified phone number type' -or $RawError -match 'not valid for the specified phone number type' -or $NormError -match 'phone number type' -or $RawError -match 'phone number type.*does not match') {
                $ActualType = $null
                try {
                    $NumberInfo = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsPhoneNumberAssignment' -CmdParams @{TelephoneNumber = $PhoneNumber; ErrorAction = 'Stop' }
                    $ActualType = $NumberInfo.NumberType
                } catch {
                    # Could not retrieve number info
                }
                $DiagList.Add(@{
                    source        = 'Phone Number Type'
                    issue         = if ($ActualType) { "Type mismatch: requested '$PhoneNumberType' but number is '$ActualType'" } else { "The phone number type does not match the number's actual type" }
                    detail        = if ($ActualType) { "The assignment was requested with type '$PhoneNumberType' but this number is actually of type '$ActualType'. The system will retry with the correct type." } else { "The phone number type specified does not match the number's actual type." }
                    fix           = 'The system can automatically retry with the correct phone number type.'
                    severity      = 'info'
                    canQuickFix   = $true
                    quickFixAction = 'retryWithCorrectType'
                    quickFixData  = @{
                        phoneNumber = $PhoneNumber
                        correctType = $ActualType
                        identity    = $Identity
                    }
                    riskLevel     = 'low'
                    riskWarning   = 'This will retry the assignment using the correct phone number type. No service will be disrupted.'
                    settingsPage  = $null
                })
            }

            if ($DiagList.Count -gt 0) {
                $Body.Diagnostics = @($DiagList)
            }
        } catch {
            Write-LogMessage -Headers $Headers -API $APINAME -tenant $TenantFilter -message "Voice assignment diagnostics failed: $($_.Exception.Message)" -Sev 'Debug'
        }

        $Results = [pscustomobject]$Body
    }
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Results
        })
}
