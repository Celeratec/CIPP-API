function Set-CIPPContactPermission {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        $APIName = 'Set Contact Permissions',
        $Headers,
        $RemoveAccess,
        $TenantFilter,
        $UserID,
        $FolderName,
        $UserToGetPermissions,
        $LoggingName,
        $Permissions,
        [bool]$SendNotificationToUser = $false,
        [string]$AclUserName
    )

    try {
        if ([string]::IsNullOrWhiteSpace($LoggingName) -and $RemoveAccess) {
            $LoggingName = $RemoveAccess
        } elseif ([string]::IsNullOrWhiteSpace($LoggingName) -and $UserToGetPermissions) {
            $LoggingName = $UserToGetPermissions
        }

        $FolderMeta = Get-CIPPMailboxFolderIdentityCandidates -TenantFilter $TenantFilter -UserID $UserID -FolderName ($FolderName ?? 'Contacts') -FolderScope Contacts
        $FolderIdentities = $FolderMeta.Identities
        $FolderIdentity = $FolderIdentities | Select-Object -First 1

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

        if ($RemoveAccess) {
            if ($PSCmdlet.ShouldProcess("$UserID\$FolderName", "Remove permissions for $LoggingName")) {
                $Attempt = Invoke-CIPPMailboxFolderPermissionAttempt -Action Remove -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -AclUserNames @($AclUserName) -Anchor $UserID
                $Result = "Successfully removed access for $LoggingName from contact folder $($Attempt.UsedFolder)"
                if ($Attempt.UsedUser -and $Attempt.UsedUser -ne $RemoveAccess) {
                    $Result += " (resolved as $($Attempt.UsedUser))"
                }
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info
            }
        } else {
            if ($PSCmdlet.ShouldProcess("$UserID\$FolderName", "Set permissions for $LoggingName to $Permissions")) {
                try {
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Set -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser
                } catch {
                    $SetError = Get-CippException -Exception $_
                    if ($SetError.NormalizedError -match 'InvalidExternalUserIdException|Couldn.?t find user|not a valid Exchange recipient|isn.?t a valid user|not valid SMTP|no matching information') {
                        throw
                    }
                    $null = Invoke-CIPPMailboxFolderPermissionAttempt -Action Add -TenantFilter $TenantFilter -FolderIdentities $FolderIdentities -Candidates $MergedCandidates -Anchor $UserID -AccessRights @($Permissions) -SendNotificationToUser $SendNotificationToUser
                }

                $Result = "Successfully set permissions on contact folder $FolderIdentity. The user $LoggingName now has $Permissions permissions on this folder."

                if ($SendNotificationToUser) {
                    $Result += ' A notification has been sent to the user.'
                }

                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-Warning "Error changing contact permissions $($_.Exception.Message)"
        Write-Information $_.InvocationInfo.PositionMessage
        if ($ErrorMessage.NormalizedError -match 'InvalidExternalUserIdException') {
            $Result = "Failed to set contact permissions for $LoggingName on $UserID : The user '$LoggingName' is not a valid Exchange recipient. Ensure they have an Exchange Online mailbox or are a valid mail-enabled object."
        } elseif ($ErrorMessage.NormalizedError -match 'no existing permission entry|UserNotFoundInPermissionEntryException|Failed after trying identities|matches multiple entries') {
            $Result = "Failed to set contact permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError)"
        } else {
            $Result = "Failed to set contact permissions for $LoggingName on $UserID : $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error -LogData $ErrorMessage
        throw $Result
    }

    return $Result
}
