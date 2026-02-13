function Invoke-ExecAddCrossTenantTemplate {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.CrossTenant.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    try {
        if ([string]::IsNullOrWhiteSpace($Request.Body.templateName)) {
            throw 'Template name is required.'
        }

        $GUID = $Request.Body.GUID ? $Request.Body.GUID : (New-Guid).GUID

        # Decode the user principal
        $updatedBy = 'Unknown'
        try {
            if ($Request.Headers.'x-ms-client-principal') {
                $decodedPrincipal = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Request.Headers.'x-ms-client-principal')) | ConvertFrom-Json
                $updatedBy = $decodedPrincipal.userDetails
            }
        } catch {
            Write-Host "Failed to decode client principal: $_"
        }

        $TemplateData = [PSCustomObject]@{
            GUID         = $GUID
            templateName = $Request.Body.templateName
            description  = $Request.Body.description ?? ''
            createdAt    = $Request.Body.createdAt ?? (Get-Date).ToUniversalTime()
            updatedAt    = (Get-Date).ToUniversalTime()
            updatedBy    = $updatedBy
            settings     = [PSCustomObject]@{
                # Cross-Tenant Access Policy defaults
                b2bCollaborationInbound      = $Request.Body.settings.b2bCollaborationInbound
                b2bCollaborationOutbound     = $Request.Body.settings.b2bCollaborationOutbound
                b2bDirectConnectInbound      = $Request.Body.settings.b2bDirectConnectInbound
                b2bDirectConnectOutbound     = $Request.Body.settings.b2bDirectConnectOutbound
                inboundTrust                 = $Request.Body.settings.inboundTrust
                tenantRestrictions           = $Request.Body.settings.tenantRestrictions
                automaticUserConsentSettings = $Request.Body.settings.automaticUserConsentSettings
                # External Collaboration settings
                allowInvitesFrom                          = $Request.Body.settings.allowInvitesFrom
                guestUserRoleId                           = $Request.Body.settings.guestUserRoleId
                allowedToSignUpEmailBasedSubscriptions     = $Request.Body.settings.allowedToSignUpEmailBasedSubscriptions
                allowEmailVerifiedUsersToJoinOrganization = $Request.Body.settings.allowEmailVerifiedUsersToJoinOrganization
                blockMsnSignIn                            = $Request.Body.settings.blockMsnSignIn
                # Domain restrictions
                domainRestrictions = $Request.Body.settings.domainRestrictions
            }
        }

        $JSON = ConvertTo-Json -Compress -Depth 20 -InputObject $TemplateData
        $Table = Get-CippTable -tablename 'templates'
        $Table.Force = $true
        Add-CIPPAzDataTableEntity @Table -Entity @{
            JSON         = "$JSON"
            RowKey       = "$GUID"
            PartitionKey = 'CrossTenantTemplate'
            GUID         = "$GUID"
        }

        Write-LogMessage -headers $Headers -API $APIName -message "Cross-tenant security template '$($Request.Body.templateName)' with GUID $GUID added/updated." -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results  = "Successfully saved cross-tenant security template '$($Request.Body.templateName)'."
            Metadata = @{ GUID = $GUID }
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -message "Failed to save cross-tenant template: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to save cross-tenant template: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
