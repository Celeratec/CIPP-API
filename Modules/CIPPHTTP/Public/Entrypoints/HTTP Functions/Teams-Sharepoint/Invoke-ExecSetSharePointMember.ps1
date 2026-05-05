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
                $SPUserId = $null
                $LastRestError = $null

                # Ensure user exists in SharePoint and capture their SP user ID
                try {
                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $EnsuredUser = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $SPUserId = $EnsuredUser.d.Id ?? $EnsuredUser.Id
                } catch {
                    $LastRestError = $_
                    Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "ensureuser failed: $($_.Exception.Message)" -Sev 'Info'
                }

                # Try adding to the associated member group (works for sites with a configured members group)
                if (-not $RestSuccess) {
                    try {
                        $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                        $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                        $RestSuccess = $true
                        $Results = "Successfully added $UserEmail as a member of the SharePoint site."
                    } catch {
                        $LastRestError = $_
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "associatedmembergroup failed: $($_.Exception.Message)" -Sev 'Info'
                    }
                }

                # If member group failed and we have a SP user ID, try direct role assignment.
                # This works even when the site has no associated member group (e.g. communication sites).
                if (-not $RestSuccess -and $SPUserId) {
                    try {
                        $RoleDefs = New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roledefinitions" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' }
                        $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 3 } | Select-Object -First 1
                        if (-not $EditRole) {
                            $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 2 } | Select-Object -First 1
                        }
                        $RoleDefId = $EditRole.Id

                        if ($RoleDefId) {
                            $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/roleassignments/addroleassignment(principalid=$SPUserId,roledefid=$RoleDefId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                            $RestSuccess = $true
                            $Results = "Successfully added $UserEmail as a member of the SharePoint site."
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Direct role assignment succeeded for $SiteUrl (RoleDefId=$RoleDefId)" -Sev 'Info'
                        } else {
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "No suitable role definition found on $SiteUrl" -Sev 'Warning'
                        }
                    } catch {
                        $LastRestError = $_
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Direct role assignment failed: $($_.Exception.Message)" -Sev 'Info'
                    }
                }

                # If all REST approaches failed, try CSOM elevation (make SAM account a site admin) then retry
                if (-not $RestSuccess) {
                    $LastErrorMsg = if ($LastRestError) { $LastRestError.Exception.Message } else { '' }
                    $IsAuthError = $LastErrorMsg -match 'unauthorized|Access denied|403|does not have permissions'

                    if ($IsAuthError) {
                        try {
                            $SamMe = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/me?`$select=userPrincipalName" -NoAuthCheck $true
                            $SamUPN = $SamMe.userPrincipalName

                            if ($SamUPN) {
                                Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Elevating SAM user ($SamUPN) to site collection admin on $SiteUrl" -Sev 'Info'

                                $ElevateXML = @"
<Request xmlns="http://schemas.microsoft.com/sharepoint/clientquery/2009" AddExpandoFieldTypeSuffix="true" SchemaVersion="15.0.0.0" LibraryVersion="16.0.0.0" ApplicationName=".NET Library">
  <Actions>
    <ObjectPath Id="249" ObjectPathId="248"/>
  </Actions>
  <ObjectPaths>
    <Method Id="248" ParentId="242" Name="SetSiteAdmin">
      <Parameters>
        <Parameter Type="String">$SiteUrl</Parameter>
        <Parameter Type="String">$SamUPN</Parameter>
        <Parameter Type="Boolean">true</Parameter>
      </Parameters>
    </Method>
    <Constructor Id="242" TypeId="{268004ae-ef6b-4e9b-8425-127220d84719}"/>
  </ObjectPaths>
</Request>
"@
                                $AdminResult = New-GraphPostRequest -scope "$($SharePointInfo.AdminUrl)/.default" -tenantid $TenantFilter -Uri "$($SharePointInfo.AdminUrl)/_vti_bin/client.svc/ProcessQuery" -Type POST -Body $ElevateXML -ContentType 'text/xml'

                                if (!$AdminResult.ErrorInfo.ErrorMessage) {
                                    Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "CSOM elevation succeeded, retrying member add for $SiteUrl" -Sev 'Info'

                                    # Retry ensureuser to get SP user ID if we didn't have it
                                    if (-not $SPUserId) {
                                        try {
                                            $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                                            $EnsuredUser = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                                            $SPUserId = $EnsuredUser.d.Id ?? $EnsuredUser.Id
                                        } catch {
                                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "ensureuser retry after elevation failed: $($_.Exception.Message)" -Sev 'Warning'
                                        }
                                    }

                                    # Retry member group add
                                    try {
                                        $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                                        $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                                        $RestSuccess = $true
                                        $Results = "Successfully added $UserEmail as a member of the SharePoint site."
                                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "associatedmembergroup retry succeeded after CSOM elevation for $SiteUrl" -Sev 'Info'
                                    } catch {
                                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "associatedmembergroup retry failed: $($_.Exception.Message)" -Sev 'Info'
                                    }

                                    # If member group still fails, try direct role assignment
                                    if (-not $RestSuccess -and $SPUserId) {
                                        try {
                                            $RoleDefs = New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roledefinitions" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' }
                                            $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 3 } | Select-Object -First 1
                                            if (-not $EditRole) {
                                                $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 2 } | Select-Object -First 1
                                            }
                                            $RoleDefId = $EditRole.Id
                                            if ($RoleDefId) {
                                                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/roleassignments/addroleassignment(principalid=$SPUserId,roledefid=$RoleDefId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                                                $RestSuccess = $true
                                                $Results = "Successfully added $UserEmail as a member of the SharePoint site."
                                                Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Direct role assignment succeeded after CSOM elevation for $SiteUrl" -Sev 'Info'
                                            }
                                        } catch {
                                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Direct role assignment retry failed: $($_.Exception.Message)" -Sev 'Warning'
                                        }
                                    }
                                } else {
                                    Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "CSOM SetSiteAdmin failed: $($AdminResult.ErrorInfo.ErrorMessage)" -Sev 'Warning'
                                }
                            }
                        } catch {
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "CSOM elevation failed: $($_.Exception.Message)" -Sev 'Warning'
                        }
                    }
                }

                # Last resort: Graph API drive invite (grants doc library write, not full site membership)
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
                            $Results = "Could not add $UserEmail to the site members group directly (the site may not have a members group configured), but they were granted document library write access via Graph API."
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Graph API fallback succeeded for non-group site member add" -Sev 'Info'
                        } else {
                            throw 'Could not resolve SharePoint site via Graph API.'
                        }
                    } catch {
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Graph API fallback also failed: $($_.Exception.Message)" -Sev 'Warning'
                    }

                    if (-not $GraphFallbackSuccess) {
                        throw $(if ($LastRestError) { $LastRestError.Exception } else { "All methods to add $UserEmail to site $SiteUrl failed." })
                    }
                }
            } else {
                # Remove: resolve user via ensureuser to get their SP ID, then remove from members group or role assignments
                $SPLoginName = $Request.Body.loginName
                if (!$SPLoginName) {
                    $SPLoginName = "i:0#.f|membership|$UserEmail"
                }

                $EnsureBody = ConvertTo-Json @{ logonName = $SPLoginName } -Compress
                $UserInfo = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders

                $SPUserId = $UserInfo.d.Id ?? $UserInfo.Id
                if ($SPUserId) {
                    $RemoveSuccess = $false

                    # Try removing from associated member group
                    try {
                        $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users/removeById($SPUserId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                        $RemoveSuccess = $true
                    } catch {
                        Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Member group remove failed, trying role assignment removal: $($_.Exception.Message)" -Sev 'Info'
                    }

                    # If member group removal failed, remove direct role assignments for this user
                    if (-not $RemoveSuccess) {
                        try {
                            $UserRoleAssignment = New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roleassignments/getbyprincipalid($SPUserId)/roledefinitionbindings" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' }
                            $RoleIds = @($UserRoleAssignment | ForEach-Object { $_.Id } | Where-Object { $_ })

                            foreach ($RoleId in $RoleIds) {
                                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/roleassignments/removeroleassignment(principalid=$SPUserId,roledefid=$RoleId)" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                            }
                            $RemoveSuccess = $true
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Removed $($RoleIds.Count) direct role assignment(s) for $UserEmail on $SiteUrl" -Sev 'Info'
                        } catch {
                            Write-LogMessage -headers $Headers -API 'ExecSetSharePointMember' -tenant $TenantFilter -message "Role assignment removal also failed: $($_.Exception.Message)" -Sev 'Warning'
                            throw "Could not remove $UserEmail from the SharePoint site. Neither the member group nor direct role assignment removal succeeded."
                        }
                    }

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
