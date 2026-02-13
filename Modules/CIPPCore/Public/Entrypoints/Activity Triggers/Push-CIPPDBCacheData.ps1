function Push-CIPPDBCacheData {
    <#
    .SYNOPSIS
        Orchestrator function to collect and cache all data for a single tenant

    .DESCRIPTION
        Builds a dynamic batch of cache collection tasks based on tenant license capabilities

    .FUNCTIONALITY
        Entrypoint
    #>
    [CmdletBinding()]
    param($Item)
    Write-Host "Starting cache collection orchestration for tenant: $($Item.TenantFilter) - Queue: $($Item.QueueName) (ID: $($Item.QueueId))"
    $TenantFilter = $Item.TenantFilter
    $QueueId = $Item.QueueId

    try {
        Write-Information "CIPPDBCache: Starting database cache orchestration for tenant $TenantFilter"

        # Check tenant capabilities for license-specific features
        $IntuneCapable = Test-CIPPStandardLicense -StandardName 'IntuneLicenseCheck' -TenantFilter $TenantFilter -RequiredCapabilities @('INTUNE_A', 'MDM_Services', 'EMS', 'SCCM', 'MICROSOFTINTUNEPLAN1') -SkipLog
        $ConditionalAccessCapable = Test-CIPPStandardLicense -StandardName 'ConditionalAccessLicenseCheck' -TenantFilter $TenantFilter -RequiredCapabilities @('AAD_PREMIUM', 'AAD_PREMIUM_P2') -SkipLog
        $AzureADPremiumP2Capable = Test-CIPPStandardLicense -StandardName 'AzureADPremiumP2LicenseCheck' -TenantFilter $TenantFilter -RequiredCapabilities @('AAD_PREMIUM_P2') -SkipLog
        $ExchangeCapable = Test-CIPPStandardLicense -StandardName 'ExchangeLicenseCheck' -TenantFilter $TenantFilter -RequiredCapabilities @('EXCHANGE_S_STANDARD', 'EXCHANGE_S_ENTERPRISE', 'EXCHANGE_S_STANDARD_GOV', 'EXCHANGE_S_ENTERPRISE_GOV', 'EXCHANGE_LITE') -SkipLog
        $DefenderForOffice365Capable = Test-CIPPStandardLicense -StandardName 'DefenderForOffice365LicenseCheck' -TenantFilter $TenantFilter -RequiredCapabilities @('ATP_ENTERPRISE', 'THREAT_INTELLIGENCE') -SkipLog

        Write-Information "CIPPDBCache: $TenantFilter - License capabilities - Intune: $IntuneCapable, CA: $ConditionalAccessCapable, P2: $AzureADPremiumP2Capable, Exchange: $ExchangeCapable, MDO: $DefenderForOffice365Capable"

        # Build dynamic batch of cache collection tasks based on license capabilities
        $Batch = [System.Collections.Generic.List[object]]::new()

        #region All Licenses - Basic tenant data collection
        $BasicCacheFunctions = @(
            'Users'
            'Groups'
            'Guests'
            'ServicePrincipals'
            'Apps'
            'Devices'
            'Organization'
            'Roles'
            'AdminConsentRequestPolicy'
            'AuthorizationPolicy'
            'AuthenticationMethodsPolicy'
            'DeviceSettings'
            'DirectoryRecommendations'
            'CrossTenantAccessPolicy'
            'DefaultAppManagementPolicy'
            'Settings'
            'SecureScore'
            'Domains'
            'B2BManagementPolicy'
            'AuthenticationFlowsPolicy'
            'DeviceRegistrationPolicy'
            'CredentialUserRegistrationDetails'
            'UserRegistrationDetails'
            'OAuth2PermissionGrants'
            'AppRoleAssignments'
            'LicenseOverview'
            'MFAState'
        )

        foreach ($CacheFunction in $BasicCacheFunctions) {
            $Batch.Add(@{
                    FunctionName = 'ExecCIPPDBCache'
                    Name         = $CacheFunction
                    TenantFilter = $TenantFilter
                    QueueId      = $QueueId
                })
        }
        #endregion All Licenses

        #region Exchange Licensed - Exchange Online features
        if ($ExchangeCapable) {
            $ExchangeCacheFunctions = @(
                'ExoAntiPhishPolicies'
                'ExoMalwareFilterPolicies'
                'ExoTransportRules'
                'ExoDkimSigningConfig'
                'ExoOrganizationConfig'
                'ExoAcceptedDomains'
                'ExoHostedContentFilterPolicy'
                'ExoHostedOutboundSpamFilterPolicy'
                'ExoAntiPhishPolicy'
                'ExoMalwareFilterPolicy'
                'ExoQuarantinePolicy'
                'ExoRemoteDomain'
                'ExoSharingPolicy'
                'ExoAdminAuditLogConfig'
                'ExoTenantAllowBlockList'
                'Mailboxes'
                'CASMailboxes'
                'MailboxUsage'
                'OneDriveUsage'
            )

            foreach ($CacheFunction in $ExchangeCacheFunctions) {
                $Batch.Add(@{
                        FunctionName = 'ExecCIPPDBCache'
                        Name         = $CacheFunction
                        TenantFilter = $TenantFilter
                        QueueId      = $QueueId
                    })
            }

            #region Defender for Office 365 Licensed - ATP/MDO features (requires Exchange + MDO)
            if ($DefenderForOffice365Capable) {
                $MdoCacheFunctions = @(
                    'ExoSafeLinksPolicies'
                    'ExoSafeAttachmentPolicies'
                    'ExoSafeLinksPolicy'
                    'ExoSafeAttachmentPolicy'
                    'ExoAtpPolicyForO365'
                    'ExoPresetSecurityPolicy'
                )

                foreach ($CacheFunction in $MdoCacheFunctions) {
                    $Batch.Add(@{
                            FunctionName = 'ExecCIPPDBCache'
                            Name         = $CacheFunction
                            TenantFilter = $TenantFilter
                            QueueId      = $QueueId
                        })
                }
            } else {
                Write-Host 'Skipping Defender for Office 365 data collection - tenant does not have required license'
            }
            #endregion Defender for Office 365 Licensed
        } else {
            Write-Host 'Skipping Exchange Online data collection - tenant does not have required license'
        }
        #endregion Exchange Licensed

        #region Conditional Access Licensed - Azure AD Premium features
        if ($ConditionalAccessCapable) {
            $Batch.Add(@{
                    FunctionName = 'ExecCIPPDBCache'
                    Name         = 'ConditionalAccessPolicies'
                    TenantFilter = $TenantFilter
                    QueueId      = $QueueId
                })
        } else {
            Write-Host 'Skipping Conditional Access data collection - tenant does not have required license'
        }
        #endregion Conditional Access Licensed

        #region Azure AD Premium P2 - Identity Protection and PIM features
        if ($AzureADPremiumP2Capable) {
            $P2CacheFunctions = @(
                'RiskyUsers'
                'RiskyServicePrincipals'
                'ServicePrincipalRiskDetections'
                'RiskDetections'
                'PIMSettings'
                'RoleEligibilitySchedules'
                'RoleManagementPolicies'
                'RoleAssignmentScheduleInstances'
            )
            foreach ($CacheFunction in $P2CacheFunctions) {
                $Batch.Add(@{
                        FunctionName = 'ExecCIPPDBCache'
                        Name         = $CacheFunction
                        TenantFilter = $TenantFilter
                        QueueId      = $QueueId
                    })
            }
        } else {
            Write-Host 'Skipping Azure AD Premium P2 Identity Protection and PIM data collection - tenant does not have required license'
        }
        #endregion Azure AD Premium P2

        #region Intune Licensed - Intune management features
        if ($IntuneCapable) {
            $IntuneCacheFunctions = @(
                'ManagedDevices'
                'IntunePolicies'
                'ManagedDeviceEncryptionStates'
                'IntuneAppProtectionPolicies'
            )
            foreach ($CacheFunction in $IntuneCacheFunctions) {
                $Batch.Add(@{
                        FunctionName = 'ExecCIPPDBCache'
                        Name         = $CacheFunction
                        TenantFilter = $TenantFilter
                        QueueId      = $QueueId
                    })
            }
        } else {
            Write-Host 'Skipping Intune data collection - tenant does not have required license'
        }
        #endregion Intune Licensed

        Write-Information "Built batch of $($Batch.Count) cache collection activities for tenant $TenantFilter"

        # Start orchestration for this tenant's cache collection
        $InputObject = [PSCustomObject]@{
            OrchestratorName = "CIPPDBCacheTenant_$TenantFilter"
            Batch            = @($Batch)
            SkipLog          = $true
        }

        if ($Item.TestRun -eq $true) {
            $InputObject | Add-Member -NotePropertyName PostExecution -NotePropertyValue @{
                FunctionName = 'CIPPDBTestsRun'
                Parameters   = @{
                    TenantFilter = $TenantFilter
                }
            }
        }

        $InstanceId = Start-NewOrchestration -FunctionName 'CIPPOrchestrator' -InputObject ($InputObject | ConvertTo-Json -Depth 5 -Compress)
        Write-Information "CIPPDBCache: Started cache collection for $TenantFilter ($($Batch.Count) activities) ID='$InstanceId'"

        return @{
            InstanceId = $InstanceId
            BatchCount = $Batch.Count
            Message    = "Cache collection orchestration started for $TenantFilter"
        }

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to start cache collection orchestration: $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
        throw $ErrorMessage
    }
}
