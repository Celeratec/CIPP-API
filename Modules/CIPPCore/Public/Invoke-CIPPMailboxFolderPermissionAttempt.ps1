function Invoke-CIPPMailboxFolderPermissionAttempt {
    <#
    .SYNOPSIS
        Run Remove/Set/Add-MailboxFolderPermission trying each resolved identity candidate.

    .DESCRIPTION
        Tries each identity candidate until one Exchange cmdlet succeeds. For Remove, also
        tries multiple folder Identity forms (name vs FolderId, GUID vs UPN) and matches
        live ACL entries using every key on the User object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Remove', 'Set', 'Add')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [string]$FolderIdentity,

        [Parameter(Mandatory = $false)]
        [string[]]$FolderIdentities,

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

    $FolderList = [System.Collections.Generic.List[string]]::new()
    foreach ($Value in @($FolderIdentities) + @($FolderIdentity)) {
        if ([string]::IsNullOrWhiteSpace($Value)) { continue }
        if (-not $FolderList.Contains($Value)) { $FolderList.Add($Value) }
    }
    if ($FolderList.Count -eq 0) {
        throw 'No folder identity available for mailbox folder permission operation'
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
        'ManagementObjectAmbiguousException'
        'matches multiple entries'
        'couldn.?t be performed'
    ) -join '|'

    $TriedFolders = [System.Collections.Generic.List[string]]::new()

    foreach ($ThisFolder in $FolderList) {
        $TriedFolders.Add($ThisFolder)
        Write-Information "Folder permission $Action trying folder identity '$ThisFolder'"

        foreach ($Candidate in $UniqueCandidates) {
            try {
                switch ($Action) {
                    'Remove' {
                        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams @{
                            Identity = $ThisFolder
                            User     = $Candidate
                        } -Anchor $Anchor
                    }
                    'Set' {
                        $CmdParams = @{
                            Identity               = $ThisFolder
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
                            Identity               = $ThisFolder
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
                    Success        = $true
                    UsedUser       = $Candidate
                    UsedFolder     = $ThisFolder
                    TriedUser      = @($UniqueCandidates)
                    TriedFolders   = @($TriedFolders)
                }
            } catch {
                $Normalized = (Get-CippException -Exception $_).NormalizedError
                $Retryable = $Normalized -match $RetryablePattern
                $LastError = $_
                if (-not $Retryable) {
                    throw
                }
                Write-Information "Folder permission $Action failed for candidate '$Candidate' on '$ThisFolder': $Normalized — trying next"
            }
        }

        # Remove fallback: match live ACL entries on this folder identity
        if ($Action -eq 'Remove') {
            try {
                $LivePermissions = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderPermission' -cmdParams @{
                    Identity = $ThisFolder
                } -Anchor $Anchor -UseSystemMailbox $true

                $CandidateSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($Candidate in $UniqueCandidates) { [void]$CandidateSet.Add($Candidate) }

                $AclTryList = [System.Collections.Generic.List[string]]::new()
                foreach ($Perm in @($LivePermissions)) {
                    $AclKeys = Get-CIPPFolderPermissionAclUserKeys -PermUser $Perm.User
                    $AclDisplay = $AclKeys | Select-Object -First 1
                    if (-not $AclDisplay -or $AclDisplay -in $SystemUsers) { continue }

                    $ShouldTry = $false
                    foreach ($AclKey in $AclKeys) {
                        if ($CandidateSet.Contains($AclKey)) { $ShouldTry = $true; break }
                    }

                    if (-not $ShouldTry) {
                        try {
                            $AclResolved = Resolve-CIPPFolderPermissionUser -User $AclDisplay -TenantFilter $TenantFilter
                            foreach ($AclCandidate in @($AclResolved.Candidates) + @($AclResolved.UserEmail) + @($AclResolved.UserId) + @($AclResolved.CandidateEmails) + $AclKeys) {
                                if ($AclCandidate -and $CandidateSet.Contains([string]$AclCandidate)) {
                                    $ShouldTry = $true
                                    break
                                }
                            }
                        } catch {
                            Write-Information "Could not resolve ACL user '$AclDisplay' for remove fallback: $($_.Exception.Message)"
                        }
                    }

                    if ($ShouldTry) {
                        foreach ($AclKey in $AclKeys) {
                            if ($AclKey -notin $SystemUsers -and -not $AclTryList.Contains($AclKey)) {
                                $AclTryList.Add($AclKey)
                            }
                        }
                    }
                }

                Write-Information "ACL fallback on '$ThisFolder' will try: $($AclTryList -join ', ')"
                foreach ($AclUser in $AclTryList) {
                    try {
                        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams @{
                            Identity = $ThisFolder
                            User     = $AclUser
                        } -Anchor $Anchor
                        return [PSCustomObject]@{
                            Success      = $true
                            UsedUser     = $AclUser
                            UsedFolder   = $ThisFolder
                            TriedUser    = @($UniqueCandidates) + @($AclTryList)
                            TriedFolders = @($TriedFolders)
                        }
                    } catch {
                        $Normalized = (Get-CippException -Exception $_).NormalizedError
                        $LastError = $_
                        if ($Normalized -notmatch $RetryablePattern) {
                            throw
                        }
                        Write-Information "ACL fallback remove failed for '$AclUser' on '$ThisFolder': $Normalized"
                    }
                }
            } catch {
                $LastError = $_
                Write-Information "ACL remove fallback failed on '$ThisFolder': $((Get-CippException -Exception $_).NormalizedError)"
            }
        }
    }

    $Tried = (@($UniqueCandidates) -join ', ')
    $FoldersTried = (@($TriedFolders) -join ', ')
    $Msg = if ($LastError) { (Get-CippException -Exception $LastError).NormalizedError } else { 'No matching permission entry could be removed' }
    throw "Failed after trying identities [$Tried] on folders [$FoldersTried]: $Msg"
}
