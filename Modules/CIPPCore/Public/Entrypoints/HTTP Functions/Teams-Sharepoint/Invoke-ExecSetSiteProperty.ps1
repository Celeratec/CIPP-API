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

        # Lock State
        if ($Request.Body.LockState) {
            $LockStateMap = @{
                'Unlock'    = 0
                'NoAccess'  = 1
                'ReadOnly'  = 2
            }
            $LockValue = $LockStateMap[$Request.Body.LockState]
            if ($null -eq $LockValue) {
                throw "Invalid LockState '$($Request.Body.LockState)'. Valid values: Unlock, NoAccess, ReadOnly"
            }
            $PropertiesToSet['LockState'] = $LockValue
            $ActionDescription = "Set lock state to '$($Request.Body.LockState)'"
        }

        # Sharing Capability
        if ($null -ne $Request.Body.SharingCapability) {
            $SharingLabels = @{
                0 = 'Disabled'
                1 = 'ExternalUserSharingOnly'
                2 = 'ExternalUserAndGuestSharing'
                3 = 'ExistingExternalUserSharingOnly'
            }
            $SharingValue = [int]$Request.Body.SharingCapability
            if ($SharingValue -notin 0, 1, 2, 3) {
                throw "Invalid SharingCapability '$SharingValue'. Valid values: 0 (Disabled), 1 (ExternalUserSharingOnly), 2 (ExternalUserAndGuestSharing), 3 (ExistingExternalUserSharingOnly)"
            }
            $PropertiesToSet['SharingCapability'] = $SharingValue
            $ActionDescription = "Set sharing capability to '$($SharingLabels[$SharingValue])'"
        }

        # Storage Quota
        if ($null -ne $Request.Body.StorageMaximumLevel) {
            $MaxLevel = [long]$Request.Body.StorageMaximumLevel
            if ($MaxLevel -le 0) {
                throw 'StorageMaximumLevel must be a positive number (in MB)'
            }
            $PropertiesToSet['StorageMaximumLevel'] = $MaxLevel

            if ($null -ne $Request.Body.StorageWarningLevel) {
                $WarnLevel = [long]$Request.Body.StorageWarningLevel
                if ($WarnLevel -lt 0 -or $WarnLevel -ge $MaxLevel) {
                    throw 'StorageWarningLevel must be between 0 and StorageMaximumLevel'
                }
                $PropertiesToSet['StorageWarningLevel'] = $WarnLevel
            } else {
                # Default warning at 90% of max
                $PropertiesToSet['StorageWarningLevel'] = [long]($MaxLevel * 0.9)
            }
            $ActionDescription = "Set storage quota to $($MaxLevel) MB (warning at $($PropertiesToSet['StorageWarningLevel']) MB)"
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
