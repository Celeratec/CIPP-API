function Invoke-ExecTeamFromGroup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.TenantFilter
    $SiteId = $Request.Body.SiteId
    $DisplayName = $Request.Body.DisplayName

    if (-not $TenantFilter) { $TenantFilter = $Request.Query.TenantFilter }
    if (-not $SiteId) { $SiteId = $Request.Query.SiteId }

    $SiteLabel = if ($DisplayName) { $DisplayName } else { $SiteId }

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    if (-not $SiteId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'SiteId is required' }
        })
    }

    try {
        # Step 1: Resolve GroupId from the SharePoint Admin API
        $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
        $SiteInfoUri = "$($SharePointInfo.AdminUrl)/_api/SPO.Tenant/sites('$SiteId')"
        $ExtraHeaders = @{
            'accept'        = 'application/json'
            'content-type'  = 'application/json'
            'odata-version' = '4.0'
        }

        $SiteInfo = New-GraphGETRequest `
            -scope "$($SharePointInfo.AdminUrl)/.default" `
            -uri $SiteInfoUri `
            -tenantid $TenantFilter `
            -extraHeaders $ExtraHeaders

        if (-not $SiteInfo) {
            throw 'Could not retrieve site information from SharePoint Admin API'
        }

        $GroupId = $SiteInfo.GroupId
        $IsGroupConnected = $GroupId -and $GroupId -ne '00000000-0000-0000-0000-000000000000'

        if (-not $IsGroupConnected) {
            $Message = "Site '$SiteLabel' is not connected to a Microsoft 365 Group. Only group-connected sites (Team Sites) can be team-enabled."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Warning
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $Message }
            })
        }

        # Step 2: Check if the group already has a Team
        $GroupInfo = New-GraphGetRequest `
            -uri "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=id,displayName,resourceProvisioningOptions" `
            -tenantid $TenantFilter -asApp $true

        $HasTeam = $GroupInfo.resourceProvisioningOptions -contains 'Team'

        if ($HasTeam) {
            $GroupDisplayName = $GroupInfo.displayName
            $Message = "Site '$SiteLabel' already has a Team ('$GroupDisplayName'). No action needed."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{ Results = $Message }
            })
        }

        # Step 3: Team-enable the group via PUT /groups/{id}/team
        $null = New-GraphPostRequest -AsApp $true `
            -uri "https://graph.microsoft.com/v1.0/groups/$GroupId/team" `
            -tenantid $TenantFilter `
            -type PUT `
            -body '{}'

        $GroupDisplayName = if ($GroupInfo.displayName) { $GroupInfo.displayName } else { $SiteLabel }
        $Message = "Successfully created a Team for '$GroupDisplayName' from SharePoint site '$SiteLabel'. The existing site, membership, and content are preserved. Full Team provisioning may take a few minutes."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to create Team from site '$SiteLabel'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::Forbidden
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Message }
    })
}
