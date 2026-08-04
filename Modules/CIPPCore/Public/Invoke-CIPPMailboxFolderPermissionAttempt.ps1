function Invoke-CIPPMailboxFolderPermissionAttempt {
    <#
    .SYNOPSIS
        Run Remove/Set/Add-MailboxFolderPermission trying each resolved identity candidate.

    .DESCRIPTION
        Optimized for Azure Function / UI timeouts. Remove is ACL-first: load live permissions
        once per folder, remove matching ACE keys, then try a short candidate list.
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
    $UniqueCandidates = @(
        @($AclUserNames) + @($Candidates) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    if ($UniqueCandidates.Count -gt 8) {
        $UniqueCandidates = @($UniqueCandidates | Select-Object -First 8)
    }
    if ($UniqueCandidates.Count -eq 0) {
        throw 'No identity candidates available for mailbox folder permission operation'
    }

    $FolderList = @(
        @($FolderIdentities) + @($FolderIdentity) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    if ($FolderList.Count -gt 3) {
        $FolderList = @($FolderList | Select-Object -First 3)
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

        if ($Action -eq 'Remove') {
            $LivePermissions = $null
            try {
                $LivePermissions = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderPermission' -cmdParams @{
                    Identity = $ThisFolder
                } -Anchor $Anchor -UseSystemMailbox $true
            } catch {
                $LastError = $_
                Write-Information "Get-MailboxFolderPermission failed for '$ThisFolder': $((Get-CippException -Exception $_).NormalizedError)"
                continue
            }

            $CandidateSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($Candidate in $UniqueCandidates) { [void]$CandidateSet.Add([string]$Candidate) }

            $AclTryKeys = [System.Collections.Generic.List[string]]::new()
            foreach ($Perm in @($LivePermissions)) {
                $AclKeys = Get-CIPPFolderPermissionAclUserKeys -PermUser $Perm.User
                $AclDisplay = $AclKeys | Select-Object -First 1
                if (-not $AclDisplay -or $AclDisplay -in $SystemUsers) { continue }

                $MatchesTarget = $false
                foreach ($AclKey in $AclKeys) {
                    if ($CandidateSet.Contains([string]$AclKey)) { $MatchesTarget = $true; break }
                }
                if (-not $MatchesTarget) { continue }

                foreach ($AclKey in $AclKeys) {
                    if ($AclKey -notin $SystemUsers -and -not $AclTryKeys.Contains($AclKey)) {
                        $AclTryKeys.Add($AclKey)
                    }
                }
            }

            foreach ($UserKey in @($AclTryKeys) + @($UniqueCandidates)) {
                if ([string]::IsNullOrWhiteSpace($UserKey) -or $UserKey -in $SystemUsers) { continue }
                try {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams @{
                        Identity = $ThisFolder
                        User     = $UserKey
                    } -Anchor $Anchor -UseSystemMailbox $true
                    return [PSCustomObject]@{
                        Success      = $true
                        UsedUser     = $UserKey
                        UsedFolder   = $ThisFolder
                        TriedUser    = @($UniqueCandidates)
                        TriedFolders = @($TriedFolders)
                    }
                } catch {
                    $LastError = $_
                    $Normalized = (Get-CippException -Exception $_).NormalizedError
                    if ($Normalized -notmatch $RetryablePattern) {
                        throw
                    }
                    Write-Information "Remove failed for '$UserKey' on '$ThisFolder': $Normalized"
                }
            }
            continue
        }

        foreach ($Candidate in $UniqueCandidates) {
            try {
                $CmdParams = @{
                    Identity               = $ThisFolder
                    User                   = $Candidate
                    AccessRights           = @($AccessRights)
                    SendNotificationToUser = $SendNotificationToUser
                }
                if ($SharingPermissionFlags) {
                    $CmdParams['SharingPermissionFlags'] = $SharingPermissionFlags
                }
                $Cmdlet = if ($Action -eq 'Set') { 'Set-MailboxFolderPermission' } else { 'Add-MailboxFolderPermission' }
                $null = New-ExoRequest -tenantid $TenantFilter -cmdlet $Cmdlet -cmdParams $CmdParams -Anchor $Anchor
                return [PSCustomObject]@{
                    Success      = $true
                    UsedUser     = $Candidate
                    UsedFolder   = $ThisFolder
                    TriedUser    = @($UniqueCandidates)
                    TriedFolders = @($TriedFolders)
                }
            } catch {
                $Normalized = (Get-CippException -Exception $_).NormalizedError
                $LastError = $_
                if ($Normalized -notmatch $RetryablePattern) {
                    throw
                }
                Write-Information "Folder permission $Action failed for candidate '$Candidate' on '$ThisFolder': $Normalized — trying next"
            }
        }
    }

    $Tried = ($UniqueCandidates -join ', ')
    $FoldersTried = (@($TriedFolders) -join ', ')
    $Msg = if ($LastError) { (Get-CippException -Exception $LastError).NormalizedError } else { 'No matching permission entry could be removed' }
    throw "Failed after trying identities [$Tried] on folders [$FoldersTried]: $Msg"
}
