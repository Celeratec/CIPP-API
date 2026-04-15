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

        $RawGroupId = [string]$Request.Body.GroupID
        $IsGuidGroupId = $RawGroupId -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'

        if ($Request.Body.SharePointType -like 'Group*' -or $IsGuidGroupId) {
            if ($IsGuidGroupId) {
                $GroupId = $RawGroupId
            } else {
                $LookupResults = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$RawGroupId' or proxyAddresses/any(x:endsWith(x,'$RawGroupId')) or mailNickname eq '$RawGroupId'" -ComplexFilter -tenantid $TenantFilter
                $GroupId = if ($LookupResults -is [array]) { [string]($LookupResults | Select-Object -First 1).id } else { [string]$LookupResults.id }
            }

            if (-not $GroupId -or $GroupId -eq '') {
                throw "Could not resolve M365 Group for this site. The GroupID value '$RawGroupId' did not match any group. If this is a group-connected site, try using the site details page which performs a direct group lookup."
            }

            if ($Request.Body.Add -eq $true) {
                $Results = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UserEmail -TenantFilter $TenantFilter -Headers $Headers

                # Force-add the user to the SharePoint User Information List so they appear
                # immediately in the site members table. Adding to the M365 Group alone does
                # not populate this list until the user visits the site or SP syncs.
                # This also covers the "already a member" case where the user is in the group
                # but hasn't visited the site yet.
                $SiteUrl = $Request.Body.URL
                if ($SiteUrl) {
                    try {
                        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                        $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                        $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
                        $SPContentType = 'application/json;odata=verbose'
                        $LoginName = "i:0#.f|membership|$UserEmail"
                        $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                        $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                    } catch {
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Member added to M365 Group but ensureuser failed: $($_.Exception.Message)" -Sev 'Warning'
                        $Results += ' Note: the member may take a few minutes to appear in the site members list.'
                    }
                }
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
                $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
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
                $LoginName = "i:0#.f|membership|$UserEmail"
                $RestSuccess = $false

                try {
                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                    $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                    $RestSuccess = $true
                    $Results = "Successfully added $UserEmail as a member of the SharePoint site."
                } catch {
                    $RestError = $_
                    Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "SharePoint REST failed for non-group site, attempting Graph API fallback: $($RestError.Exception.Message)" -Sev 'Info'
                }

                if (-not $RestSuccess) {
                    $GraphFallbackSuccess = $false
                    try {
                        $SiteUri = [System.Uri]$SiteUrl
                        $GraphSiteIdentifier = "$($SiteUri.Host):$($SiteUri.AbsolutePath.TrimEnd('/'))"
                        $GraphSite = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$GraphSiteIdentifier" -tenantid $TenantFilter -AsApp $true

                        if ($GraphSite.id) {
                            $ShareBody = ConvertTo-Json @{
                                requireSignIn  = $true
                                sendInvitation = $false
                                roles          = @('write')
                                recipients     = @(@{ email = $UserEmail })
                            } -Compress
                            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/sites/$($GraphSite.id)/drive/root/invite" -tenantid $TenantFilter -type POST -body $ShareBody -AsApp $true
                            $GraphFallbackSuccess = $true
                            $Results = "The site members group could not be modified directly, but $UserEmail was successfully granted document library write access via Graph API."
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Graph API fallback succeeded for non-group site member add" -Sev 'Info'
                        } else {
                            throw 'Could not resolve SharePoint site via Graph API.'
                        }
                    } catch {
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Graph API fallback also failed: $($_.Exception.Message)" -Sev 'Warning'
                    }

                    if (-not $GraphFallbackSuccess) {
                        throw $RestError.Exception
                    }
                }
            } else {
                # Remove: resolve user via ensureuser to get their SP ID, then remove from members group
                # Use the login name from the table row if available, otherwise construct from email
                $SPLoginName = $Request.Body.loginName
                if (!$SPLoginName) {
                    $SPLoginName = "i:0#.f|membership|$UserEmail"
                }

                $EnsureBody = ConvertTo-Json @{ logonName = $SPLoginName } -Compress
                $UserInfo = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                $SPUserId = $UserInfo.d.Id ?? $UserInfo.Id
                if ($SPUserId) {
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users/removeById($SPUserId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $Results = "Successfully removed $UserEmail from the SharePoint site."
                } else {
                    throw "Could not resolve SharePoint user ID for $UserEmail."
                }
            }
            $StatusCode = [HttpStatusCode]::OK
        }
    } catch {
        $ErrorMsg = $_.Exception.Message
        $NormalizedError = Get-NormalizedError -Message $ErrorMsg
        if ($ErrorMsg -match 'ID3035' -or $ErrorMsg -match 'is malformed' -or $ErrorMsg -match 'Could not get token') {
            $Results = "Failed to obtain a SharePoint token for this tenant. This usually means delegated permissions have not been pushed via CPV consent. Try running a CPV Refresh for this tenant from the tenant overview page. Error: $NormalizedError"
        } elseif ($ErrorMsg -match 'Unsupported app only token') {
            $Results = "SharePoint rejected the app-only token for this operation. This is an internal error -- please report it. The endpoint should be using delegated authentication for SharePoint REST API calls."
        } elseif ($ErrorMsg -match 'unauthorized' -or $ErrorMsg -match 'Access denied' -or $ErrorMsg -match '403') {
            $Results = "SharePoint denied access to this operation. This may be a site-level permission issue or the site may have restricted access. Try running a CPV Refresh for this tenant. Error: $NormalizedError"
        } else {
            $Results = $NormalizedError
        }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }


    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Results }
        })

}
