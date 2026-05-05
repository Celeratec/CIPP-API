function Push-DeployIntegrationApp {
    <#
    .FUNCTIONALITY
        Entrypoint
    #>
    param($Item)

    Write-LogMessage -API 'Deploy Integration App' -message "Push-DeployIntegrationApp started with item: $($Item | ConvertTo-Json -Depth 5 -Compress)" -Sev 'Debug'

    try {
        $Item = $Item | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $TenantFilter = $Item.Tenant
        $TenantName = $Item.TenantName
        $DeploymentId = $Item.DeploymentId
        $TemplateName = $Item.TemplateName

        Write-LogMessage -API 'Deploy Integration App' -tenant $TenantFilter -message "Starting deployment of '$TemplateName' (DeploymentId: $DeploymentId)" -Sev 'Info'
        Write-Information "Deploying integration app '$TemplateName' to tenant $TenantFilter"

        # Get tenant info for the app name pattern
        $TenantInfo = Get-Tenants -TenantFilter $TenantFilter
        $DisplayTenantName = $TenantName
        if ($TenantInfo.displayName) {
            $DisplayTenantName = $TenantInfo.displayName
        }

        # Build app display name from pattern
        $AppDisplayName = $Item.AppNamePattern -replace '\{TenantName\}', $DisplayTenantName

        # Build requiredResourceAccess from template permissions
        $RequiredResourceAccess = @()
        foreach ($Resource in $Item.Permissions) {
            $ResourceAccess = @()
            foreach ($Perm in $Resource.permissions) {
                $ResourceAccess += @{
                    id   = $Perm.id
                    type = $Perm.type
                }
            }
            $RequiredResourceAccess += @{
                resourceAppId  = $Resource.resourceAppId
                resourceAccess = $ResourceAccess
            }
        }

        # Check if app already exists
        $ExistingApps = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$AppDisplayName'" -tenantid $TenantFilter -AsApp $true
        if ($ExistingApps.value -and $ExistingApps.value.Count -gt 0) {
            $ExistingApp = $ExistingApps.value[0]
            Write-LogMessage -message "Application '$AppDisplayName' already exists in tenant $TenantFilter. Updating permissions." -tenant $TenantFilter -API 'Deploy Integration App' -sev Info

            # Update existing app's permissions
            $UpdateBody = @{
                requiredResourceAccess = $RequiredResourceAccess
            } | ConvertTo-Json -Depth 10
            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/applications/$($ExistingApp.id)" -type PATCH -tenantid $TenantFilter -body $UpdateBody -AsApp $true

            $AppId = $ExistingApp.appId
            $AppObjectId = $ExistingApp.id

            # Check for existing service principal
            $ServicePrincipal = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$AppId'" -tenantid $TenantFilter -AsApp $true
            if (-not $ServicePrincipal.value -or $ServicePrincipal.value.Count -eq 0) {
                $SPBody = @{ appId = $AppId } | ConvertTo-Json
                $ServicePrincipal = New-GraphPostRequest -uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -type POST -tenantid $TenantFilter -body $SPBody -AsApp $true
                $ServicePrincipalId = $ServicePrincipal.id
            } else {
                $ServicePrincipalId = $ServicePrincipal.value[0].id
            }
        } else {
            # Create new application
            $AppBody = @{
                displayName            = $AppDisplayName
                signInAudience         = 'AzureADMyOrg'
                requiredResourceAccess = $RequiredResourceAccess
            }

            # Add redirect URIs if specified
            if ($Item.RedirectUris -and $Item.RedirectUris.Count -gt 0) {
                $AppBody.web = @{
                    redirectUris = $Item.RedirectUris
                }
            }

            $AppBodyJson = $AppBody | ConvertTo-Json -Depth 10
            $CreatedApp = New-GraphPostRequest -uri 'https://graph.microsoft.com/v1.0/applications' -type POST -tenantid $TenantFilter -body $AppBodyJson -AsApp $true

            if (-not $CreatedApp.appId) {
                throw 'Application creation failed - no appId returned'
            }

            $AppId = $CreatedApp.appId
            $AppObjectId = $CreatedApp.id

            Write-LogMessage -message "Created application '$AppDisplayName' in tenant $TenantFilter. App ID: $AppId" -tenant $TenantFilter -API 'Deploy Integration App' -sev Info

            # Create service principal
            $SPBody = @{ appId = $AppId } | ConvertTo-Json
            $ServicePrincipal = New-GraphPostRequest -uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -type POST -tenantid $TenantFilter -body $SPBody -AsApp $true
            $ServicePrincipalId = $ServicePrincipal.id
        }

        # Generate client secret if requested
        $ClientSecret = $null
        $SecretExpiration = $null
        if ($Item.GenerateSecret) {
            $ExpirationDays = $Item.SecretExpDays ?? 730
            $SecretEndDate = (Get-Date).AddDays($ExpirationDays).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

            $PasswordBody = @{
                passwordCredential = @{
                    displayName = 'CIPP Generated Secret'
                    endDateTime = $SecretEndDate
                }
            } | ConvertTo-Json -Depth 10

            $PasswordResult = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/applications/$AppObjectId/addPassword" -type POST -tenantid $TenantFilter -body $PasswordBody -AsApp $true

            $ClientSecret = $PasswordResult.secretText
            $SecretExpiration = $SecretEndDate
        }

        # Grant admin consent for application permissions
        foreach ($Resource in $Item.Permissions) {
            # Get the resource service principal
            $ResourceSP = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($Resource.resourceAppId)'" -tenantid $TenantFilter -AsApp $true

            if ($ResourceSP.value -and $ResourceSP.value.Count -gt 0) {
                $ResourceSPId = $ResourceSP.value[0].id

                foreach ($Perm in $Resource.permissions) {
                    if ($Perm.type -eq 'Role') {
                        # Application permission - create app role assignment
                        try {
                            $AssignmentBody = @{
                                principalId = $ServicePrincipalId
                                resourceId  = $ResourceSPId
                                appRoleId   = $Perm.id
                            } | ConvertTo-Json

                            $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/appRoleAssignments" -type POST -tenantid $TenantFilter -body $AssignmentBody -AsApp $true
                            Write-Information "Granted $($Perm.name) permission to app in tenant $TenantFilter"
                        } catch {
                            if ($_.Exception.Message -notlike '*Permission being assigned already exists*') {
                                Write-Warning "Failed to grant permission $($Perm.name): $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }

        Write-LogMessage -message "Successfully deployed integration app '$AppDisplayName' to tenant $TenantFilter" -tenant $TenantFilter -API 'Deploy Integration App' -sev Info

        # Store result in deployment table
        Write-Information "Storing deployment result for $TenantFilter (DeploymentId: $DeploymentId)"
        $DeploymentTable = Get-CIPPTable -TableName 'IntegrationDeployments'
        $ResultEntity = @{
            PartitionKey     = 'IntegrationDeploymentResult'
            RowKey           = "$DeploymentId`_$TenantFilter"
            DeploymentId     = $DeploymentId
            Tenant           = $TenantFilter
            TenantName       = $TenantName
            DisplayName      = $DisplayTenantName
            AppName          = $AppDisplayName
            AppId            = $AppId
            TenantId         = $TenantInfo.customerId ?? $TenantFilter
            ClientSecret     = $ClientSecret
            SecretExpiration = $SecretExpiration
            Status           = 'Success'
            Message          = "Successfully created application '$AppDisplayName'"
            CompletedAt      = (Get-Date).ToUniversalTime().ToString('o')
        }
        Add-CIPPAzDataTableEntity @DeploymentTable -Entity $ResultEntity -Force
        Write-LogMessage -API 'Deploy Integration App' -tenant $TenantFilter -message "Stored deployment result: Success for $AppDisplayName (AppId: $AppId)" -Sev 'Info'

        return $true

    } catch {
        $ErrorMessage = $_.Exception.Message
        $ErrorDetails = Get-CippException -Exception $_
        Write-LogMessage -message "Error deploying integration app to tenant $($Item.Tenant): $ErrorMessage" -tenant $Item.Tenant -API 'Deploy Integration App' -sev Error -LogData $ErrorDetails

        # Store error result
        try {
            $DeploymentTable = Get-CIPPTable -TableName 'IntegrationDeployments'
            $ResultEntity = @{
                PartitionKey = 'IntegrationDeploymentResult'
                RowKey       = "$($Item.DeploymentId)`_$($Item.Tenant)"
                DeploymentId = $Item.DeploymentId
                Tenant       = $Item.Tenant
                TenantName   = $Item.TenantName
                Status       = 'Failed'
                Message      = $ErrorMessage
                CompletedAt  = (Get-Date).ToUniversalTime().ToString('o')
            }
            Add-CIPPAzDataTableEntity @DeploymentTable -Entity $ResultEntity -Force
            Write-LogMessage -API 'Deploy Integration App' -tenant $Item.Tenant -message "Stored deployment result: Failed - $ErrorMessage" -Sev 'Info'
        } catch {
            Write-LogMessage -API 'Deploy Integration App' -message "Failed to store error result: $($_.Exception.Message)" -Sev 'Error'
        }

        return $false
    }
}
