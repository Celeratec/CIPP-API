function Invoke-ListGroupAliases {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Groups.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter
    $GroupId = $Request.Query.groupId
    $GroupType = $Request.Query.groupType

    if ([string]::IsNullOrWhiteSpace($GroupId)) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'No group ID provided.' }
            })
    }

    if ($GroupType -notin @('Distribution List', 'Mail-Enabled Security', 'Microsoft 365')) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = "Group type '$GroupType' does not support email aliases." }
            })
    }

    try {
        $Params = @{ Identity = $GroupId }

        if ($GroupType -eq 'Microsoft 365') {
            $Group = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-UnifiedGroup' -cmdParams $Params -Select 'DisplayName,PrimarySmtpAddress,EmailAddresses' -UseSystemMailbox $true
        } else {
            $Group = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-DistributionGroup' -cmdParams $Params -Select 'DisplayName,PrimarySmtpAddress,EmailAddresses' -UseSystemMailbox $true
        }

        if (-not $Group) {
            throw 'Could not find mail-enabled group in Exchange Online.'
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            displayName    = $Group.DisplayName
            mail           = $Group.PrimarySmtpAddress
            proxyAddresses = @($Group.EmailAddresses)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to list group aliases: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
