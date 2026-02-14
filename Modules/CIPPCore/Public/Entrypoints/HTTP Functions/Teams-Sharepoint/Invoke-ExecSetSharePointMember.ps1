function Invoke-ExecSetSharePointMember {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Headers = $Request.Headers


    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Body.tenantFilter

    try {
        if ($Request.Body.SharePointType -eq 'Group') {
            if ($Request.Body.GroupID -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                $GroupId = $Request.Body.GroupID
            } else {
                $GroupId = (New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$($Request.Body.GroupID)' or proxyAddresses/any(x:endsWith(x,'$($Request.Body.GroupID)')) or mailNickname eq '$($Request.Body.GroupID)'" -ComplexFilter -tenantid $TenantFilter).id
            }

            if ($Request.Body.Add -eq $true) {
                $Results = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $Request.Body.user.value -TenantFilter $TenantFilter -Headers $Headers
            } else {
                $EncodedUser = [uri]::EscapeDataString($Request.Body.user.value)
                $UserID = (New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUser" -tenantid $TenantFilter).id
                $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
            }
            $StatusCode = [HttpStatusCode]::OK
        } else {
            # Non-group site: manage membership via Graph API sharing on the site's document library
            $SiteUrl = $Request.Body.URL
            if (!$SiteUrl) {
                throw 'Site URL is required for non-group site membership changes.'
            }

            $UserEmail = $Request.Body.user.value ?? $Request.Body.user

            # Resolve the Graph site ID from the site URL
            $SiteUri = [System.Uri]$SiteUrl
            $SiteHost = $SiteUri.Host
            $SitePath = $SiteUri.AbsolutePath.TrimEnd('/')
            $GraphSite = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/${SiteHost}:${SitePath}?`$select=id" -tenantid $TenantFilter -AsApp $true

            # Get the default document library drive
            $SiteDrive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($GraphSite.id)/drive?`$select=id" -tenantid $TenantFilter -AsApp $true

            if ($Request.Body.Add -eq $true) {
                # Resolve user's Entra object ID for reliable sharing
                # URL-encode the UPN because guest UPNs contain '#' (e.g. user_domain.com#EXT#@tenant.onmicrosoft.com)
                $EncodedEmail = [uri]::EscapeDataString($UserEmail)
                $UserObj = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedEmail?`$select=id" -tenantid $TenantFilter -AsApp $true

                # Grant edit access via sharing invitation on the document library root
                $ShareBody = ConvertTo-Json @{
                    recipients     = @(@{ objectId = $UserObj.id })
                    roles          = @('write')
                    requireSignIn  = $true
                    sendInvitation = $false
                } -Depth 5 -Compress
                $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/drives/$($SiteDrive.id)/root/invite" -tenantid $TenantFilter -type POST -body $ShareBody -AsApp $true

                $Results = "Successfully added $UserEmail as a member of the SharePoint site."
            } else {
                # Remove: find the user's sharing permission on the drive root and delete it
                $Permissions = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/drives/$($SiteDrive.id)/root/permissions" -tenantid $TenantFilter -AsApp $true
                $UserLower = $UserEmail.ToLower()
                $MatchedPerm = $Permissions | Where-Object {
                    ($_.grantedToV2.user.email -and $_.grantedToV2.user.email.ToLower() -eq $UserLower) -or
                    ($_.grantedTo.user.email -and $_.grantedTo.user.email.ToLower() -eq $UserLower) -or
                    ($_.grantedToIdentitiesV2 | Where-Object { $_.user.email -and $_.user.email.ToLower() -eq $UserLower }) -or
                    ($_.grantedToIdentities | Where-Object { $_.user.email -and $_.user.email.ToLower() -eq $UserLower })
                } | Select-Object -First 1

                if ($MatchedPerm) {
                    $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/drives/$($SiteDrive.id)/root/permissions/$($MatchedPerm.id)" -tenantid $TenantFilter -type DELETE -body '{}' -AsApp $true
                    $Results = "Successfully removed $UserEmail from the SharePoint site."
                } else {
                    throw "Could not find a sharing permission for $UserEmail on this site."
                }
            }
            $StatusCode = [HttpStatusCode]::OK
        }
    } catch {
        $Results = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::InternalServerError
    }


    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Results }
        })

}
