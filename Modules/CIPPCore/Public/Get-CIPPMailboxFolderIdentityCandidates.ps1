function Get-CIPPMailboxFolderIdentityCandidates {
    <#
    .SYNOPSIS
        Build Exchange folder Identity strings to try for folder-permission ops.

    .DESCRIPTION
        Prefer the same Identity shape ListCalendarPermissions uses (id:\FolderName).
        Optionally include FolderId / UPN variants. Keep the list small to avoid API timeouts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        $UserID,

        [Parameter(Mandatory = $false)]
        [string]$FolderName = 'Calendar',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Calendar', 'Contacts')]
        [string]$FolderScope = 'Calendar',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeFolderId,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUpnVariants
    )

    $Identities = [System.Collections.Generic.List[string]]::new()
    $Add = {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return }
        if (-not $Identities.Contains($Value)) { $Identities.Add($Value) }
    }

    $FolderType = if ($FolderScope -eq 'Contacts') { 'Contacts' } else { 'Calendar' }
    $FolderId = $null
    $ResolvedName = $FolderName
    $MailboxUPN = $null

    try {
        $Stats = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderStatistics' -cmdParams @{
            Identity    = $UserID
            FolderScope = $FolderScope
        } -Anchor $UserID
        $Primary = @($Stats) | Where-Object { $_.FolderType -eq $FolderType } | Select-Object -First 1
        if (-not $Primary) { $Primary = @($Stats) | Select-Object -First 1 }
        if ($Primary) {
            $FolderId = $Primary.FolderId
            if ($Primary.Name) { $ResolvedName = [string]$Primary.Name }
        }
    } catch {
        Write-Information "Could not get folder statistics for $UserID : $($_.Exception.Message)"
    }

    if ($IncludeUpnVariants) {
        try {
            $Mailbox = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Mailbox' -cmdParams @{ Identity = $UserID } -Anchor $UserID
            $MailboxUPN = $Mailbox.UserPrincipalName ?? $Mailbox.PrimarySmtpAddress
        } catch {
            Write-Information "Could not get mailbox for $UserID : $($_.Exception.Message)"
        }
    }

    # Prefer the same Identity shape ListCalendarPermissions uses
    & $Add "$UserID`:\$ResolvedName"
    if ($FolderName -and $FolderName -ne $ResolvedName) {
        & $Add "$UserID`:\$FolderName"
    }

    if ($IncludeUpnVariants -and $MailboxUPN) {
        & $Add "$MailboxUPN`:\$ResolvedName"
        if ($FolderName -and $FolderName -ne $ResolvedName) {
            & $Add "$MailboxUPN`:\$FolderName"
        }
    }

    if ($IncludeFolderId -and $FolderId) {
        & $Add "$UserID`:$FolderId"
        if ($IncludeUpnVariants -and $MailboxUPN) {
            & $Add "$MailboxUPN`:$FolderId"
        }
    }

    return @{
        Identities = @($Identities)
        FolderName = $ResolvedName
        FolderId   = $FolderId
        MailboxUPN = $MailboxUPN
    }
}

function Get-CIPPFolderPermissionAclUserKeys {
    <#
    .SYNOPSIS
        Extract every usable User key from a Get-MailboxFolderPermission User value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $PermUser
    )

    $Keys = [System.Collections.Generic.List[string]]::new()
    $Add = {
        param($Value)
        if ($null -eq $Value) { return }
        if ($Value -is [string]) {
            $Trimmed = $Value.Trim()
            if ($Trimmed -and -not $Keys.Contains($Trimmed)) { $Keys.Add($Trimmed) }
            return
        }
        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
            foreach ($Item in @($Value)) { & $Add $Item }
            return
        }
        if ($Value -is [psobject]) {
            foreach ($Name in @('UserSmtpAddress', 'SmtpAddress', 'PrimarySmtpAddress', 'DisplayName', 'UserId', 'Name', 'Identity', 'RawIdentity')) {
                if ($Value.PSObject.Properties.Name -contains $Name) {
                    & $Add $Value.$Name
                }
            }
            foreach ($Name in @('RecipientPrincipal', 'ADRecipient')) {
                if ($Value.PSObject.Properties.Name -contains $Name -and $Value.$Name) {
                    & $Add $Value.$Name
                }
            }
            if ($Keys.Count -eq 0) {
                & $Add ([string]$Value)
            }
        }
    }

    & $Add $PermUser
    return @($Keys)
}
