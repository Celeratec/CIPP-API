Function Invoke-AddTeam {
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

    # Interact with the body of the request
    $TeamObj = $Request.Body
    $TenantID = $TeamObj.tenantid

    $Owners = ($TeamObj.owner)
    try {
        if ($null -eq $Owners) {
            throw 'You have to add at least one owner to the team'
        }

        # Build owner member - Graph API only allows ONE member during team creation
        $OwnerUPN = @($Owners)[0]
        $OwnerMember = @{
            '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
            'roles'           = @('owner')
            'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$OwnerUPN')"
        }

        # Determine template
        $TemplateName = if ($TeamObj.templateName) { $TeamObj.templateName } else { 'standard' }

        # Build team settings object - only include the owner during creation
        $TeamsSettings = [ordered]@{
            'template@odata.bind' = "https://graph.microsoft.com/v1.0/teamsTemplates('$TemplateName')"
            'visibility'          = $TeamObj.visibility
            'displayName'         = $TeamObj.displayName
            'description'         = $TeamObj.description
            'members'             = @($OwnerMember)
        }

        # Add member settings if provided
        if ($null -ne $TeamObj.allowCreateUpdateChannels -or
            $null -ne $TeamObj.allowDeleteChannels -or
            $null -ne $TeamObj.allowAddRemoveApps -or
            $null -ne $TeamObj.allowCreatePrivateChannels -or
            $null -ne $TeamObj.allowCreateUpdateRemoveTabs -or
            $null -ne $TeamObj.allowCreateUpdateRemoveConnectors) {

            $MemberSettings = @{}
            if ($null -ne $TeamObj.allowCreateUpdateChannels) { $MemberSettings['allowCreateUpdateChannels'] = [bool]$TeamObj.allowCreateUpdateChannels }
            if ($null -ne $TeamObj.allowDeleteChannels) { $MemberSettings['allowDeleteChannels'] = [bool]$TeamObj.allowDeleteChannels }
            if ($null -ne $TeamObj.allowAddRemoveApps) { $MemberSettings['allowAddRemoveApps'] = [bool]$TeamObj.allowAddRemoveApps }
            if ($null -ne $TeamObj.allowCreatePrivateChannels) { $MemberSettings['allowCreatePrivateChannels'] = [bool]$TeamObj.allowCreatePrivateChannels }
            if ($null -ne $TeamObj.allowCreateUpdateRemoveTabs) { $MemberSettings['allowCreateUpdateRemoveTabs'] = [bool]$TeamObj.allowCreateUpdateRemoveTabs }
            if ($null -ne $TeamObj.allowCreateUpdateRemoveConnectors) { $MemberSettings['allowCreateUpdateRemoveConnectors'] = [bool]$TeamObj.allowCreateUpdateRemoveConnectors }
            $TeamsSettings['memberSettings'] = $MemberSettings
        }

        # Add guest settings if provided
        if ($null -ne $TeamObj.allowGuestCreateUpdateChannels -or $null -ne $TeamObj.allowGuestDeleteChannels) {
            $GuestSettings = @{}
            if ($null -ne $TeamObj.allowGuestCreateUpdateChannels) { $GuestSettings['allowCreateUpdateChannels'] = [bool]$TeamObj.allowGuestCreateUpdateChannels }
            if ($null -ne $TeamObj.allowGuestDeleteChannels) { $GuestSettings['allowDeleteChannels'] = [bool]$TeamObj.allowGuestDeleteChannels }
            $TeamsSettings['guestSettings'] = $GuestSettings
        }

        # Add messaging settings if provided
        if ($null -ne $TeamObj.allowUserEditMessages -or
            $null -ne $TeamObj.allowUserDeleteMessages -or
            $null -ne $TeamObj.allowOwnerDeleteMessages -or
            $null -ne $TeamObj.allowTeamMentions -or
            $null -ne $TeamObj.allowChannelMentions) {

            $MessagingSettings = @{}
            if ($null -ne $TeamObj.allowUserEditMessages) { $MessagingSettings['allowUserEditMessages'] = [bool]$TeamObj.allowUserEditMessages }
            if ($null -ne $TeamObj.allowUserDeleteMessages) { $MessagingSettings['allowUserDeleteMessages'] = [bool]$TeamObj.allowUserDeleteMessages }
            if ($null -ne $TeamObj.allowOwnerDeleteMessages) { $MessagingSettings['allowOwnerDeleteMessages'] = [bool]$TeamObj.allowOwnerDeleteMessages }
            if ($null -ne $TeamObj.allowTeamMentions) { $MessagingSettings['allowTeamMentions'] = [bool]$TeamObj.allowTeamMentions }
            if ($null -ne $TeamObj.allowChannelMentions) { $MessagingSettings['allowChannelMentions'] = [bool]$TeamObj.allowChannelMentions }
            $TeamsSettings['messagingSettings'] = $MessagingSettings
        }

        # Add fun settings if provided
        if ($null -ne $TeamObj.allowGiphy -or
            $null -ne $TeamObj.allowStickersAndMemes -or
            $null -ne $TeamObj.allowCustomMemes) {

            $FunSettings = @{}
            if ($null -ne $TeamObj.allowGiphy) { $FunSettings['allowGiphy'] = [bool]$TeamObj.allowGiphy }
            if ($TeamObj.giphyContentRating) { $FunSettings['giphyContentRating'] = $TeamObj.giphyContentRating }
            if ($null -ne $TeamObj.allowStickersAndMemes) { $FunSettings['allowStickersAndMemes'] = [bool]$TeamObj.allowStickersAndMemes }
            if ($null -ne $TeamObj.allowCustomMemes) { $FunSettings['allowCustomMemes'] = [bool]$TeamObj.allowCustomMemes }
            $TeamsSettings['funSettings'] = $FunSettings
        }

        $Body = $TeamsSettings | ConvertTo-Json -Depth 10
        # Create the team - the response Content-Location header contains the team ID
        $CreateResponse = New-GraphPostRequest -AsApp $true -uri 'https://graph.microsoft.com/v1.0/teams' -tenantid $TenantID -type POST -body $Body -Verbose

        # Add additional members after team creation (Graph API only allows 1 member during creation)
        $AdditionalMemberUPNs = @()
        if ($TeamObj.additionalMembers) {
            $AdditionalMemberUPNs = @($TeamObj.additionalMembers) | Where-Object { $_ }
        }

        $MemberFailures = @()
        if ($AdditionalMemberUPNs.Count -gt 0) {
            # Extract Team ID from the creation response
            $NewTeamID = $null
            if ($CreateResponse -and $CreateResponse.'Content-Location') {
                # Content-Location is like /teams('guid')
                if ($CreateResponse.'Content-Location' -match "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}") {
                    $NewTeamID = $Matches[0]
                }
            }

            if (-not $NewTeamID) {
                # Fallback: look up the team by display name
                Start-Sleep -Seconds 5
                $LookupResult = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($TeamObj.displayName)' and resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id" -tenantid $TenantID -asapp $true
                if ($LookupResult -and $LookupResult.Count -gt 0) {
                    $NewTeamID = $LookupResult[0].id
                }
            }

            if ($NewTeamID) {
                # Wait a moment for team provisioning to complete
                Start-Sleep -Seconds 5

                foreach ($MemberUPN in $AdditionalMemberUPNs) {
                    try {
                        $MemberBody = @{
                            '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                            'roles'           = @()
                            'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$MemberUPN')"
                        } | ConvertTo-Json
                        $null = New-GraphPostRequest -AsApp $true -uri "https://graph.microsoft.com/v1.0/teams/$NewTeamID/members" -tenantid $TenantID -type POST -body $MemberBody
                    } catch {
                        $MemberFailures += $MemberUPN
                        Write-Host "Failed to add member $MemberUPN to team: $_"
                    }
                }
            } else {
                $MemberFailures = $AdditionalMemberUPNs
                Write-Host "Could not determine new team ID to add additional members"
            }
        }

        if ($MemberFailures.Count -gt 0) {
            $Message = "Successfully created Team: '$($TeamObj.displayName)', but failed to add $($MemberFailures.Count) member(s): $($MemberFailures -join ', '). You can add them manually from the team details page."
        } else {
            $MembersAdded = $AdditionalMemberUPNs.Count
            $Message = "Successfully created Team: '$($TeamObj.displayName)'"
            if ($MembersAdded -gt 0) {
                $Message += " with $MembersAdded additional member(s)"
            }
        }
        Write-LogMessage -headers $Headers -API $APINAME -tenant $TenantID -message $Message -Sev Info
        $StatusCode = [HttpStatusCode]::OK

    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to create Team: '$($TeamObj.displayName)'. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APINAME -tenant $TenantID -message $Message -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }


    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = $Message }
        })

}
