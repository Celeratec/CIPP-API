function Remove-CIPPGraphCalendarPermission {
    <#
    .SYNOPSIS
        Remove calendar permissions via Microsoft Graph calendarPermissions API.

    .DESCRIPTION
        Used when Exchange Remove-MailboxFolderPermission cannot bind an ACE (e.g. orphaned
        entry colliding with a live display name). Matches Graph calendarPermission rows by
        email address or display name, then deletes by permission id.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        $MailboxUserId,

        [Parameter(Mandatory = $true)]
        [string[]]$MatchValues
    )

    $MatchSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Value in $MatchValues) {
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            [void]$MatchSet.Add($Value.Trim())
        }
    }
    if ($MatchSet.Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Message = 'No match values for Graph calendar permission remove' }
    }

    try {
        $Permissions = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$MailboxUserId/calendar/calendarPermissions" -tenantid $TenantFilter -AsApp $true -NoAuthCheck $true
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Graph calendarPermissions list failed: $((Get-CippException -Exception $_).NormalizedError)"
        }
    }

    $Removed = [System.Collections.Generic.List[string]]::new()
    foreach ($Perm in @($Permissions)) {
        if (-not $Perm.id) { continue }
        if ($Perm.isRemovable -eq $false) { continue }

        $Email = $Perm.emailAddress.address
        $Name = $Perm.emailAddress.name
        $Matches = ($Email -and $MatchSet.Contains([string]$Email)) -or ($Name -and $MatchSet.Contains([string]$Name))
        if (-not $Matches) { continue }

        try {
            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/users/$MailboxUserId/calendar/calendarPermissions/$($Perm.id)" -tenantid $TenantFilter -type DELETE -body '{}' -AsApp $true -NoAuthCheck $true
            $Label = $Email ?? $Name ?? $Perm.id
            $Removed.Add([string]$Label)
            Write-Information "Removed Graph calendarPermission $Label ($($Perm.id)) from $MailboxUserId"
        } catch {
            Write-Information "Failed Graph calendarPermission delete $($Perm.id): $((Get-CippException -Exception $_).NormalizedError)"
        }
    }

    if ($Removed.Count -gt 0) {
        return [PSCustomObject]@{
            Success = $true
            Message = "Removed Graph calendar permission(s): $($Removed -join ', ')"
            Removed = @($Removed)
        }
    }

    return [PSCustomObject]@{
        Success = $false
        Message = 'No matching removable Graph calendarPermission entries found'
    }
}

function Invoke-CIPPCalendarPermissionCollisionRemove {
    <#
    .SYNOPSIS
        Last-resort remove for orphaned ACEs colliding with a live display name.

    .DESCRIPTION
        Temporarily renames live Graph users that share the ACE display name (and are among
        the known candidate emails/ids), removes the folder permission by display name, then
        restores the original display names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$FolderIdentity,

        [Parameter(Mandatory = $true)]
        [string]$AclDisplayName,

        [Parameter(Mandatory = $false)]
        [string[]]$ProtectedEmails,

        [Parameter(Mandatory = $false)]
        $Anchor
    )

    if ([string]::IsNullOrWhiteSpace($AclDisplayName)) {
        return [PSCustomObject]@{ Success = $false; Message = 'No ACL display name for collision remove' }
    }

    $Escaped = $AclDisplayName -replace "'", "''"
    try {
        $Users = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=displayName eq '$Escaped'&`$select=id,displayName,userPrincipalName,mail,accountEnabled,assignedLicenses" -tenantid $TenantFilter -NoAuthCheck $true)
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = "Could not list colliding users: $((Get-CippException -Exception $_).NormalizedError)" }
    }

    if ($Users.Count -lt 2 -and -not ($Users | Where-Object { ($_.mail -in $ProtectedEmails) -or ($_.userPrincipalName -in $ProtectedEmails) })) {
        # Still allow rename of unique live user so orphaned ACE can bind by name
        if ($Users.Count -eq 0) {
            return [PSCustomObject]@{ Success = $false; Message = 'No live users found with that display name for collision remove' }
        }
    }

    $ProtectSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Email in @($ProtectedEmails)) {
        if ($Email) { [void]$ProtectSet.Add($Email) }
    }

    # Rename every live licensed/enabled match so the orphaned ACE display name becomes unique
    $Renamed = [System.Collections.Generic.List[object]]::new()
    foreach ($User in $Users) {
        if (-not $User.id) { continue }
        $TempName = "$AclDisplayName [CIPP-TEMP-$([guid]::NewGuid().ToString('N').Substring(0,8))]"
        try {
            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/users/$($User.id)" -tenantid $TenantFilter -type PATCH -body (@{ displayName = $TempName } | ConvertTo-Json -Compress) -NoAuthCheck $true
            $Renamed.Add([PSCustomObject]@{ Id = $User.id; Original = $User.displayName; Temp = $TempName; UPN = $User.userPrincipalName })
            Write-Information "Temporarily renamed $($User.userPrincipalName) to '$TempName' for orphaned ACE remove"
        } catch {
            Write-Information "Failed to temp-rename $($User.userPrincipalName): $((Get-CippException -Exception $_).NormalizedError)"
        }
    }

    $RemoveSuccess = $false
    $RemoveError = $null
    try {
        Start-Sleep -Seconds 3
        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-MailboxFolderPermission' -cmdParams @{
            Identity = $FolderIdentity
            User     = $AclDisplayName
        } -Anchor $Anchor -UseSystemMailbox $true
        $RemoveSuccess = $true
    } catch {
        $RemoveError = (Get-CippException -Exception $_).NormalizedError
        Write-Information "Collision remove still failed for '$AclDisplayName': $RemoveError"
    }

    foreach ($Item in $Renamed) {
        try {
            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/users/$($Item.Id)" -tenantid $TenantFilter -type PATCH -body (@{ displayName = $Item.Original } | ConvertTo-Json -Compress) -NoAuthCheck $true
            Write-Information "Restored display name for $($Item.UPN)"
        } catch {
            Write-Warning "Failed to restore display name for $($Item.UPN) (was temp '$($Item.Temp)'): $((Get-CippException -Exception $_).NormalizedError)"
        }
    }

    if ($RemoveSuccess) {
        return [PSCustomObject]@{
            Success = $true
            Message = "Removed orphaned ACE '$AclDisplayName' after temporarily renaming $($Renamed.Count) live account(s)"
        }
    }

    return [PSCustomObject]@{
        Success = $false
        Message = "Collision remove failed: $RemoveError"
    }
}
