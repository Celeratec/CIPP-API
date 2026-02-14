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
                $UserID = (New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$($Request.Body.user.value)" -tenantid $TenantFilter).id
                $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupID -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
            }
            $StatusCode = [HttpStatusCode]::OK
        } else {
            # Non-group site: manage membership via SharePoint REST API
            $SiteUrl = $Request.Body.URL
            if (!$SiteUrl) {
                throw 'Site URL is required for non-group site membership changes.'
            }

            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
            $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
            $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
            $SPContentType = 'application/json;odata=verbose'

            # Resolve the user's login name for SharePoint
            $UserEmail = $Request.Body.user.value ?? $Request.Body.user
            $LoginName = "i:0#.f|membership|$UserEmail"

            if ($Request.Body.Add -eq $true) {
                # Ensure the user exists in the site's User Information List
                $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders -NoAuthCheck $true

                # Add to the site's default Members group
                $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders -NoAuthCheck $true

                $Results = "Successfully added $UserEmail as a member of the SharePoint site."
            } else {
                # Remove: first get the user's SharePoint ID, then remove from members group
                $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                $UserInfo = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders -NoAuthCheck $true

                $SPUserId = $UserInfo.d.Id ?? $UserInfo.Id
                if ($SPUserId) {
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users/removeById($SPUserId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders -NoAuthCheck $true
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
