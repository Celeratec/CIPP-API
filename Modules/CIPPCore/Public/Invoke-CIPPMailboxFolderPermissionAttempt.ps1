function Invoke-CIPPMailboxFolderPermissionAttempt {
    <#
    .SYNOPSIS
        Run Remove/Set/Add-MailboxFolderPermission trying each resolved identity candidate.

    .DESCRIPTION
        Used when folder permission User values are display names that may collide.
        Tries each candidate until one Exchange cmdlet succeeds. For Remove, falls back to
        matching live Get-MailboxFolderPermission ACL entries and removing by the exact
        ACL User string (often the only form Exchange accepts).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Remove', 'Set', 'Add')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$FolderIdentity,

        [Parameter(Mandatory = $true)]
        [string[]]$Candidates,

        [Parameter(Mandatory = $false)]
        $Anchor,

        [Parameter(Mandatory = $false)]
        [string[]]$AccessRights,

        [Parameter(Mandatory = $false)]
        [bool]$SendNotificationToUser = $false,

        [Parameter(Mandatory = $false)]
        [string]$SharingPermissionFlags,

        [Parameter(Mandatory = $false)]
        [string[]]$AclUserNames
    )

    $LastError = $null
    $SystemUsers = @('Default', 'Anonymous', 'NT AUTHORITY\SELF')
    $UniqueCandidates = [System.Collections.Generic.List[string]]::new()
    foreach ($Value in @($AclUserNames) + @($Candidates)) {
        if ([string]::IsNullOrWhiteSpace($Value)) { continue }
        if (-not $UniqueCandidates.Contains($Value)) {
            $UniqueCandidates.Add($Value)
        }
    }

    if ($UniqueCandidates.Count -eq 0) {
        throw 'No identity candidates available for mailbox folder permission operation'
    }

    $RetryablePattern = @(
        'UserNotFoundInPermissionEntryException'
        'InvalidExternalUserIdException'
        'Couldn.?t find user'
        'couldn.?t be found'
        'no existing permission entry'
        'not valid SMTP'
        'no matching information'
        'isn.?t a valid'
        'is not a valid'
        'Cannot find recipient'
        'couldn.?t resolve'
        'could not be found'
        'doesn.?t exist'
    ) -join '|'

    foreach ($Candidate in $UniqueCandidates) {
        try {
            switch ($Action) {
                'Remove' {
                    $CmdParams = @{
                        Identity = $FolderIdentity
                        User     = $Candidate
                    }
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams $CmdParams -Anchor $Anchor
                }
                'Set' {
                    $CmdParams = @{
                        Identity               = $FolderIdentity
                        User                   = $Candidate
                        AccessRights           = @($AccessRights)
                        SendNotificationToUser = $SendNotificationToUser
                    }
                    if ($SharingPermissionFlags) {
                        $CmdParams['SharingPermissionFlags'] = $SharingPermissionFlags
                    }
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-MailboxFolderPermission' -cmdParams $CmdParams -Anchor $Anchor
                }
                'Add' {
                    $CmdParams = @{
                        Identity               = $FolderIdentity
                        User                   = $Candidate
                        AccessRights           = @($AccessRights)
                        SendNotificationToUser = $SendNotificationToUser
                    }
                    if ($SharingPermissionFlags) {
                        $CmdParams['SharingPermissionFlags'] = $SharingPermissionFlags
                    }
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Add-MailboxFolderPermission' -cmdParams $CmdParams -Anchor $Anchor
                }
            }
            return [PSCustomObject]@{
                Success   = $true
                UsedUser  = $Candidate
                TriedUser = @($UniqueCandidates)
            }
        } catch {
            $Normalized = (Get-CippException -Exception $_).NormalizedError
            $Retryable = $Normalized -match $RetryablePattern
            $LastError = $_
            if (-not $Retryable) {
                throw
            }
            Write-Information "Folder permission $Action failed for candidate '$Candidate': $Normalized — trying next identity"
        }
    }

    # Remove fallback: match live ACL entries and remove using the exact ACL User string.
    # Exchange frequently stores ACE principals as display names that don't reverse-map from SMTP/GUID.
    if ($Action -eq 'Remove') {
        try {
            $LivePermissions = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderPermission' -cmdParams @{
                Identity = $FolderIdentity
            } -Anchor $Anchor -UseSystemMailbox $true

            $CandidateSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($Candidate in $UniqueCandidates) { [void]$CandidateSet.Add($Candidate) }

            $AclTryList = [System.Collections.Generic.List[string]]::new()
            foreach ($Perm in @($LivePermissions)) {
                $AclUser = if ($Perm.User -is [string]) { $Perm.User } else { [string]($Perm.User.DisplayName ?? $Perm.User.UserId ?? $Perm.User) }
                if ([string]::IsNullOrWhiteSpace($AclUser) -or $AclUser -in $SystemUsers) { continue }

                $ShouldTry = $false
                if ($CandidateSet.Contains($AclUser)) {
                    $ShouldTry = $true
                } else {
                    try {
                        $AclResolved = Resolve-CIPPFolderPermissionUser -User $AclUser -TenantFilter $TenantFilter
                        foreach ($AclCandidate in @($AclResolved.Candidates) + @($AclResolved.UserEmail) + @($AclResolved.UserId) + @($AclResolved.CandidateEmails)) {
                            if ($AclCandidate -and $CandidateSet.Contains([string]$AclCandidate)) {
                                $ShouldTry = $true
                                break
                            }
                        }
                    } catch {
                        Write-Information "Could not resolve ACL user '$AclUser' for remove fallback: $($_.Exception.Message)"
                    }
                }

                if ($ShouldTry -and -not $AclTryList.Contains($AclUser)) {
                    $AclTryList.Add($AclUser)
                }
            }

            foreach ($AclUser in $AclTryList) {
                try {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams @{
                        Identity = $FolderIdentity
                        User     = $AclUser
                    } -Anchor $Anchor
                    return [PSCustomObject]@{
                        Success   = $true
                        UsedUser  = $AclUser
                        TriedUser = @($UniqueCandidates) + @($AclTryList)
                    }
                } catch {
                    $Normalized = (Get-CippException -Exception $_).NormalizedError
                    $LastError = $_
                    if ($Normalized -notmatch $RetryablePattern) {
                        throw
                    }
                    Write-Information "ACL fallback remove failed for '$AclUser': $Normalized"
                }
            }
        } catch {
            $LastError = $_
            Write-Information "ACL remove fallback failed: $((Get-CippException -Exception $_).NormalizedError)"
        }
    }

    $Tried = (@($UniqueCandidates) -join ', ')
    $Msg = if ($LastError) { (Get-CippException -Exception $LastError).NormalizedError } else { 'No matching permission entry could be removed' }
    throw "Failed after trying identities [$Tried]: $Msg"
}
