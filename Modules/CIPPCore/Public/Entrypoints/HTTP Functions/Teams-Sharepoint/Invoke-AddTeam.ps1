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

        # Build owners array
        $OwnerMembers = @($Owners) | ForEach-Object {
            $OwnerUPN = $_
            @{
                '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                'roles'           = @('owner')
                'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$OwnerUPN')"
            }
        }

        # Build additional members array (if provided)
        $AdditionalMembers = @()
        if ($TeamObj.additionalMembers) {
            $AdditionalMembers = @($TeamObj.additionalMembers) | ForEach-Object {
                $MemberUPN = $_
                @{
                    '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                    'roles'           = @()
                    'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$MemberUPN')"
                }
            }
        }

        $AllMembers = @($OwnerMembers) + @($AdditionalMembers)

        # Determine template
        $TemplateName = if ($TeamObj.templateName) { $TeamObj.templateName } else { 'standard' }

        # Build team settings object
        $TeamsSettings = [ordered]@{
            'template@odata.bind' = "https://graph.microsoft.com/v1.0/teamsTemplates('$TemplateName')"
            'visibility'          = $TeamObj.visibility
            'displayName'         = $TeamObj.displayName
            'description'         = $TeamObj.description
            'members'             = @($AllMembers)
        }

        # Add member settings if provided
        if ($TeamObj.allowCreateUpdateChannels -ne $null -or
            $TeamObj.allowDeleteChannels -ne $null -or
            $TeamObj.allowAddRemoveApps -ne $null -or
            $TeamObj.allowCreatePrivateChannels -ne $null -or
            $TeamObj.allowCreateUpdateRemoveTabs -ne $null -or
            $TeamObj.allowCreateUpdateRemoveConnectors -ne $null) {

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
        $null = New-GraphPostRequest -AsApp $true -uri 'https://graph.microsoft.com/v1.0/teams' -tenantid $TenantID -type POST -body $Body -Verbose
        $Message = "Successfully created Team: '$($TeamObj.displayName)'"
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
