function Set-CIPPCalendarPermission {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        $APIName = 'Set Calendar Permissions',
        $Headers,
        $RemoveAccess,
        $TenantFilter,
        $UserID,
        $FolderName,
        $UserToGetPermissions,
        $LoggingName,
        $Permissions,
        [bool]$CanViewPrivateItems,
        [bool]$SendNotificationToUser = $false,
        [switch]$AutoResolveFolderName,
        [string]$AclUserName
    )

    try {
        # If a pretty logging name is not provided, use the ID instead
        if ([string]::IsNullOrWhiteSpace($LoggingName) -and $RemoveAccess) {
            $LoggingName = $RemoveAccess
        } elseif ([string]::IsNullOrWhiteSpace($LoggingName) -and $UserToGetPermissions) {
            $LoggingName = $UserToGetPermissions
        }

        # Prefer locale-independent FolderId for removes — folder name mismatches leave ACEs unreachable
        if ($AutoResolveFolderName -or $RemoveAccess) {
            $CalFolderStats = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderStatistics' -cmdParams @{
                Identity    = $UserID
                FolderScope = 'Calendar'
            } -Anchor $UserID | Where-Object { $_.FolderType -eq 'Calendar' }
            $FolderIdentity = if ($CalFolderStats) { "$($UserID):$($CalFolderStats.FolderId)" } else { "$($UserID):\$FolderName" }
        } else {
            $FolderIdentity = "$($UserID):\$FolderName"
        }

        $TargetUser = if ($RemoveAccess) { $RemoveAccess } else { $UserToGetPermissions }
        $Resolved = Resolve-CIPPFolderPermissionUser -User $TargetUser -TenantFilter $TenantFilter
        if (-not [string]::IsNullOrWhiteSpace($AclUserName) -and $AclUserName -ne $TargetUser) {
            $AclResolved = Resolve-CIPPFolderPermissionUser -User $AclUserName -TenantFilter $TenantFilter
            $MergedCandidates = @($AclUserName) + @($Resolved.Candidates) + @($AclResolved.Candidates) | Select-Object -Unique
        } else {
            $MergedCandidates = @($Resolved.Candidates)
            if (-not [string]::IsNullOrWhiteSpace($AclUserName)) {
                $MergedCandidates = @($AclUserName) + $MergedCandidates | Select-Object -Unique
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($AclUserName) -and ($LoggingName -eq $TargetUser -or [string]::IsNullOrWhiteSpace($LoggingName))) {
            $LoggingName = $AclUserName
        } elseif (-not [string]::IsNullOrWhiteSpace($Resolved.UserEmail) -and [string]::IsNullOrWhiteSpace($LoggingName)) {
            $LoggingName = $Resolved.UserEmail
        } elseif ($Resolved.User -and ($LoggingName -eq $TargetUser)) {
            $LoggingName = $Resolved.User
        }

        $SharingFlags = $null
        if ($CanViewPrivateItems) {
            $SharingFlags = 'Delegate,CanViewPrivateItems'
        }

        if ($RemoveAccess) {
            if ($PSCmdlet.ShouldProcess("$UserID\$FolderName", "Remove permissions for $LoggingName")) {
                $Attempt = Invoke-CIPPMailboxFolderPermissionAttempt -Action Remove -TenantFilter $TenantFilter -FolderIdentity $FolderIdentity -Candidates $MergedCandidates -AclUserNames @($AclUserName) -Anchor $UserID
                $Result = "Successfully removed access for $LoggingName from calendar $($FolderIdentity)"
                if ($Attempt.UsedUser -and $Attempt.UsedUser -ne $RemoveAccess) {
                    $Result += " (resolved as $($Attempt.UsedUser))"
                }
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info

                # Sync cache — use original + resolved identities
                Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName $FolderName -User $RemoveAccess -Action 'Remove'
                if ($AclUserName) {
                    Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName $FolderName -User $AclUserName -Action 'Remove'
                }
                if ($Resolved.UserEmail -and $Resolved.UserEmail -ne $RemoveAccess) {
                    Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName $FolderName -User $Resolved.UserEmail -Action 'Remove'
                }
                if ($Resolved.User -and $Resolved.User -ne $RemoveAccess) {
                    Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName $FolderName -User $Resolved.User -Action 'Remove'
                }
            }
        } else {
            if ($PSCmdlet.ShouldProcess("$UserID\$FolderName", "Set permissions for $LoggingName to $Permissions")) {
                try {
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Set -TenantFilter $TenantFilter -FolderIdentity $FolderIdentity -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser -SharingPermissionFlags $SharingFlags
                } catch {
                    $SetError = Get-CippException -Exception $_
                    # Only fall through to Add when the entry is missing; do not Add after identity resolution failures
                    if ($SetError.NormalizedError -match 'InvalidExternalUserIdException|Couldn.?t find user|not a valid Exchange recipient|isn.?t a valid user|not valid SMTP|no matching information') {
                        throw
                    }
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Add -TenantFilter $TenantFilter -FolderIdentity $FolderIdentity -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser -SharingPermissionFlags $SharingFlags
                }

                $Result = "Successfully set permissions on folder $FolderIdentity. The user $LoggingName now has $Permissions permissions on this folder."
                if ($CanViewPrivateItems) {
                    $Result += ' The user can also view private items.'
                }
                if ($SendNotificationToUser) {
                    $Result += ' A notification has been sent to the user.'
                }
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info

                $CacheUser = $Resolved.UserEmail ?? $UserToGetPermissions
                Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName $FolderName -User $CacheUser -Permissions $Permissions -Action 'Add'
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-Warning "Error changing calendar permissions $($_.Exception.Message)"
        Write-Information $_.InvocationInfo.PositionMessage

        if ($ErrorMessage.NormalizedError -match 'InvalidExternalUserIdException') {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : The user '$LoggingName' is not a valid Exchange recipient. Ensure they have an Exchange Online mailbox or are a valid mail-enabled object."
        } elseif ($ErrorMessage.NormalizedError -match 'no existing permission entry|UserNotFoundInPermissionEntryException|Failed after trying identities') {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError) If the ACL still shows this person, the permission may be an orphaned Exchange entry that only matches the original display name — try again after refreshing, or remove via Outlook/MFCMAPI if it persists."
        } else {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError)"
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error -LogData $ErrorMessage
        throw $Result
    }

    return $Result
}
