function Invoke-ExecSetSharePointMember {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    .DESCRIPTION
        Adds or removes a user in a SharePoint site role (Owners, Members or Visitors).
        Group-connected sites manage Owners/Members through the backing M365 group via Graph;
        Visitors (and classic/communication sites entirely) are managed through the site's
        associated SharePoint role groups via the SharePoint REST API using certificate
        authentication. Removals sourced from ListSiteMembers carry the group and type of the
        selected entry, so users directly added to a role group on a group-connected site are
        removed from that group rather than from the M365 group.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $UPN = $Request.Body.user.value ?? $Request.Body.user
    # The user picker sends .addedFields.id (Entra object ID). Prefer it for Graph user
    # lookups: guest UPNs contain '#' (#EXT#) which breaks URL paths and query strings.
    $UserObjectId = $Request.Body.user.addedFields.id ?? $Request.Body.user.id
    $Add = $Request.Body.Add -eq $true

    # Role comes from the removal picker's selected entry when present, else from the form.
    $Role = $Request.Body.user.addedFields.Group ?? $Request.Body.Role ?? 'Members'
    $MemberType = $Request.Body.user.addedFields.Type ?? $Request.Body.MemberType
    $AssociatedGroups = @{
        'Owners'   = 'associatedownergroup'
        'Members'  = 'associatedmembergroup'
        'Visitors' = 'associatedvisitorgroup'
    }

    # Resolves the Entra object ID for the selected user, preferring the picker-provided ID
    # and falling back to a filter query with '#' encoded so guest UPNs resolve correctly.
    function Resolve-MemberObjectId {
        param($UserObjectId, $UPN, $TenantFilter)
        if ($UserObjectId) { return $UserObjectId }
        $SafeUPN = ($UPN -replace "'", "''") -replace '#', '%23'
        $Lookup = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$SafeUPN'&`$select=id" -tenantid $TenantFilter -ComplexFilter
        return $Lookup.id
    }

    try {
        if (-not $UPN) { throw 'No user was selected.' }
        if (-not $AssociatedGroups.ContainsKey([string]$Role)) {
            throw "Invalid role '$Role'. Valid roles are: $($AssociatedGroups.Keys -join ', ')."
        }

        $IsGroupSite = $Request.Body.SharePointType -like 'Group*'
        # Owners/Members of a group-connected site live in the M365 group. Visitors are always
        # a SharePoint role group. A removal of a directly-added user (Type 'User') on a group
        # site targets the SharePoint role group instead of the M365 group.
        $UseGraphGroup = $IsGroupSite -and $Role -ne 'Visitors' -and ($Add -or $MemberType -ne 'User')

        if ($UseGraphGroup) {
            $RawGroupId = [string]$Request.Body.GroupID
            if ($RawGroupId -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
                $GroupId = $RawGroupId
            } else {
                # Escape single quotes for the OData filter (e.g. o'brien@contoso.com)
                $SafeGroupId = $RawGroupId -replace "'", "''"
                $LookupResults = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=mail eq '$SafeGroupId' or proxyAddresses/any(x:endsWith(x,'$SafeGroupId')) or mailNickname eq '$SafeGroupId'" -ComplexFilter -tenantid $TenantFilter
                $GroupId = if ($LookupResults -is [array]) { [string]($LookupResults | Select-Object -First 1).id } else { [string]$LookupResults.id }
            }

            if (-not $GroupId) {
                throw "Could not resolve M365 Group for this site. The GroupID value '$RawGroupId' did not match any group. If this is a group-connected site, try using the site details page which performs a direct group lookup."
            }

            if ($Role -eq 'Owners') {
                $UserID = Resolve-MemberObjectId -UserObjectId $UserObjectId -UPN $UPN -TenantFilter $TenantFilter
                if (-not $UserID) { throw "Could not resolve user $UPN." }
                if ($Add) {
                    $OwnerBody = ConvertTo-Json -Compress -InputObject @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$UserID" }
                    $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/groups/$GroupId/owners/`$ref" -tenantid $TenantFilter -type POST -body $OwnerBody
                    $Results = "Successfully added $UPN as an owner of the M365 group backing the site."
                } else {
                    $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/groups/$GroupId/owners/$UserID/`$ref" -tenantid $TenantFilter -type DELETE -body ''
                    $Results = "Successfully removed $UPN as an owner of the M365 group backing the site."
                }
                Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info
            } else {
                if ($Add) {
                    $Results = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UPN -TenantFilter $TenantFilter -Headers $Headers

                    # Force-add the user to the SharePoint User Information List so they appear
                    # immediately in the site members table. Adding to the M365 Group alone does
                    # not populate this list until the user visits the site or SP syncs.
                    $SiteUrl = $Request.Body.URL
                    if ($SiteUrl) {
                        try {
                            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                            $EnsureBody = ConvertTo-Json -Compress -InputObject @{ logonName = "i:0#.f|membership|$UPN" }
                            $null = New-GraphPostRequest -uri "$($SiteUrl.TrimEnd('/'))/_api/web/ensureuser" -tenantid $TenantFilter -scope "$($SharePointInfo.SharePointUrl)/.default" -type POST -body $EnsureBody -contentType 'application/json;odata=nometadata' -AddedHeaders @{ Accept = 'application/json;odata=nometadata' } -UseCertificate -AsApp $true
                        } catch {
                            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Member added to M365 Group but ensureuser failed: $($_.Exception.Message)" -Sev 'Warning'
                            $Results = @($Results) + 'Note: the member may take a few minutes to appear in the site members list.'
                        }
                    }
                } else {
                    $UserID = Resolve-MemberObjectId -UserObjectId $UserObjectId -UPN $UPN -TenantFilter $TenantFilter
                    if (-not $UserID) { throw "Could not resolve user $UPN." }
                    $Results = Remove-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UserID -TenantFilter $TenantFilter -Headers $Headers
                }
            }
            $StatusCode = [HttpStatusCode]::OK
        } else {
            # SharePoint role group management via REST with certificate auth.
            $SiteUrl = $Request.Body.URL
            if (-not $SiteUrl) { throw 'No site URL was provided for this site.' }

            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
            $Scope = "$($SharePointInfo.SharePointUrl)/.default"
            $JsonAccept = @{ Accept = 'application/json;odata=nometadata' }
            $BaseUri = "$($SiteUrl.TrimEnd('/'))/_api"
            $RoleGroup = $AssociatedGroups[[string]$Role]
            $RoleLabel = ([string]$Role).ToLower().TrimEnd('s')
            $Article = if ($RoleLabel -match '^[aeiou]') { 'an' } else { 'a' }

            try {
                $EnsureBody = ConvertTo-Json -Compress -InputObject @{ logonName = "i:0#.f|membership|$UPN" }
                $EnsuredUser = New-GraphPostRequest -uri "$BaseUri/web/ensureuser" -tenantid $TenantFilter -scope $Scope -type POST -body $EnsureBody -contentType 'application/json;odata=nometadata' -AddedHeaders $JsonAccept -UseCertificate -AsApp $true
            } catch {
                throw "Could not resolve $UPN on the site (ensureuser): $($_.Exception.Message)"
            }
            if (-not $EnsuredUser.Id) {
                throw "Could not resolve $UPN on the site."
            }

            if ($Add) {
                # Same shape PnP sends: an SP.User entity posted to the group's users
                # collection, which requires the odata=verbose content type.
                $AddBody = ConvertTo-Json -Compress -Depth 5 -InputObject @{
                    '__metadata' = @{ 'type' = 'SP.User' }
                    'LoginName'  = $EnsuredUser.LoginName
                }
                try {
                    $null = New-GraphPostRequest -uri "$BaseUri/web/$RoleGroup/users" -tenantid $TenantFilter -scope $Scope -type POST -body $AddBody -contentType 'application/json;odata=verbose' -AddedHeaders $JsonAccept -UseCertificate -AsApp $true
                } catch {
                    throw "Could not add $UPN to the site $Role group: $($_.Exception.Message)"
                }
                $Results = "Successfully added $UPN as $Article $RoleLabel of $SiteUrl."
            } else {
                try {
                    $null = New-GraphPostRequest -uri "$BaseUri/web/$RoleGroup/users/removebyid($($EnsuredUser.Id))" -tenantid $TenantFilter -scope $Scope -type POST -body '{}' -contentType 'application/json;odata=nometadata' -AddedHeaders $JsonAccept -UseCertificate -AsApp $true
                } catch {
                    if ($_.Exception.Message -match 'Can not find the user') {
                        throw "$UPN is not in the site's $Role group."
                    }
                    throw "Could not remove $UPN from the site $Role group: $($_.Exception.Message)"
                }
                $Results = "Successfully removed $UPN as $Article $RoleLabel of $SiteUrl."
            }
            Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info
            $StatusCode = [HttpStatusCode]::OK
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorMsg = $_.Exception.Message
        # Classify common failure modes into actionable guidance (rendered by CippApiResults)
        if ($ErrorMsg -match 'ID3035' -or $ErrorMsg -match 'is malformed' -or $ErrorMsg -match 'Could not get token') {
            $Results = "Failed to obtain a SharePoint token for this tenant. This usually means permissions have not been pushed via CPV consent. Try running a CPV Refresh for this tenant from the tenant overview page. Error: $($ErrorMessage.NormalizedError)"
        } elseif ($ErrorMsg -match 'No SAM certificate available') {
            $Results = "SharePoint site role management requires the SAM certificate, which is not provisioned yet. It is created automatically on authentication load or by the weekly token update. Error: $($ErrorMessage.NormalizedError)"
        } elseif ($ErrorMsg -match 'unauthorized' -or $ErrorMsg -match 'Access denied' -or $ErrorMsg -match '403') {
            $Results = "SharePoint denied access to this operation. This may be a site-level permission issue or the site may have restricted access. Try running a CPV Refresh for this tenant. Error: $($ErrorMessage.NormalizedError)"
        } else {
            $Results = "Failed to modify $Role for $($Request.Body.URL ?? $Request.Body.GroupID). Error: $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Results }
        })

}
