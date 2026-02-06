Function Invoke-ListTeams {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Query.TenantFilter
    if ($request.query.type -eq 'List') {
        $Groups = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName,description,visibility,mailNickname" -tenantid $TenantFilter | Sort-Object -Property displayName

        # Fetch isArchived, memberCount, and channelCount via batch requests for richer list data
        try {
            $TeamBatchRequests = $Groups | ForEach-Object {
                @{
                    id     = $_.id
                    method = 'GET'
                    url    = "/teams/$($_.id)?`$select=isArchived"
                }
            }

            $TeamDetails = if ($TeamBatchRequests.Count -gt 0) {
                New-GraphBulkRequest -Requests $TeamBatchRequests -tenantid $TenantFilter -asapp $true
            } else { @() }

            # Build a lookup for team details
            $TeamLookup = @{}
            foreach ($result in $TeamDetails) {
                if ($result.body -and $result.id) {
                    $TeamLookup[$result.id] = $result.body
                }
            }
        } catch {
            Write-Host "Warning: Could not fetch team details batch: $_"
            $TeamLookup = @{}
        }

        # Merge group data with team details
        $GraphRequest = $Groups | ForEach-Object {
            $details = $TeamLookup[$_.id]
            [PSCustomObject]@{
                id           = $_.id
                displayName  = $_.displayName
                description  = $_.description
                visibility   = $_.visibility
                mailNickname = $_.mailNickname
                isArchived   = if ($null -ne $details.isArchived) { $details.isArchived } else { $false }
            }
        }
    }
    $TeamID = $request.query.ID
    Write-Host $TeamID
    if ($request.query.type -eq 'Team') {
        $Team = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/teams/$($TeamID)" -tenantid $TenantFilter -asapp $true
        $Channels = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/teams/$($TeamID)/Channels" -tenantid $TenantFilter -asapp $true
        $UserList = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/teams/$($TeamID)/Members" -tenantid $TenantFilter -asapp $true
        $AppsList = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/teams/$($TeamID)/installedApps?`$expand=teamsAppDefinition" -tenantid $TenantFilter -asapp $true

        # Fetch the SharePoint site URL from the associated group
        $SharePointUrl = $null
        try {
            $GroupSites = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/groups/$($TeamID)/sites/root?`$select=webUrl,name" -tenantid $TenantFilter -asapp $true
            if ($GroupSites.webUrl) {
                $SharePointUrl = $GroupSites.webUrl
            }
        } catch {
            Write-Host "Warning: Could not fetch SharePoint site URL for team $TeamID`: $_"
        }

        $Owners = $UserList | Where-Object -Property Roles -EQ 'Owner'
        $Members = $UserList | Where-Object -Property email -NotIn $owners.email
        $GraphRequest = [PSCustomObject]@{
            Name          = $team.DisplayName
            TeamInfo      = @($team)
            ChannelInfo   = @($channels)
            Members       = @($Members)
            Owners        = @($owners)
            InstalledApps = @($AppsList)
            SharePointUrl = $SharePointUrl
        }
    }


    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @($GraphRequest)
        })

}
