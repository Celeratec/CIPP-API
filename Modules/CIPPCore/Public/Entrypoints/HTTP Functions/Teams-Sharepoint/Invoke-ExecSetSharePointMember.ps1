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
        # The user picker sends .value (UPN), .addedFields.id (Entra object ID), and .label.
        # Use the object ID for Graph API calls to avoid UPN encoding issues
        # (guest UPNs contain '#' which breaks URL paths and query strings).
        $UserEmail = $Request.Body.user.value ?? $Request.Body.user
        $UserObjectId = $Request.Body.user.addedFields.id ?? $Request.Body.user.id

        if ($Request.Body.SharePointType -eq 'Group') {
            if ($Request.Body.GroupID -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                $GroupId = $Request.Body.GroupID
            } else {
                $GroupId = (New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$($Request.Body.GroupID)' or proxyAddresses/any(x:endsWith(x,'$($Request.Body.GroupID)')) or mailNickname eq '$($Request.Body.GroupID)'" -ComplexFilter -tenantid $TenantFilter).id
            }

            if ($Request.Body.Add -eq $true) {
                $Results = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $Request.Body.user.value -TenantFilter $TenantFilter -Headers $Headers
            } else {
                # Use the object ID directly if available, otherwise resolve via Graph
                if ($UserObjectId) {
                    $UserID = $UserObjectId
                } else {
                    # Encode '#' as '%23' in the UPN to prevent URL fragment parsing
                    $SafeEmail = $UserEmail -replace '#', '%23'
                    $UserLookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$SafeEmail'&`$select=id" -tenantid $TenantFilter -ComplexFilter
                    $UserID = $UserLookup.id
                }
                $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
            }
            $StatusCode = [HttpStatusCode]::OK
        } else {
            # Non-group site: manage membership via SharePoint REST API (site permission groups)
            $SiteUrl = $Request.Body.URL
            if (!$SiteUrl) {
                throw 'Site URL is required for non-group site membership changes.'
            }

            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
            $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
            $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
            $SPContentType = 'application/json;odata=verbose'

            if ($Request.Body.Add -eq $true) {
                # Build the claims login name from the UPN
                $LoginName = "i:0#.f|membership|$UserEmail"

                # Ensure the user exists in the site
                $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders -AsApp $true

                # Add to the site's default Members permission group
                $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders -AsApp $true

                $Results = "Successfully added $UserEmail as a member of the SharePoint site."
            } else {
                # Remove: resolve user via ensureuser to get their SP ID, then remove from members group
                # Use the login name from the table row if available, otherwise construct from email
                $SPLoginName = $Request.Body.loginName
                if (!$SPLoginName) {
                    $SPLoginName = "i:0#.f|membership|$UserEmail"
                }

                $EnsureBody = ConvertTo-Json @{ logonName = $SPLoginName } -Compress
                $UserInfo = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders -AsApp $true

                $SPUserId = $UserInfo.d.Id ?? $UserInfo.Id
                if ($SPUserId) {
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users/removeById($SPUserId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders -AsApp $true
                    $Results = "Successfully removed $UserEmail from the SharePoint site."
                } else {
                    throw "Could not resolve SharePoint user ID for $UserEmail."
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
