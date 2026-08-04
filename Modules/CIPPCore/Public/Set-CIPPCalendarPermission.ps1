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
        if ([string]::IsNullOrWhiteSpace($LoggingName) -and $RemoveAccess) {
            $LoggingName = $RemoveAccess
        } elseif ([string]::IsNullOrWhiteSpace($LoggingName) -and $UserToGetPermissions) {
            $LoggingName = $UserToGetPermissions
        }

        $FolderMeta = Get-CIPPMailboxFolderIdentityCandidates -TenantFilter $TenantFilter -UserID $UserID -FolderName ($FolderName ?? 'Calendar') -FolderScope Calendar
        $FolderIdentities = $FolderMeta.Identities
        $FolderIdentity = $FolderIdentities | Select-Object -First 1

        $TargetUser = if ($RemoveAccess) { $RemoveAccess } else { $UserToGetPermissions }
        $Resolved = Resolve-CIPPFolderPermissionUser -User $TargetUser -TenantFilter $TenantFilter
        # Keep remove candidate list short to stay under UI timeout
        if ($RemoveAccess) {
            $MergedCandidates = @(
                $AclUserName
                $RemoveAccess
                $Resolved.UserEmail
                $Resolved.UserId
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
            if ($MergedCandidates.Count -eq 0) {
                $MergedCandidates = @($Resolved.Candidates | Select-Object -First 4)
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($AclUserName) -and $AclUserName -ne $TargetUser) {
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
                $Attempt = Invoke-CIPPMailboxFolderPermissionAttempt -Action Remove -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -AclUserNames @($AclUserName) -Anchor $UserID
                $Result = "Successfully removed access for $LoggingName from calendar $($Attempt.UsedFolder)"
                if ($Attempt.UsedUser -and $Attempt.UsedUser -ne $RemoveAccess) {
                    $Result += " (resolved as $($Attempt.UsedUser))"
                }
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info

                Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName ($FolderMeta.FolderName ?? $FolderName) -User $RemoveAccess -Action 'Remove'
                if ($AclUserName) {
                    Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName ($FolderMeta.FolderName ?? $FolderName) -User $AclUserName -Action 'Remove'
                }
                if ($Resolved.UserEmail -and $Resolved.UserEmail -ne $RemoveAccess) {
                    Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName ($FolderMeta.FolderName ?? $FolderName) -User $Resolved.UserEmail -Action 'Remove'
                }
            }
        } else {
            if ($PSCmdlet.ShouldProcess("$UserID\$FolderName", "Set permissions for $LoggingName to $Permissions")) {
                try {
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Set -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser -SharingPermissionFlags $SharingFlags
                } catch {
                    $SetError = Get-CippException -Exception $_
                    if ($SetError.NormalizedError -match 'InvalidExternalUserIdException|Couldn.?t find user|not a valid Exchange recipient|isn.?t a valid user|not valid SMTP|no matching information') {
                        throw
                    }
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Add -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser -SharingPermissionFlags $SharingFlags
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
                Sync-CIPPCalendarPermissionCache -TenantFilter $TenantFilter -MailboxIdentity $UserID -FolderName ($FolderMeta.FolderName ?? $FolderName) -User $CacheUser -Permissions $Permissions -Action 'Add'
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-Warning "Error changing calendar permissions $($_.Exception.Message)"
        Write-Information $_.InvocationInfo.PositionMessage

        if ($ErrorMessage.NormalizedError -match 'InvalidExternalUserIdException') {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : The user '$LoggingName' is not a valid Exchange recipient. Ensure they have an Exchange Online mailbox or are a valid mail-enabled object."
        } elseif ($ErrorMessage.NormalizedError -match 'no existing permission entry|UserNotFoundInPermissionEntryException|Failed after trying identities|matches multiple entries') {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError)"
        } else {
            $Result = "Failed to set calendar permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError)"
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error -LogData $ErrorMessage
        throw $Result
    }

    return $Result
}
