function Invoke-CippTestCIS_1_1_4 {
    <#
    .SYNOPSIS
    Tests CIS M365 7.0.0 (1.1.4) - Administrative accounts SHALL use licenses with a reduced application footprint
    #>
    param($Tenant)

    try {
        $Roles = Get-CippDbRole -TenantFilter $Tenant -IncludePrivilegedRoles
        $RoleAssignmentScheduleInstances = Get-CIPPTestData -TenantFilter $Tenant -Type 'RoleAssignmentScheduleInstances'
        $Users = Get-CIPPTestData -TenantFilter $Tenant -Type 'Users'

        if ($null -eq $Roles -or $null -eq $Users) {
            Add-CippTestResult -TenantFilter $Tenant -TestId 'CIS_1_1_4' -TestType 'Identity' -Status 'Skipped' -ResultMarkdown 'Required cache (Roles or Users) not found. Please refresh the cache for this tenant.' -Risk 'Medium' -Name 'Administrative accounts use licenses with a reduced application footprint' -UserImpact 'Low' -ImplementationEffort 'Medium' -Category 'Privileged Access'
            return
        }

        # SkuPartNumbers that are acceptable for admin accounts: Entra ID P1/P2 only
        $AcceptableSkus = @('AAD_PREMIUM', 'AAD_PREMIUM_P2', 'EMS', 'EMSPREMIUM')

        $PrivilegedRoleIds = [System.Collections.Generic.HashSet[string]]::new()
        $PrivilegedUserIds = [System.Collections.Generic.HashSet[string]]::new()

        foreach ($Role in @($Roles)) {
            $RoleTemplateId = if ($Role.roleTemplateId) { [string]$Role.roleTemplateId } elseif ($Role.RoletemplateId) { [string]$Role.RoletemplateId } else { $null }
            if ($RoleTemplateId) {
                [void]$PrivilegedRoleIds.Add($RoleTemplateId)
            }

            foreach ($Member in @($Role.members)) {
                if ($Member.id) {
                    [void]$PrivilegedUserIds.Add([string]$Member.id)
                }
            }
        }

        foreach ($Assignment in @($RoleAssignmentScheduleInstances)) {
            if ($Assignment.roleDefinitionId -and $Assignment.assignmentType -eq 'Assigned' -and $null -eq $Assignment.endDateTime -and $PrivilegedRoleIds.Contains([string]$Assignment.roleDefinitionId) -and $Assignment.principalId) {
                [void]$PrivilegedUserIds.Add([string]$Assignment.principalId)
            }
        }

        $PrivilegedUsers = $Users | Where-Object { $PrivilegedUserIds.Contains($_.id) }

        $LicensedAdmins = $PrivilegedUsers | Where-Object {
            $_.assignedLicenses -and $_.assignedLicenses.Count -gt 0
        }

        $NonCompliant = $LicensedAdmins | Where-Object {
            $skus = ($_.assignedPlans | ForEach-Object { $_.servicePlanId }) -join ','
            $hasProductivity = $_.assignedPlans | Where-Object { $_.service -in @('exchange', 'SharePoint', 'MicrosoftCommunicationsOnline', 'TeamspaceAPI') -and $_.capabilityStatus -eq 'Enabled' }
            [bool]$hasProductivity
        }

        if (-not $LicensedAdmins) {
            $Status = 'Passed'
            $Result = 'No privileged users have licenses assigned.'
        } elseif (-not $NonCompliant) {
            $Status = 'Passed'
            $Result = "All $($LicensedAdmins.Count) licensed privileged user(s) hold only identity-only licenses (no productivity workloads enabled)."
        } else {
            $Status = 'Failed'
            $Result = "$($NonCompliant.Count) privileged user(s) have productivity workloads (Exchange/SharePoint/Teams/Skype) enabled on their administrative accounts.`n`n"
            $Result += ($NonCompliant | Select-Object -First 25 | ForEach-Object { "- $($_.userPrincipalName)" }) -join "`n"
        }

        Add-CippTestResult -TenantFilter $Tenant -TestId 'CIS_1_1_4' -TestType 'Identity' -Status $Status -ResultMarkdown $Result -Risk 'Medium' -Name 'Administrative accounts use licenses with a reduced application footprint' -UserImpact 'Low' -ImplementationEffort 'Medium' -Category 'Privileged Access'
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Add-CippTestResult -TenantFilter $Tenant -TestId 'CIS_1_1_4' -TestType 'Identity' -Status 'Failed' -ResultMarkdown "Test failed: $($ErrorMessage.NormalizedError)" -Risk 'Medium' -Name 'Administrative accounts use licenses with a reduced application footprint' -UserImpact 'Low' -ImplementationEffort 'Medium' -Category 'Privileged Access'
    }
}
