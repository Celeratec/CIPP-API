function Invoke-ListCrossTenantHealth {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.tenantFilter

    try {
        # Fetch cross-tenant data in bulk for health analysis
        $Requests = @(
            @{
                id     = 'defaultPolicy'
                url    = 'policies/crossTenantAccessPolicy/default'
                method = 'GET'
            }
            @{
                id     = 'partners'
                url    = 'policies/crossTenantAccessPolicy/partners'
                method = 'GET'
            }
        )

        $BulkResults = New-GraphBulkRequest -Requests $Requests -tenantid $TenantFilter -asapp $true

        $DefaultPolicy = ($BulkResults | Where-Object { $_.id -eq 'defaultPolicy' }).body
        $Partners = ($BulkResults | Where-Object { $_.id -eq 'partners' }).body.value

        # Fetch authorization policy separately (must use /authorizationPolicy/authorizationPolicy to get the object, not the collection)
        $AuthPolicy = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -tenantid $TenantFilter -AsApp $true

        # Fetch SharePoint settings for cross-service domain restriction checks
        $SPOSettings = $null
        try {
            $SPOSettings = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -tenantid $TenantFilter -AsApp $true
        } catch {
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Could not get SharePoint settings for health check (non-critical): $($_.Exception.Message)" -Sev 'Debug'
        }

        # Analyze configuration and detect issues
        $Findings = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Check 1: B2B Collaboration - Inbound defaults
        $InboundCollabAccess = $DefaultPolicy.b2bCollaborationInbound.usersAndGroups.accessType
        if ($InboundCollabAccess -eq 'allowed' -and
            ($DefaultPolicy.b2bCollaborationInbound.usersAndGroups.targets | Where-Object { $_.target -eq 'AllUsers' })) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'B2B Collaboration'
                Area           = 'Inbound'
                Severity       = 'Warning'
                Finding        = 'Inbound B2B collaboration allows all external users by default.'
                Recommendation = 'Consider restricting inbound collaboration to specific organizations.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }

        # Check 2: B2B Collaboration - Outbound defaults
        $OutboundCollabAccess = $DefaultPolicy.b2bCollaborationOutbound.usersAndGroups.accessType
        if ($OutboundCollabAccess -eq 'allowed' -and
            ($DefaultPolicy.b2bCollaborationOutbound.usersAndGroups.targets | Where-Object { $_.target -eq 'AllUsers' })) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'B2B Collaboration'
                Area           = 'Outbound'
                Severity       = 'Info'
                Finding        = 'Outbound B2B collaboration allows all internal users by default.'
                Recommendation = 'Review if all users should be able to collaborate externally.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }

        # Check 3: B2B Direct Connect defaults
        $InboundDCAccess = $DefaultPolicy.b2bDirectConnectInbound.usersAndGroups.accessType
        if ($InboundDCAccess -eq 'allowed' -and
            ($DefaultPolicy.b2bDirectConnectInbound.usersAndGroups.targets | Where-Object { $_.target -eq 'AllUsers' })) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'B2B Direct Connect'
                Area           = 'Inbound'
                Severity       = 'Warning'
                Finding        = 'B2B Direct Connect allows all external users inbound by default.'
                Recommendation = 'Restrict Direct Connect to specific partner organizations for Teams shared channels.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }

        # Check 4: Inbound Trust settings
        if (-not $DefaultPolicy.inboundTrust.isMfaAccepted) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'Inbound Trust'
                Area           = 'MFA'
                Severity       = 'Info'
                Finding        = 'External MFA is not trusted. Guest users must re-authenticate with your MFA.'
                Recommendation = 'Consider trusting external MFA to reduce friction for B2B guests.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }
        if (-not $DefaultPolicy.inboundTrust.isCompliantDeviceAccepted) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'Inbound Trust'
                Area           = 'Device Compliance'
                Severity       = 'Info'
                Finding        = 'External device compliance claims are not trusted.'
                Recommendation = 'Consider trusting compliant device claims from partner organizations.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }

        # Check 5: Tenant Restrictions
        $TenantRestrictionsUsers = $DefaultPolicy.tenantRestrictions.usersAndGroups.accessType
        if ($null -eq $TenantRestrictionsUsers -or $TenantRestrictionsUsers -eq 'allowed') {
            $Findings.Add([PSCustomObject]@{
                Category       = 'Tenant Restrictions'
                Area           = 'Defaults'
                Severity       = 'Info'
                Finding        = 'Tenant Restrictions v2 defaults are not configured or allow all.'
                Recommendation = 'Configure Tenant Restrictions to control which external tenants users can access.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/policy'
                RelatedPage    = 'Cross-Tenant Default Policy'
            })
        }

        # Check 6: Guest invite settings
        if ($AuthPolicy.allowInvitesFrom -eq 'everyone') {
            $Findings.Add([PSCustomObject]@{
                Category       = 'External Collaboration'
                Area           = 'Guest Invites'
                Severity       = 'Warning'
                Finding        = 'Anyone in the organization (including guests) can invite guest users.'
                Recommendation = 'Restrict guest invitation permissions to admins or the Guest Inviter role.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/external-collaboration'
                RelatedPage    = 'External Collaboration'
            })
        }

        # Check 7: Guest invite blocked
        if ($AuthPolicy.allowInvitesFrom -eq 'none') {
            $Findings.Add([PSCustomObject]@{
                Category       = 'External Collaboration'
                Area           = 'Guest Invites'
                Severity       = 'Warning'
                Finding        = 'Guest invitations are completely disabled. No one can invite external guests.'
                Recommendation = 'If external collaboration is needed, allow at least admins to invite guests.'
                RelatedLink    = '/tenant/administration/cross-tenant-access/external-collaboration'
                RelatedPage    = 'External Collaboration'
            })
        }

        # Check 8: Guest user role
        $RestrictedGuestRoleId = '2af84b1e-32c8-42b7-82bc-daa82404023b'
        $DefaultGuestRoleId = '10dae51f-b6af-4016-8d66-8c2a99b929b3'
        if ($AuthPolicy.guestUserRoleId -ne $RestrictedGuestRoleId -and $AuthPolicy.guestUserRoleId -ne $DefaultGuestRoleId) {
            $Findings.Add([PSCustomObject]@{
                Category       = 'External Collaboration'
                Area           = 'Guest Permissions'
                Severity       = 'Warning'
                Finding        = 'Guest users have the same access as member users.'
                Recommendation = 'Set guest user permissions to "Guest User" or "Restricted Guest User".'
                RelatedLink    = '/tenant/administration/cross-tenant-access/external-collaboration'
                RelatedPage    = 'External Collaboration'
            })
        }

        # Check 9: Partner configuration conflicts
        if ($Partners -and $Partners.Count -gt 0) {
            foreach ($Partner in $Partners) {
                # Check if partner has more permissive settings than default
                $PartnerInbound = $Partner.b2bCollaborationInbound.usersAndGroups.accessType
                if ($PartnerInbound -eq 'allowed' -and $InboundCollabAccess -eq 'blocked') {
                    $Findings.Add([PSCustomObject]@{
                        Category       = 'Configuration Conflict'
                        Area           = "Partner: $($Partner.tenantId)"
                        Severity       = 'Info'
                        Finding        = "Partner $($Partner.tenantId) has inbound B2B allowed while defaults block it."
                        Recommendation = 'Verify this partner exception is intentional.'
                        RelatedLink    = '/tenant/administration/cross-tenant-access/partners'
                        RelatedPage    = 'Partner Organizations'
                    })
                }
            }
        }

        # Check 10: SharePoint sharing domain restrictions
        if ($SPOSettings) {
            $SPODomainMode = $SPOSettings.sharingDomainRestrictionMode
            if ($SPODomainMode -eq 'allowList') {
                $DomainCount = ($SPOSettings.sharingAllowedDomainList | Measure-Object).Count
                $Findings.Add([PSCustomObject]@{
                    Category       = 'SharePoint Sharing'
                    Area           = 'Domain Restrictions'
                    Severity       = 'Info'
                    Finding        = "SharePoint sharing is restricted to an allow list of $DomainCount domain(s). External users from unlisted domains cannot receive SharePoint/OneDrive sharing invitations."
                    Recommendation = 'Ensure all required partner domains are included in the SharePoint allowed domains list. Note: this is a separate list from Entra External Collaboration domain restrictions.'
                    RelatedLink    = '/teams-share/sharepoint/sharing-settings'
                    RelatedPage    = 'SharePoint Sharing Settings'
                })
            } elseif ($SPODomainMode -eq 'blockList') {
                $DomainCount = ($SPOSettings.sharingBlockedDomainList | Measure-Object).Count
                $Findings.Add([PSCustomObject]@{
                    Category       = 'SharePoint Sharing'
                    Area           = 'Domain Restrictions'
                    Severity       = 'Info'
                    Finding        = "SharePoint sharing blocks $DomainCount domain(s). External users from blocked domains cannot receive SharePoint/OneDrive sharing invitations."
                    Recommendation = 'Review the blocked domains list to ensure no required partners are blocked.'
                    RelatedLink    = '/teams-share/sharepoint/sharing-settings'
                    RelatedPage    = 'SharePoint Sharing Settings'
                })
            }

            # Check 11: SharePoint sharing capability
            if ($SPOSettings.sharingCapability -eq 'disabled') {
                $Findings.Add([PSCustomObject]@{
                    Category       = 'SharePoint Sharing'
                    Area           = 'Sharing Level'
                    Severity       = 'Warning'
                    Finding        = 'SharePoint external sharing is completely disabled. No files or sites can be shared externally regardless of other settings.'
                    Recommendation = 'If external collaboration via SharePoint is needed, set the sharing level to at least "Existing guests".'
                    RelatedLink    = '/teams-share/sharepoint/sharing-settings'
                    RelatedPage    = 'SharePoint Sharing Settings'
                })
            }
        }

        # Calculate overall health score
        $CriticalCount = ($Findings | Where-Object { $_.Severity -eq 'Critical' }).Count
        $WarningCount = ($Findings | Where-Object { $_.Severity -eq 'Warning' }).Count
        $InfoCount = ($Findings | Where-Object { $_.Severity -eq 'Info' }).Count

        $HealthScore = 100
        $HealthScore -= ($CriticalCount * 25)
        $HealthScore -= ($WarningCount * 10)
        $HealthScore -= ($InfoCount * 2)
        if ($HealthScore -lt 0) { $HealthScore = 0 }

        $HealthStatus = if ($HealthScore -ge 80) { 'Healthy' }
                        elseif ($HealthScore -ge 60) { 'Needs Attention' }
                        elseif ($HealthScore -ge 40) { 'At Risk' }
                        else { 'Critical' }

        $Result = [PSCustomObject]@{
            Tenant        = $TenantFilter
            HealthScore   = $HealthScore
            HealthStatus  = $HealthStatus
            CriticalCount = $CriticalCount
            WarningCount  = $WarningCount
            InfoCount     = $InfoCount
            PartnerCount  = if ($Partners) { $Partners.Count } else { 0 }
            Findings      = @($Findings)
            Summary       = [PSCustomObject]@{
                b2bCollaborationInbound  = $DefaultPolicy.b2bCollaborationInbound.usersAndGroups.accessType ?? 'Not configured'
                b2bCollaborationOutbound = $DefaultPolicy.b2bCollaborationOutbound.usersAndGroups.accessType ?? 'Not configured'
                b2bDirectConnectInbound  = $DefaultPolicy.b2bDirectConnectInbound.usersAndGroups.accessType ?? 'Not configured'
                b2bDirectConnectOutbound = $DefaultPolicy.b2bDirectConnectOutbound.usersAndGroups.accessType ?? 'Not configured'
                trustExternalMFA         = $DefaultPolicy.inboundTrust.isMfaAccepted ?? $false
                trustCompliantDevices    = $DefaultPolicy.inboundTrust.isCompliantDeviceAccepted ?? $false
                trustHybridJoinedDevices = $DefaultPolicy.inboundTrust.isHybridAzureADJoinedDeviceAccepted ?? $false
                guestInvitePolicy        = $AuthPolicy.allowInvitesFrom ?? 'Not configured'
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = $Result
        }
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Failed to generate cross-tenant health report: $ErrorMessage" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = [PSCustomObject]@{
            Results = "Failed to generate cross-tenant health report: $ErrorMessage"
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
