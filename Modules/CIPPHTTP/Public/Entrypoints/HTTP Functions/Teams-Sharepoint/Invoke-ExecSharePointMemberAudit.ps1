function Invoke-ExecSharePointMemberAudit {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $SiteId = $Request.Body.siteId
    $SiteUrl = $Request.Body.siteUrl
    $GroupId = $Request.Body.groupId
    $SharePointType = $Request.Body.sharePointType
    $Action = $Request.Body.action ?? 'audit'

    if (-not $TenantFilter -or -not $SiteId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = @{ error = 'tenantFilter and siteId are required.' } }
        })
    }

    $IsGroupConnected = ($SharePointType -like 'Group*') -or ($GroupId -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')

    try {
        if ($Action -eq 'audit') {
            $Issues = [System.Collections.Generic.List[hashtable]]::new()

            # --- Data source 1: SP User Information List ---
            $UILUsers = @()
            try {
                $Lists = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/sites/$SiteId/lists?`$select=id,list,system" -tenantid $TenantFilter -AsApp $true
                $UIList = $Lists | Where-Object { $_.list.template -eq 'userInformation' } | Select-Object -First 1
                if ($UIList.id) {
                    $UILItems = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/sites/$SiteId/lists/$($UIList.id)/items?`$expand=fields&`$filter=fields/ContentType eq 'Person'" -tenantid $TenantFilter -AsApp $true
                    $UILUsers = @($UILItems | Where-Object {
                        $email = $_.fields.EMail
                        $title = ($_.fields.Title ?? '').ToLower()
                        $excluded = @('system account', 'sharepoint app', 'nt service', 'everyone')
                        $isSys = $excluded | Where-Object { $title -like "*$_*" -or $title -like 'nt *' }
                        $email -and -not $isSys
                    })
                }
            } catch {
                Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Failed to read User Information List: $($_.Exception.Message)" -Sev 'Warning'
            }

            $UILEmailSet = @{}
            foreach ($u in $UILUsers) {
                $email = ($u.fields.EMail ?? '').ToLower()
                if ($email) { $UILEmailSet[$email] = $u }
            }

            # --- Data source 2: Drive root permissions ---
            $DrivePerms = @()
            try {
                $DrivePerms = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drive/root/permissions" -tenantid $TenantFilter -AsApp $true)
            } catch {
                Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Failed to read drive permissions: $($_.Exception.Message)" -Sev 'Info'
            }

            $DriveUserPerms = @($DrivePerms | Where-Object {
                ($_.grantedToV2.user.email -or $_.grantedTo.user.email) -and -not $_.link
            })

            if ($IsGroupConnected -and $GroupId) {
                # --- Group-connected: compare M365 Group members vs SP UIL ---
                $GroupMembers = @()
                try {
                    $GroupMembers = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=id,displayName,userPrincipalName,userType" -tenantid $TenantFilter -AsApp $true)
                } catch {
                    Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Failed to read group members: $($_.Exception.Message)" -Sev 'Warning'
                }

                $GroupEmailSet = @{}
                foreach ($m in $GroupMembers) {
                    $email = ($m.userPrincipalName ?? '').ToLower()
                    if ($email) { $GroupEmailSet[$email] = $m }
                }

                # NOT_SYNCED: in group but not in SP UIL
                foreach ($m in $GroupMembers) {
                    $email = ($m.userPrincipalName ?? '').ToLower()
                    if ($email -and -not $UILEmailSet.ContainsKey($email)) {
                        $Issues.Add(@{
                            type         = 'NOT_SYNCED'
                            severity     = 'warning'
                            userEmail    = $m.userPrincipalName
                            userName     = $m.displayName
                            userId       = $m.id
                            description  = "Member of M365 group but not synced to SharePoint. They won't appear in the site until they visit or are synced."
                            repairAction = 'sync_to_sp'
                        })
                    }
                }

                # ORPHANED: in SP UIL but not in group (skip admins and system accounts)
                foreach ($u in $UILUsers) {
                    $email = ($u.fields.EMail ?? '').ToLower()
                    $isAdmin = $u.fields.IsSiteAdmin
                    if ($email -and -not $isAdmin -and -not $GroupEmailSet.ContainsKey($email)) {
                        $Issues.Add(@{
                            type         = 'ORPHANED'
                            severity     = 'info'
                            userEmail    = $u.fields.EMail
                            userName     = $u.fields.Title
                            userId       = $null
                            description  = 'Has SharePoint site access but is not in the M365 group. This may be intentional (direct permission) or leftover from a previous change.'
                            repairAction = 'add_to_group'
                        })
                    }
                }

                # DRIVE_ONLY: has drive invite permission but not in group
                foreach ($dp in $DriveUserPerms) {
                    $dpEmail = (($dp.grantedToV2.user.email ?? $dp.grantedTo.user.email) ?? '').ToLower()
                    $dpName = $dp.grantedToV2.user.displayName ?? $dp.grantedTo.user.displayName ?? $dpEmail
                    if ($dpEmail -and -not $GroupEmailSet.ContainsKey($dpEmail)) {
                        $alreadyReported = $Issues | Where-Object { ($_.userEmail ?? '').ToLower() -eq $dpEmail }
                        if (-not $alreadyReported) {
                            $Issues.Add(@{
                                type              = 'DRIVE_ONLY'
                                severity          = 'warning'
                                userEmail         = $dpEmail
                                userName          = $dpName
                                userId            = $dp.grantedToV2.user.id ?? $dp.grantedTo.user.id
                                drivePermissionId = $dp.id
                                roles             = $dp.roles -join ', '
                                description       = "Has document library access ($($dp.roles -join ', ')) via sharing but is not a member of the M365 group or site."
                                repairAction      = 'promote_to_member'
                            })
                        }
                    }
                }
            } else {
                # --- Non-group site: compare SP role assignments vs drive permissions ---
                $RoleAssignments = @()
                if ($SiteUrl) {
                    try {
                        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                        $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                        $RoleAssignments = @(New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roleassignments?`$expand=Member,RoleDefinitionBindings" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' })
                    } catch {
                        Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Failed to read role assignments: $($_.Exception.Message)" -Sev 'Warning'
                    }
                }

                # Build set of users who have actual site-level role assignments (PrincipalType 1 = User)
                $RoleUserLogins = @{}
                foreach ($ra in $RoleAssignments) {
                    if ($ra.Member.PrincipalType -eq 1) {
                        $loginName = ($ra.Member.LoginName ?? '').ToLower()
                        $memberEmail = ''
                        if ($loginName -match 'membership\|(.+)$') {
                            $memberEmail = $Matches[1].ToLower()
                        }
                        if ($memberEmail) { $RoleUserLogins[$memberEmail] = $ra }
                    }
                }

                # DRIVE_ONLY: has drive invite permission but no site-level role assignment
                foreach ($dp in $DriveUserPerms) {
                    $dpEmail = (($dp.grantedToV2.user.email ?? $dp.grantedTo.user.email) ?? '').ToLower()
                    $dpName = $dp.grantedToV2.user.displayName ?? $dp.grantedTo.user.displayName ?? $dpEmail
                    if ($dpEmail -and -not $RoleUserLogins.ContainsKey($dpEmail)) {
                        $Issues.Add(@{
                            type              = 'DRIVE_ONLY'
                            severity          = 'warning'
                            userEmail         = $dpEmail
                            userName          = $dpName
                            userId            = $dp.grantedToV2.user.id ?? $dp.grantedTo.user.id
                            drivePermissionId = $dp.id
                            roles             = $dp.roles -join ', '
                            description       = "Has document library access ($($dp.roles -join ', ')) via sharing but has no site-level permissions. This was likely created by a fallback when normal member add failed."
                            repairAction      = 'promote_to_member'
                        })
                    }
                }

                # NO_ROLE: in UIL but has no role assignment and no drive permission
                $DriveEmailSet = @{}
                foreach ($dp in $DriveUserPerms) {
                    $dpEmail = (($dp.grantedToV2.user.email ?? $dp.grantedTo.user.email) ?? '').ToLower()
                    if ($dpEmail) { $DriveEmailSet[$dpEmail] = $true }
                }

                foreach ($u in $UILUsers) {
                    $email = ($u.fields.EMail ?? '').ToLower()
                    $isAdmin = $u.fields.IsSiteAdmin
                    if ($email -and -not $isAdmin -and -not $RoleUserLogins.ContainsKey($email) -and -not $DriveEmailSet.ContainsKey($email)) {
                        $Issues.Add(@{
                            type         = 'NO_ROLE'
                            severity     = 'info'
                            userEmail    = $u.fields.EMail
                            userName     = $u.fields.Title
                            userId       = $null
                            description  = 'User appears in the site user list but has no permissions assigned. They were likely added via ensureuser but never granted a role.'
                            repairAction = 'assign_role'
                        })
                    }
                }
            }

            $Results = @{
                siteType   = if ($IsGroupConnected) { 'group-connected' } else { 'standalone' }
                issueCount = $Issues.Count
                issues     = @($Issues)
            }
            $StatusCode = [HttpStatusCode]::OK

        } elseif ($Action -eq 'repair') {
            $RepairType = $Request.Body.repairType
            $UserEmail = $Request.Body.userEmail
            $UserId = $Request.Body.userId
            $DrivePermissionId = $Request.Body.drivePermissionId

            if (-not $RepairType -or -not $UserEmail) {
                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::BadRequest
                    Body       = @{ Results = @{ error = 'repairType and userEmail are required for repair.' } }
                })
            }

            $RepairResults = [System.Collections.Generic.List[string]]::new()

            switch ($RepairType) {
                'sync_to_sp' {
                    if (-not $SiteUrl) { throw 'siteUrl is required for sync_to_sp repair.' }
                    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                    $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                    $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
                    $SPContentType = 'application/json;odata=verbose'
                    $LoginName = "i:0#.f|membership|$UserEmail"
                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $RepairResults.Add("Synced $UserEmail to SharePoint site.")
                    Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "sync_to_sp: ensureuser succeeded for $UserEmail on $SiteUrl" -Sev 'Info'
                }
                'add_to_group' {
                    if (-not $GroupId) { throw 'groupId is required for add_to_group repair.' }
                    $Result = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UserEmail -TenantFilter $TenantFilter -Headers $Headers
                    $RepairResults.Add("Added $UserEmail to M365 group. $Result")

                    if ($SiteUrl) {
                        try {
                            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                            $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                            $LoginName = "i:0#.f|membership|$UserEmail"
                            $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                            $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType 'application/json;odata=verbose' -AddedHeaders @{ 'Accept' = 'application/json;odata=verbose' }
                            $RepairResults.Add('Also synced user to SharePoint site.')
                        } catch {
                            $RepairResults.Add("Note: user may take a few minutes to appear in the site members list.")
                        }
                    }
                    Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "add_to_group: added $UserEmail to group $GroupId" -Sev 'Info'
                }
                'promote_to_member' {
                    if (-not $SiteUrl) { throw 'siteUrl is required for promote_to_member repair.' }
                    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                    $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                    $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
                    $SPContentType = 'application/json;odata=verbose'
                    $LoginName = "i:0#.f|membership|$UserEmail"

                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $EnsuredUser = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $SPUserId = $EnsuredUser.d.Id ?? $EnsuredUser.Id

                    $MemberAdded = $false

                    if ($IsGroupConnected -and $GroupId) {
                        try {
                            $Result = Add-CIPPGroupMember -GroupType 'Team' -GroupID $GroupId -Member $UserEmail -TenantFilter $TenantFilter -Headers $Headers
                            $MemberAdded = $true
                            $RepairResults.Add("Added $UserEmail to M365 group. $Result")
                        } catch {
                            Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "promote_to_member: group add failed, trying direct: $($_.Exception.Message)" -Sev 'Info'
                        }
                    }

                    if (-not $MemberAdded) {
                        # Try associated member group first, then direct role assignment
                        try {
                            $AddBody = ConvertTo-Json @{ LoginName = $LoginName } -Compress
                            $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/associatedmembergroup/users" -Type POST -Body $AddBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                            $MemberAdded = $true
                            $RepairResults.Add("Added $UserEmail to site members group.")
                        } catch {
                            Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "promote_to_member: member group failed: $($_.Exception.Message)" -Sev 'Info'
                        }

                        if (-not $MemberAdded -and $SPUserId) {
                            $RoleDefs = New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roledefinitions" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' }
                            $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 3 } | Select-Object -First 1
                            if (-not $EditRole) {
                                $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 2 } | Select-Object -First 1
                            }
                            if ($EditRole.Id) {
                                $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/roleassignments/addroleassignment(principalid=$SPUserId,roledefid=$($EditRole.Id))" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                                $MemberAdded = $true
                                $RepairResults.Add("Assigned $($EditRole.Name) role to $UserEmail on the site.")
                            }
                        }
                    }

                    if (-not $MemberAdded) {
                        throw "Could not add $UserEmail as a proper site member."
                    }

                    # Remove the drive-only permission now that proper membership is in place
                    if ($DrivePermissionId) {
                        try {
                            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteId/drive/root/permissions/$DrivePermissionId" -tenantid $TenantFilter -type DELETE -body '{}' -AsApp $true
                            $RepairResults.Add('Removed the old document library sharing permission.')
                        } catch {
                            $RepairResults.Add('Note: could not remove the old drive sharing permission. It can be cleaned up manually.')
                            Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Failed to remove drive permission $DrivePermissionId : $($_.Exception.Message)" -Sev 'Info'
                        }
                    }

                    Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "promote_to_member: completed for $UserEmail on $SiteUrl" -Sev 'Info'
                }
                'assign_role' {
                    if (-not $SiteUrl) { throw 'siteUrl is required for assign_role repair.' }
                    $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
                    $SPScope = "$($SharePointInfo.SharePointUrl)/.default"
                    $SPHeaders = @{ 'Accept' = 'application/json;odata=verbose' }
                    $SPContentType = 'application/json;odata=verbose'
                    $LoginName = "i:0#.f|membership|$UserEmail"

                    $EnsureBody = ConvertTo-Json @{ logonName = $LoginName } -Compress
                    $EnsuredUser = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/ensureuser" -Type POST -Body $EnsureBody -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $SPUserId = $EnsuredUser.d.Id ?? $EnsuredUser.Id

                    if (-not $SPUserId) { throw "Could not resolve SharePoint user ID for $UserEmail." }

                    $RoleDefs = New-GraphGetRequest -scope $SPScope -tenantid $TenantFilter -uri "$SiteUrl/_api/web/roledefinitions" -NoAuthCheck $true -extraHeaders @{ 'Accept' = 'application/json' }
                    $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 3 } | Select-Object -First 1
                    if (-not $EditRole) {
                        $EditRole = $RoleDefs | Where-Object { $_.RoleTypeKind -eq 2 } | Select-Object -First 1
                    }
                    if (-not $EditRole.Id) { throw "No suitable role definition found on $SiteUrl." }

                    $null = New-GraphPostRequest -scope $SPScope -tenantid $TenantFilter -Uri "$SiteUrl/_api/web/roleassignments/addroleassignment(principalid=$SPUserId,roledefid=$($EditRole.Id))" -Type POST -Body '{}' -ContentType $SPContentType -AddedHeaders $SPHeaders
                    $RepairResults.Add("Assigned $($EditRole.Name) role to $UserEmail.")
                    Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "assign_role: assigned $($EditRole.Name) to $UserEmail on $SiteUrl" -Sev 'Info'
                }
                'repair_all' {
                    $IssuesToRepair = $Request.Body.issues
                    if (-not $IssuesToRepair -or $IssuesToRepair.Count -eq 0) {
                        throw 'No issues provided for repair_all.'
                    }

                    foreach ($Issue in $IssuesToRepair) {
                        try {
                            $RepairRequest = @{
                                Headers = $Request.Headers
                                Body    = @{
                                    tenantFilter      = $TenantFilter
                                    siteId            = $SiteId
                                    siteUrl           = $SiteUrl
                                    groupId           = $GroupId
                                    sharePointType    = $SharePointType
                                    action            = 'repair'
                                    repairType        = $Issue.repairAction
                                    userEmail         = $Issue.userEmail
                                    userId            = $Issue.userId
                                    drivePermissionId = $Issue.drivePermissionId
                                }
                            }
                            $SubResult = Invoke-ExecSharePointMemberAudit -Request ([PSCustomObject]$RepairRequest) -TriggerMetadata $TriggerMetadata
                            $SubBody = $SubResult.Body
                            if ($SubBody.Results.results) {
                                $RepairResults.AddRange([string[]]$SubBody.Results.results)
                            } else {
                                $RepairResults.Add("Repaired $($Issue.userEmail) ($($Issue.repairAction)).")
                            }
                        } catch {
                            $RepairResults.Add("Failed to repair $($Issue.userEmail): $($_.Exception.Message)")
                            Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "repair_all: failed for $($Issue.userEmail): $($_.Exception.Message)" -Sev 'Warning'
                        }
                    }
                }
                default {
                    throw "Unknown repairType: $RepairType"
                }
            }

            $Results = @{
                action  = 'repair'
                results = @($RepairResults)
            }
            $StatusCode = [HttpStatusCode]::OK

        } else {
            throw "Unknown action: $Action. Use 'audit' or 'repair'."
        }
    } catch {
        $ErrorMsg = $_.Exception.Message
        $NormalizedError = Get-NormalizedError -Message $ErrorMsg
        Write-LogMessage -headers $Headers -API 'ExecSharePointMemberAudit' -tenant $TenantFilter -message "Member audit failed: $ErrorMsg" -Sev 'Error'
        $Results = @{ error = $NormalizedError }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Results }
    })
}
