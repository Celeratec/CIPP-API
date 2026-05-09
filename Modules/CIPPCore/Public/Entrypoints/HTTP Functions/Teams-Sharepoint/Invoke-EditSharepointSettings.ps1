function Invoke-EditSharepointSettings {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Admin.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter

    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        $PatchBody = @{}

        # Sharing capability (main sharing level)
        if ($null -ne $Request.Body.sharingCapability) {
            $PatchBody['sharingCapability'] = $Request.Body.sharingCapability
        }

        # Domain restriction mode
        if ($null -ne $Request.Body.sharingDomainRestrictionMode) {
            $PatchBody['sharingDomainRestrictionMode'] = $Request.Body.sharingDomainRestrictionMode

            if ($Request.Body.sharingDomainRestrictionMode -eq 'allowList') {
                $PatchBody['sharingAllowedDomainList'] = @($Request.Body.sharingAllowedDomainList)
            } elseif ($Request.Body.sharingDomainRestrictionMode -eq 'blockList') {
                $PatchBody['sharingBlockedDomainList'] = @($Request.Body.sharingBlockedDomainList)
            }
        }

        # External resharing
        if ($null -ne $Request.Body.isResharingByExternalUsersEnabled) {
            $PatchBody['isResharingByExternalUsersEnabled'] = [bool]$Request.Body.isResharingByExternalUsersEnabled
        }

        # Default sharing link type
        if ($null -ne $Request.Body.defaultSharingLinkType) {
            $PatchBody['defaultSharingLinkType'] = $Request.Body.defaultSharingLinkType
        }

        # Default link permission
        if ($null -ne $Request.Body.defaultLinkPermission) {
            $PatchBody['defaultLinkPermission'] = $Request.Body.defaultLinkPermission
        }

        # File and folder links (anonymous link settings)
        if ($null -ne $Request.Body.fileAnonymousLinkType) {
            $PatchBody['fileAnonymousLinkType'] = $Request.Body.fileAnonymousLinkType
        }
        if ($null -ne $Request.Body.folderAnonymousLinkType) {
            $PatchBody['folderAnonymousLinkType'] = $Request.Body.folderAnonymousLinkType
        }

        # Anyone link expiration
        if ($null -ne $Request.Body.requireAnonymousLinksExpireInDays) {
            $PatchBody['requireAnonymousLinksExpireInDays'] = [int]$Request.Body.requireAnonymousLinksExpireInDays
        }

        if ($PatchBody.Count -eq 0) {
            throw 'No valid settings provided to update.'
        }

        $PatchJSON = ConvertTo-Json -Depth 10 -InputObject $PatchBody -Compress
        $null = New-GraphPostRequest -tenantid $TenantFilter -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true -Type PATCH -Body $PatchJSON -ContentType 'application/json'

        $Results.Add('Successfully updated SharePoint sharing settings.')
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($Results -join ' ') -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = ($Results -join ' ')
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to update SharePoint sharing settings: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to update SharePoint sharing settings: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
