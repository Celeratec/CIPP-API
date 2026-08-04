function Resolve-CIPPFolderPermissionUser {
    <#
    .SYNOPSIS
        Resolve an Exchange folder-permission User value to SMTP/UPN/object ID candidates.

    .DESCRIPTION
        Get-MailboxFolderPermission often returns display names. Duplicate display names
        (e.g. licensed + unlicensed accounts) cause Remove/Set-MailboxFolderPermission to
        bind the wrong principal and throw UserNotFoundInPermissionEntryException.

        This helper resolves via Graph and Get-Recipient, preferring mailbox-enabled
        Exchange recipients, and returns ordered identity candidates for retries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        $User,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter
    )

    $SystemUsers = @('Default', 'Anonymous', 'NT AUTHORITY\SELF')

    if ($null -eq $User -or $User -eq '') {
        return [PSCustomObject]@{
            User            = $null
            UserEmail       = $null
            UserId          = $null
            UserAmbiguous   = $false
            IsSystemUser    = $false
            Candidates      = @()
            CandidateEmails = @()
        }
    }

    $UserString = $null
    if ($User -is [System.Collections.IEnumerable] -and $User -isnot [string]) {
        $First = @($User) | Select-Object -First 1
        if ($First -is [psobject] -and ($First.PSObject.Properties.Name -contains 'DisplayName' -or $First.PSObject.Properties.Name -contains 'UserId')) {
            $UserString = $First.DisplayName ?? $First.UserId ?? [string]$First
        } else {
            $UserString = [string]$First
        }
    } elseif ($User -is [psobject] -and -not ($User -is [string])) {
        $UserString = $User.DisplayName ?? $User.UserId ?? $User.userPrincipalName ?? $User.mail ?? [string]$User
    } else {
        $UserString = [string]$User
    }

    $UserString = $UserString.Trim()

    if ($UserString -in $SystemUsers) {
        return [PSCustomObject]@{
            User            = $UserString
            UserEmail       = $null
            UserId          = $null
            UserAmbiguous   = $false
            IsSystemUser    = $true
            Candidates      = @($UserString)
            CandidateEmails = @()
        }
    }

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $CandidateEmails = [System.Collections.Generic.List[string]]::new()
    $MatchedPrincipals = [System.Collections.Generic.List[object]]::new()
    $ResolvedId = $null
    $ResolvedEmail = $null
    $Ambiguous = $false
    $DisplayNameForSearch = $null

    $AddCandidate = {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return }
        if (-not $Candidates.Contains($Value)) {
            $Candidates.Add($Value)
        }
    }

    $AddEmail = {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '@') { return }
        if (-not $CandidateEmails.Contains($Value)) {
            $CandidateEmails.Add($Value)
        }
    }

    $AddPrincipal = {
        param(
            [string]$Type,
            [string]$Id,
            [string]$Mail,
            [string]$UserPrincipalName,
            [bool]$AccountEnabled = $true,
            [int]$LicenseCount = 0,
            [bool]$IsExchangeRecipient = $false,
            [string]$RecipientTypeDetails = $null
        )
        if ([string]::IsNullOrWhiteSpace($Id) -and [string]::IsNullOrWhiteSpace($Mail) -and [string]::IsNullOrWhiteSpace($UserPrincipalName)) {
            return
        }
        $Key = ($Id ?? $UserPrincipalName ?? $Mail).ToLowerInvariant()
        $Existing = $MatchedPrincipals | Where-Object {
            ($_.Id -and $Id -and $_.Id -eq $Id) -or
            ($_.UserPrincipalName -and $UserPrincipalName -and $_.UserPrincipalName -eq $UserPrincipalName) -or
            ($_.Mail -and $Mail -and $_.Mail -eq $Mail)
        } | Select-Object -First 1

        if ($Existing) {
            if ($IsExchangeRecipient) { $Existing.IsExchangeRecipient = $true }
            if ($RecipientTypeDetails) { $Existing.RecipientTypeDetails = $RecipientTypeDetails }
            if ($LicenseCount -gt $Existing.LicenseCount) { $Existing.LicenseCount = $LicenseCount }
            if ($Id -and -not $Existing.Id) { $Existing.Id = $Id }
            if ($Mail -and -not $Existing.Mail) { $Existing.Mail = $Mail }
            if ($UserPrincipalName -and -not $Existing.UserPrincipalName) { $Existing.UserPrincipalName = $UserPrincipalName }
            return
        }

        $MatchedPrincipals.Add([PSCustomObject]@{
                Type                 = $Type
                Id                   = $Id
                Mail                 = $Mail
                UserPrincipalName    = $UserPrincipalName
                AccountEnabled       = $AccountEnabled
                LicenseCount         = $LicenseCount
                IsExchangeRecipient  = $IsExchangeRecipient
                RecipientTypeDetails = $RecipientTypeDetails
                Key                  = $Key
            })
    }

    # Always keep the original identifier as a candidate (Exchange sometimes only accepts the ACL display name)
    & $AddCandidate $UserString

    if ($UserString -match '@') {
        & $AddEmail $UserString
        try {
            $DirectUser = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$([System.Uri]::EscapeDataString($UserString))?`$select=id,displayName,userPrincipalName,mail,accountEnabled,assignedLicenses" -tenantid $TenantFilter -NoAuthCheck $true
            if ($DirectUser.id) {
                $DisplayNameForSearch = $DirectUser.displayName
                & $AddPrincipal -Type 'User' -Id $DirectUser.id -Mail $DirectUser.mail -UserPrincipalName $DirectUser.userPrincipalName -AccountEnabled ([bool]$DirectUser.accountEnabled) -LicenseCount @($DirectUser.assignedLicenses).Count
            }
        } catch {
            Write-Information "Could not resolve folder permission user by email '$UserString': $($_.Exception.Message)"
        }
    } elseif ($UserString -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        try {
            $DirectUser = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserString?`$select=id,displayName,userPrincipalName,mail,accountEnabled,assignedLicenses" -tenantid $TenantFilter -NoAuthCheck $true
            if ($DirectUser.id) {
                $DisplayNameForSearch = $DirectUser.displayName
                & $AddPrincipal -Type 'User' -Id $DirectUser.id -Mail $DirectUser.mail -UserPrincipalName $DirectUser.userPrincipalName -AccountEnabled ([bool]$DirectUser.accountEnabled) -LicenseCount @($DirectUser.assignedLicenses).Count
            }
        } catch {
            Write-Information "Could not resolve folder permission user by id '$UserString': $($_.Exception.Message)"
        }
    } else {
        $DisplayNameForSearch = $UserString
    }

    if (-not $DisplayNameForSearch -and $UserString -notmatch '@' -and $UserString -notmatch '^[0-9a-fA-F-]{36}$') {
        $DisplayNameForSearch = $UserString
    }

    # Exchange often only removes the ACE when -User matches the ACL display name string
    if ($DisplayNameForSearch -and $DisplayNameForSearch -ne $UserString) {
        & $AddCandidate $DisplayNameForSearch
    }

    # Graph users by display name (catches duplicate-name siblings even when UI passed a bad SMTP)
    if ($DisplayNameForSearch) {
        $EscapedName = $DisplayNameForSearch -replace "'", "''"
        try {
            $GraphUsers = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=displayName eq '$EscapedName'&`$select=id,displayName,userPrincipalName,mail,accountEnabled,assignedLicenses" -tenantid $TenantFilter -NoAuthCheck $true
            foreach ($GraphUser in @($GraphUsers)) {
                if ($GraphUser.id) {
                    & $AddPrincipal -Type 'User' -Id $GraphUser.id -Mail $GraphUser.mail -UserPrincipalName $GraphUser.userPrincipalName -AccountEnabled ([bool]$GraphUser.accountEnabled) -LicenseCount @($GraphUser.assignedLicenses).Count
                }
            }
        } catch {
            Write-Information "Could not search users by display name '$DisplayNameForSearch': $($_.Exception.Message)"
        }

        try {
            $GraphGroups = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$EscapedName'&`$select=id,displayName,mail" -tenantid $TenantFilter -NoAuthCheck $true
            foreach ($GraphGroup in @($GraphGroups)) {
                if ($GraphGroup.id) {
                    & $AddPrincipal -Type 'Group' -Id $GraphGroup.id -Mail $GraphGroup.mail -UserPrincipalName $GraphGroup.mail -AccountEnabled $true -LicenseCount 1
                }
            }
        } catch {
            Write-Information "Could not search groups by display name '$DisplayNameForSearch': $($_.Exception.Message)"
        }

        # Prefer identities Exchange actually knows about
        try {
            $EscapedFilterName = $DisplayNameForSearch -replace "'", "''"
            $Recipients = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Recipient' -cmdParams @{
                Filter     = "DisplayName -eq '$EscapedFilterName'"
                ResultSize = 20
            } -UseSystemMailbox $true
            foreach ($Recipient in @($Recipients)) {
                $RecipientId = $Recipient.ExternalDirectoryObjectId ?? $Recipient.Guid ?? $Recipient.Identity
                & $AddPrincipal -Type ($(if ($Recipient.RecipientTypeDetails -match 'Group') { 'Group' } else { 'User' })) `
                    -Id ([string]$RecipientId) `
                    -Mail ($Recipient.PrimarySmtpAddress) `
                    -UserPrincipalName ($Recipient.PrimarySmtpAddress) `
                    -AccountEnabled $true `
                    -LicenseCount 1 `
                    -IsExchangeRecipient $true `
                    -RecipientTypeDetails ([string]$Recipient.RecipientTypeDetails)
            }
        } catch {
            Write-Information "Could not Get-Recipient by display name '$DisplayNameForSearch': $($_.Exception.Message)"
        }
    }

    # Also validate the original email / UPN directly with Get-Recipient when applicable
    if ($UserString -match '@') {
        try {
            $DirectRecipient = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Recipient' -cmdParams @{
                Identity = $UserString
            } -UseSystemMailbox $true
            if ($DirectRecipient) {
                foreach ($Recipient in @($DirectRecipient)) {
                    $RecipientId = $Recipient.ExternalDirectoryObjectId ?? $Recipient.Guid ?? $Recipient.Identity
                    & $AddPrincipal -Type 'User' -Id ([string]$RecipientId) -Mail ($Recipient.PrimarySmtpAddress) -UserPrincipalName ($Recipient.PrimarySmtpAddress) -AccountEnabled $true -LicenseCount 1 -IsExchangeRecipient $true -RecipientTypeDetails ([string]$Recipient.RecipientTypeDetails)
                }
            }
        } catch {
            Write-Information "Get-Recipient could not validate '$UserString' (will still try sibling candidates): $($_.Exception.Message)"
        }
    }

    if ($MatchedPrincipals.Count -gt 1) {
        $Ambiguous = $true
    }

    # Prefer real Exchange recipients, then enabled + licensed users
    $Ordered = @($MatchedPrincipals | Sort-Object -Property `
        @{ Expression = { -not $_.IsExchangeRecipient } },
        @{ Expression = { if ($_.Type -eq 'User') { 0 } else { 1 } } },
        @{ Expression = { -not $_.AccountEnabled } },
        @{ Expression = { $_.LicenseCount -eq 0 } })

    foreach ($Principal in $Ordered) {
        # Prefer SMTP/UPN before object ID for EXO folder permissions; keep all forms
        & $AddCandidate $Principal.UserPrincipalName
        & $AddCandidate $Principal.Mail
        & $AddCandidate $Principal.Id
        & $AddEmail $Principal.UserPrincipalName
        & $AddEmail $Principal.Mail
    }

    # UserEmail for UI / API prefer: first Exchange recipient SMTP, else first licensed Graph mail
    $Preferred = $Ordered | Where-Object { $_.IsExchangeRecipient -and ($_.Mail -or $_.UserPrincipalName) } | Select-Object -First 1
    if (-not $Preferred) {
        $Preferred = $Ordered | Where-Object { $_.LicenseCount -gt 0 -and ($_.Mail -or $_.UserPrincipalName) } | Select-Object -First 1
    }
    if (-not $Preferred) {
        $Preferred = $Ordered | Where-Object { $_.Mail -or $_.UserPrincipalName } | Select-Object -First 1
    }

    # Only stamp a single UserEmail when not ambiguous OR when Exchange uniquely identified a recipient
    $ExchangeHits = @($Ordered | Where-Object { $_.IsExchangeRecipient })
    if ($Preferred -and ($ExchangeHits.Count -eq 1 -or -not $Ambiguous)) {
        $ResolvedId = $Preferred.Id
        $ResolvedEmail = $Preferred.Mail ?? $Preferred.UserPrincipalName
        if ($ExchangeHits.Count -eq 1) {
            $Ambiguous = $false
        }
    } elseif ($Preferred -and $Ambiguous -and $ExchangeHits.Count -ge 1) {
        # Still expose the best mailbox SMTP for remove preference; keep Ambiguous true for UI warning
        $ResolvedId = $Preferred.Id
        $ResolvedEmail = $Preferred.Mail ?? $Preferred.UserPrincipalName
    }

    return [PSCustomObject]@{
        User            = $UserString
        UserEmail       = $ResolvedEmail
        UserId          = $ResolvedId
        UserAmbiguous   = $Ambiguous
        IsSystemUser    = $false
        Candidates      = @($Candidates)
        CandidateEmails = @($CandidateEmails | Select-Object -Unique)
    }
}
