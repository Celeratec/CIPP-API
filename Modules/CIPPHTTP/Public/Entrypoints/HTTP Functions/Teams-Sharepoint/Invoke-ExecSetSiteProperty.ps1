function Invoke-ExecSetSiteProperty {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $SiteId = $Request.Body.SiteId
    $DisplayName = $Request.Body.DisplayName

    try {
        if (-not $SiteId) {
            throw 'SiteId is required'
        }
        if (-not $TenantFilter) {
            throw 'TenantFilter is required'
        }

        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
        $ExtraHeaders = @{
            'accept'        = 'application/json'
            'content-type'  = 'application/json'
            'odata-version' = '4.0'
        }

        $SiteLabel = if ($DisplayName) { $DisplayName } else { $SiteId }
        $PatchUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/sites('$SiteId')"
        $PropertiesToSet = @{}
        $ActionDescription = ''

        # Helper: autoComplete fields may arrive as { label, value } objects — extract the value
        function Get-FieldValue($Field) {
            if ($Field -is [PSCustomObject] -and $null -ne $Field.value) {
                return $Field.value
            }
            return $Field
        }

        # Lock State
        $RawLockState = Get-FieldValue $Request.Body.LockState
        if ($RawLockState) {
            $LockStateMap = @{
                'Unlock'    = 0
                'NoAccess'  = 1
                'ReadOnly'  = 2
            }
            $LockValue = $LockStateMap[$RawLockState]
            if ($null -eq $LockValue) {
                throw "Invalid LockState '$RawLockState'. Valid values: Unlock, NoAccess, ReadOnly"
            }
            $PropertiesToSet['LockState'] = $LockValue
            $ActionDescription = "Set lock state to '$RawLockState'"
        }

        # Sharing Capability
        $RawSharing = Get-FieldValue $Request.Body.SharingCapability
        if ($null -ne $RawSharing -and '' -ne $RawSharing) {
            $SharingLabels = @{
                0 = 'Disabled'
                1 = 'ExternalUserSharingOnly'
                2 = 'ExternalUserAndGuestSharing'
                3 = 'ExistingExternalUserSharingOnly'
            }
            $SharingValue = [int]$RawSharing
            if ($SharingValue -notin 0, 1, 2, 3) {
                throw "Invalid SharingCapability '$SharingValue'. Valid values: 0 (Disabled), 1 (ExternalUserSharingOnly), 2 (ExternalUserAndGuestSharing), 3 (ExistingExternalUserSharingOnly)"
            }
            $PropertiesToSet['SharingCapability'] = $SharingValue
            $ActionDescription = "Set sharing capability to '$($SharingLabels[$SharingValue])'"
        }

        # Storage Quota (accepts GB, converts to MB for the API)
        if ($null -ne $Request.Body.StorageMaximumLevelGB -and '' -ne $Request.Body.StorageMaximumLevelGB) {
            $MaxGB = [double]$Request.Body.StorageMaximumLevelGB
            if ($MaxGB -le 0) {
                throw 'StorageMaximumLevelGB must be a positive number'
            }
            $MaxLevel = [long]($MaxGB * 1024)
            $PropertiesToSet['StorageMaximumLevel'] = $MaxLevel

            if ($null -ne $Request.Body.StorageWarningLevelGB -and '' -ne $Request.Body.StorageWarningLevelGB) {
                $WarnGB = [double]$Request.Body.StorageWarningLevelGB
                $WarnLevel = [long]($WarnGB * 1024)
                if ($WarnLevel -lt 0 -or $WarnLevel -ge $MaxLevel) {
                    throw 'StorageWarningLevelGB must be between 0 and StorageMaximumLevelGB'
                }
                $PropertiesToSet['StorageWarningLevel'] = $WarnLevel
            } else {
                # Default warning at 90% of max
                $PropertiesToSet['StorageWarningLevel'] = [long]($MaxLevel * 0.9)
            }
            $ActionDescription = "Set storage quota to $($MaxGB) GB (warning at $([math]::Round($PropertiesToSet['StorageWarningLevel'] / 1024, 2)) GB)"
        }

        if ($PropertiesToSet.Count -eq 0) {
            throw 'No valid properties specified. Provide one of: LockState, SharingCapability, StorageMaximumLevel'
        }

        $PatchBody = $PropertiesToSet | ConvertTo-Json -Depth 5
        $null = New-GraphPOSTRequest `
            -scope "$($SharePointInfo.AdminUrl)/.default" `
            -uri $PatchUri `
            -body $PatchBody `
            -tenantid $TenantFilter `
            -type PATCH `
            -AddedHeaders $ExtraHeaders

        $Results = "Successfully updated site '$SiteLabel': $ActionDescription"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Results }
        })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = $ErrorMessage.NormalizedError
        $Results = "Failed to update site property for '$SiteLabel'. Error: $ErrorText"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = $Results }
        })
    }
}
