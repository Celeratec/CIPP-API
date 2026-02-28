function Invoke-ExecDomainMigration {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $SourceDomain = $Request.Body.sourceDomain
    $TargetDomain = $Request.Body.targetDomain
    $Users = $Request.Body.users
    $Groups = $Request.Body.groups

    $Results = [System.Collections.Generic.List[object]]::new()

    if ([string]::IsNullOrWhiteSpace($TenantFilter) -or [string]::IsNullOrWhiteSpace($TargetDomain)) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = @('Missing required parameters: tenantFilter and targetDomain') }
        })
    }

    # Process Users
    if ($Users -and $Users.Count -gt 0) {
        foreach ($User in $Users) {
            try {
                $CurrentUPN = $User.userPrincipalName
                $DisplayName = $User.displayName ?? $CurrentUPN
                $UserId = $User.id

                if ([string]::IsNullOrWhiteSpace($CurrentUPN) -or [string]::IsNullOrWhiteSpace($UserId)) {
                    $Results.Add("Skipped $($DisplayName ?? 'unknown user') - missing id or userPrincipalName")
                    continue
                }

                if ($CurrentUPN -match '#EXT#') {
                    $Results.Add("Skipped $DisplayName - guest users cannot have their UPN changed")
                    continue
                }

                $MailNickname = ($CurrentUPN -split '@')[0]
                $CurrentDomain = ($CurrentUPN -split '@')[1]

                if ($CurrentDomain -eq $TargetDomain) {
                    $Results.Add("Skipped $DisplayName - already on $TargetDomain")
                    continue
                }

                $NewUPN = "$MailNickname@$TargetDomain"

                # Check for conflicts
                $EscapedUPN = $NewUPN -replace "'", "''"
                $ConflictFilters = @(
                    "userPrincipalName eq '$EscapedUPN'"
                    "mail eq '$EscapedUPN'"
                    "proxyAddresses/any(x:x eq 'smtp:$EscapedUPN')"
                )
                $ConflictFound = $false
                foreach ($Filter in $ConflictFilters) {
                    try {
                        $ConflictUsers = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/users?`$filter=$Filter&`$select=id,displayName,userPrincipalName" -tenantid $TenantFilter -ComplexFilter
                        foreach ($ConflictUser in $ConflictUsers) {
                            if ($ConflictUser.id -ne $UserId) {
                                $Results.Add("Failed to migrate $DisplayName - $NewUPN conflicts with user $($ConflictUser.displayName) ($($ConflictUser.userPrincipalName)) [ID: $($ConflictUser.id)]")
                                $ConflictFound = $true
                                break
                            }
                        }
                    } catch {
                        Write-Verbose "Conflict lookup failed for user filter '$Filter': $($_.Exception.Message)"
                    }
                    if ($ConflictFound) { break }
                }

                if (-not $ConflictFound) {
                    foreach ($Filter in $ConflictFilters) {
                        try {
                            $ConflictGroups = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=$Filter&`$select=id,displayName,mail" -tenantid $TenantFilter -ComplexFilter
                            foreach ($ConflictGroup in $ConflictGroups) {
                                $Results.Add("Failed to migrate $DisplayName - $NewUPN conflicts with group $($ConflictGroup.displayName) ($($ConflictGroup.mail)) [ID: $($ConflictGroup.id)]")
                                $ConflictFound = $true
                                break
                            }
                        } catch {
                            Write-Verbose "Conflict lookup failed for group filter '$Filter': $($_.Exception.Message)"
                        }
                        if ($ConflictFound) { break }
                    }
                }

                if ($ConflictFound) { continue }

                $Body = @{
                    userPrincipalName = $NewUPN
                } | ConvertTo-Json -Compress
                $null = New-GraphPostRequest -uri "https://graph.microsoft.com/beta/users/$UserId" -tenantid $TenantFilter -type PATCH -body $Body

                # Add old email as alias via Exchange
                try {
                    $CurrentMailbox = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Mailbox' -cmdParams @{ Identity = $UserId } -UseSystemMailbox $true
                    if ($CurrentMailbox) {
                        $CurrentProxyAddresses = @($CurrentMailbox.EmailAddresses)
                        $OldSmtp = "smtp:$CurrentUPN"

                        $AliasExists = $CurrentProxyAddresses | Where-Object { $_.ToLower() -eq $OldSmtp.ToLower() }
                        if (-not $AliasExists) {
                            $NewProxyAddresses = @("SMTP:$NewUPN") + @($CurrentProxyAddresses | ForEach-Object {
                                if ($_ -cmatch '^SMTP:') { $_.ToLower() } else { $_ }
                            }) + @($OldSmtp)
                            $Seen = @{}
                            $NewProxyAddresses = $NewProxyAddresses | Where-Object {
                                $lower = $_.ToLower()
                                if ($Seen.ContainsKey($lower)) { $false } else { $Seen[$lower] = $true; $true }
                            }
                            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-Mailbox' -cmdParams @{
                                Identity       = $UserId
                                EmailAddresses = $NewProxyAddresses
                            } -UseSystemMailbox $true
                        }
                        $Results.Add("Successfully migrated $DisplayName from $CurrentUPN to $NewUPN (old address kept as alias)")
                    } else {
                        $Results.Add("Migrated $DisplayName UPN to $NewUPN (no mailbox found - alias not created)")
                    }
                } catch {
                    $AliasError = Get-CippException -Exception $_
                    $Results.Add("Migrated $DisplayName UPN to $NewUPN but failed to add alias: $($AliasError.NormalizedError)")
                }

                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Migrated $DisplayName from $CurrentUPN to $NewUPN" -Sev Info

            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                $Results.Add("Failed to migrate $($User.displayName ?? $User.userPrincipalName): $($ErrorMessage.NormalizedError)")
                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Failed to migrate $($User.userPrincipalName): $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
            }
        }
    }

    # Process Groups
    if ($Groups -and $Groups.Count -gt 0) {
        foreach ($Group in $Groups) {
            try {
                $GroupMail = $Group.mail
                $GroupName = $Group.displayName ?? $GroupMail
                $GroupId = $Group.id
                $GroupType = $Group.groupType

                if ([string]::IsNullOrWhiteSpace($GroupId)) {
                    $Results.Add("Skipped group $($GroupName ?? 'unknown') - missing group id")
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($GroupMail)) {
                    $Results.Add("Skipped group $GroupName - no mail address")
                    continue
                }

                $MailPrefix = ($GroupMail -split '@')[0]
                $CurrentGroupDomain = ($GroupMail -split '@')[1]

                if ($CurrentGroupDomain -eq $TargetDomain) {
                    $Results.Add("Skipped group $GroupName - already on $TargetDomain")
                    continue
                }

                $NewMail = "$MailPrefix@$TargetDomain"

                if ($GroupType -eq 'Microsoft 365 Group') {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-UnifiedGroup' -cmdParams @{
                        Identity           = $GroupId
                        PrimarySmtpAddress = $NewMail
                    } -UseSystemMailbox $true
                } else {
                    $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-DistributionGroup' -cmdParams @{
                        Identity           = $GroupId
                        PrimarySmtpAddress = $NewMail
                    } -UseSystemMailbox $true
                }

                $Results.Add("Successfully migrated group $GroupName from $GroupMail to $NewMail (old address kept as alias)")
                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Migrated group $GroupName from $GroupMail to $NewMail" -Sev Info

            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                $Results.Add("Failed to migrate group $($Group.displayName ?? $Group.mail): $($ErrorMessage.NormalizedError)")
                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Failed to migrate group $($Group.mail): $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
            }
        }
    }

    if ($Results.Count -eq 0) {
        $Results.Add('No users or groups were provided for migration.')
    }

    return ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{ Results = @($Results) }
    })
}
