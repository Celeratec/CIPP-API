function Invoke-EditGroupAliases {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $GroupObj = $Request.Body
    $TenantFilter = $GroupObj.tenantFilter
    $GroupType = $GroupObj.GroupType

    if ([string]::IsNullOrWhiteSpace($GroupObj.id)) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = @('Failed to manage aliases. No group ID provided.') }
            })
    }

    if ($GroupType -notin @('Distribution List', 'Mail-Enabled Security', 'Microsoft 365')) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = @("Group type '$GroupType' does not support email aliases.") }
            })
    }

    $Results = [System.Collections.Generic.List[object]]::new()
    $Aliases = if ($GroupObj.AddedAliases) { ($GroupObj.AddedAliases -split ',').ForEach({ $_.Trim() }) }
    $RemoveAliases = if ($GroupObj.RemovedAliases) { ($GroupObj.RemovedAliases -split ',').ForEach({ $_.Trim() }) }

    $GetCmdlet = if ($GroupType -eq 'Microsoft 365') { 'Get-UnifiedGroup' } else { 'Get-DistributionGroup' }
    $SetCmdlet = if ($GroupType -eq 'Microsoft 365') { 'Set-UnifiedGroup' } else { 'Set-DistributionGroup' }

    try {
        if ($Aliases -or $RemoveAliases -or $GroupObj.MakePrimary) {
            $CurrentGroup = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $GroupObj.id } -UseSystemMailbox $true

            if (-not $CurrentGroup) {
                throw 'Could not find mail-enabled group in Exchange Online.'
            }

            $CurrentProxyAddresses = @($CurrentGroup.EmailAddresses)
            $NewProxyAddresses = @($CurrentProxyAddresses)

            if ($GroupObj.MakePrimary) {
                $PrimaryAddress = $GroupObj.MakePrimary

                if ($PrimaryAddress -notlike 'SMTP:*') {
                    $PrimaryAddress = "SMTP:$($PrimaryAddress -replace '^smtp:', '')"
                }

                $ExistingAddress = $CurrentProxyAddresses | Where-Object { $_.ToLower() -eq $PrimaryAddress.ToLower() }

                if (-not $ExistingAddress) {
                    throw "Cannot set primary address. Address $($PrimaryAddress -replace '^SMTP:', '') not found in group addresses."
                }

                $NewProxyAddresses = $NewProxyAddresses | ForEach-Object {
                    if ($_ -like 'SMTP:*') {
                        $_.ToLower()
                    } else {
                        $_
                    }
                }

                $NewProxyAddresses = $NewProxyAddresses | Where-Object { $_.ToLower() -ne $PrimaryAddress.ToLower() }
                $NewProxyAddresses = @($PrimaryAddress) + $NewProxyAddresses

                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Set primary address for $($CurrentGroup.DisplayName)" -Sev Info
                $Results.Add('Success. Set new primary address.')
            }

            if ($RemoveAliases) {
                foreach ($Alias in $RemoveAliases) {
                    if ($Alias -notlike 'smtp:*') {
                        $Alias = "smtp:$Alias"
                    }
                    $NewProxyAddresses = $NewProxyAddresses | Where-Object { $_.ToLower() -ne $Alias.ToLower() }
                }
                Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Removed aliases from $($CurrentGroup.DisplayName)" -Sev Info
                $Results.Add('Success. Removed specified aliases from group.')
            }

            if ($Aliases) {
                $AliasesToAdd = @()
                foreach ($Alias in $Aliases) {
                    if ($Alias -notlike 'smtp:*') {
                        $Alias = "smtp:$Alias"
                    }
                    if (-not ($NewProxyAddresses | Where-Object { $_.ToLower() -eq $Alias.ToLower() })) {
                        $AliasesToAdd = $AliasesToAdd + $Alias
                    }
                }
                if ($AliasesToAdd.Count -gt 0) {
                    $NewProxyAddresses = $NewProxyAddresses + $AliasesToAdd
                    Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Added aliases to $($CurrentGroup.DisplayName)" -Sev Info
                    $Results.Add('Success. Added new aliases to group.')
                }
            }

            $Params = @{
                Identity       = $GroupObj.id
                EmailAddresses = $NewProxyAddresses
            }
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet $SetCmdlet -cmdParams $Params -UseSystemMailbox $true
        } else {
            $Results.Add('No alias changes specified.')
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message "Group alias management failed. $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        $Results.Add("Failed to manage aliases: $($ErrorMessage.NormalizedError)")
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = @($Results) }
        })
}
