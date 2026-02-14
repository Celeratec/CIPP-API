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
        # The user picker sends both .value (UPN) and .id (Entra object ID).
        # Use the object ID for Graph API calls to avoid UPN encoding issues
        # (guest UPNs contain '#' which breaks URL paths).
        $UserEmail = $Request.Body.user.value ?? $Request.Body.user
        $UserObjectId = $Request.Body.user.id

        if ($Request.Body.SharePointType -eq 'Group') {
            if ($Request.Body.GroupID -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                $GroupId = $Request.Body.GroupID
            } else {
                $GroupId = (New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$($Request.Body.GroupID)' or proxyAddresses/any(x:endsWith(x,'$($Request.Body.GroupID)')) or mailNickname eq '$($Request.Body.GroupID)'" -ComplexFilter -tenantid $TenantFilter).id
            }

            if ($Request.Body.Add -eq $true) {
                $Results = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $Request.Body.user.value -TenantFilter $TenantFilter -Headers $Headers
            } else {
                # Use the object ID directly if available, otherwise resolve via $filter
                if ($UserObjectId) {
                    $UserID = $UserObjectId
                } else {
                    $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$UserEmail'&`$select=id" -tenantid $TenantFilter -ComplexFilter
                    $UserID = $UserLookup.id
                }
                $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
            }
            $StatusCode = [HttpStatusCode]::OK
        } else {
            # Non-group site: manage membership via Graph API sharing on the site's document library
            $SiteUrl = $Request.Body.URL
            if (!$SiteUrl) {
                throw 'Site URL is required for non-group site membership changes.'
            }

            # Resolve the Graph site ID from the site URL
            $SiteUri = [System.Uri]$SiteUrl
            $SiteHost = $SiteUri.Host
            $SitePath = $SiteUri.AbsolutePath.TrimEnd('/')
            $GraphSite = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/${SiteHost}:${SitePath}?`$select=id" -tenantid $TenantFilter -AsApp $true

            # Get the default document library drive
            $SiteDrive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($GraphSite.id)/drive?`$select=id" -tenantid $TenantFilter -AsApp $true

            if ($Request.Body.Add -eq $true) {
                # Use the object ID from the picker, or resolve it via $filter if not available
                if (!$UserObjectId) {
                    $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$UserEmail'&`$select=id" -tenantid $TenantFilter -AsApp $true -ComplexFilter
                    $UserObjectId = $UserLookup.id
                }

                # Grant edit access via sharing invitation on the document library root
                $ShareBody = ConvertTo-Json @{
                    recipients     = @(@{ objectId = $UserObjectId })
                    roles          = @('write')
                    requireSignIn  = $true
                    sendInvitation = $false
                } -Depth 5 -Compress
                $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/drives/$($SiteDrive.id)/root/invite" -tenantid $TenantFilter -type POST -body $ShareBody -AsApp $true

                $Results = "Successfully added $UserEmail as a member of the SharePoint site."
            } else {
                # Remove: find the user's sharing permission on the drive root and delete it
                $Permissions = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/drives/$($SiteDrive.id)/root/permissions" -tenantid $TenantFilter -AsApp $true
                $UserLower = ($UserEmail ?? '').ToLower()
                $MatchedPerm = $Permissions | Where-Object {
                    ($_.grantedToV2.user.email -and $_.grantedToV2.user.email.ToLower() -eq $UserLower) -or
                    ($_.grantedToV2.user.id -and $UserObjectId -and $_.grantedToV2.user.id -eq $UserObjectId) -or
                    ($_.grantedTo.user.email -and $_.grantedTo.user.email.ToLower() -eq $UserLower) -or
                    ($_.grantedTo.user.id -and $UserObjectId -and $_.grantedTo.user.id -eq $UserObjectId) -or
                    ($_.grantedToIdentitiesV2 | Where-Object { ($_.user.email -and $_.user.email.ToLower() -eq $UserLower) -or ($_.user.id -and $UserObjectId -and $_.user.id -eq $UserObjectId) }) -or
                    ($_.grantedToIdentities | Where-Object { ($_.user.email -and $_.user.email.ToLower() -eq $UserLower) -or ($_.user.id -and $UserObjectId -and $_.user.id -eq $UserObjectId) })
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
