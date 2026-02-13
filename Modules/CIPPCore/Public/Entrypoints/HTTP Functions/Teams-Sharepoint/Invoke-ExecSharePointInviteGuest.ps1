function Invoke-ExecSharePointInviteGuest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter

    try {
        $ResultMessages = [System.Collections.Generic.List[string]]::new()

        # Step 1: Invite the guest user to the tenant
        $RedirectUrl = if ($Request.Body.redirectUri) { $Request.Body.redirectUri } else { 'https://myapps.microsoft.com' }
        $InviteBody = [pscustomobject]@{
            InvitedUserDisplayName  = $Request.Body.displayName
            InvitedUserEmailAddress = $Request.Body.mail
            sendInvitationMessage   = [bool]$Request.Body.sendInvite
            inviteRedirectUrl       = $RedirectUrl
        }
        $InviteBodyJson = ConvertTo-Json -Depth 10 -InputObject $InviteBody -Compress
        $InviteResult = New-GraphPostRequest -uri 'https://graph.microsoft.com/beta/invitations' -tenantid $TenantFilter -type POST -body $InviteBodyJson -Verbose

        $GuestUserId = $InviteResult.invitedUser.id
        $GuestUPN = $InviteResult.invitedUser.userPrincipalName

        if ($Request.Body.sendInvite -eq $true) {
            $ResultMessages.Add("Invited guest $($Request.Body.displayName) ($($Request.Body.mail)) with email invite.")
        } else {
            $ResultMessages.Add("Invited guest $($Request.Body.displayName) ($($Request.Body.mail)) without email invite.")
        }

        # Step 2: Add guest to the SharePoint site group (for Group-connected sites)
        if ($Request.Body.SharePointType -eq 'Group' -and $Request.Body.groupId -and $GuestUserId) {
            try {
                $GroupId = $Request.Body.groupId
                if ($GroupId -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                    $GroupId = (New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$GroupId' or proxyAddresses/any(x:endsWith(x,'$GroupId')) or mailNickname eq '$GroupId'" -ComplexFilter -tenantid $TenantFilter).id
                }

                if ($GroupId) {
                    $MemberIdentifier = if ($GuestUPN) { $GuestUPN } else { $GuestUserId }
                    $null = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $MemberIdentifier -TenantFilter $TenantFilter -Headers $Headers
                    $ResultMessages.Add("Added guest as a member of the SharePoint site.")
                } else {
                    $ResultMessages.Add("Warning: Could not resolve group ID for site membership.")
                }
            } catch {
                $GroupError = Get-CippException -Exception $_
                $ResultMessages.Add("Guest invited, but failed to add to site group: $($GroupError.NormalizedError)")
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to add guest to site group: $($GroupError.NormalizedError)" -Sev 'Warning' -LogData $GroupError
            }
        } elseif ($Request.Body.SharePointType -ne 'Group') {
            $ResultMessages.Add("Guest invited to tenant. Non-group sites require manual permission assignment in SharePoint.")
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($ResultMessages -join ' ') -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ResultMessages = @("Failed to invite guest. $($ErrorMessage.NormalizedError)")
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResultMessages[0] -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = @($ResultMessages) }
        })
}
