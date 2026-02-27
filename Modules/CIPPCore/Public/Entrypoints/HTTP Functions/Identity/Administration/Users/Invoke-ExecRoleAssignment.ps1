function Invoke-ExecRoleAssignment {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.Role.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $UserId = $Request.Body.userId
    $UserPrincipalName = $Request.Body.userPrincipalName
    $DisplayName = $Request.Body.displayName
    $Action = $Request.Body.action
    $Reason = $Request.Body.reason ?? 'No reason provided'

    $Roles = if ($Request.Body.roles.value) {
        $Request.Body.roles | ForEach-Object { $_.value }
    } else {
        @($Request.Body.roles)
    }

    $RoleLabels = if ($Request.Body.roles.label) {
        $Request.Body.roles | ForEach-Object { $_.label }
    } else {
        @($Request.Body.roles)
    }

    $Results = [System.Collections.Generic.List[object]]::new()

    try {
        $UserObj = New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/users/$UserId" -tenantid $TenantFilter

        switch ($Action) {
            'Add' {
                foreach ($Role in $Roles) {
                    try {
                        $Body = @{
                            '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($UserObj.id)"
                        } | ConvertTo-Json -Compress
                        $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/beta/directoryRoles(roleTemplateId='$Role')/members/`$ref" -tenantid $TenantFilter -body $Body
                    } catch {
                        $RoleError = Get-NormalizedError -Message $_.Exception.Message
                        if ($RoleError -notmatch 'already exist') {
                            throw $RoleError
                        }
                    }
                }
                $RoleNames = ($RoleLabels -join ', ')
                $Message = "Successfully assigned roles ($RoleNames) to $DisplayName ($UserPrincipalName)"
                $Results.Add($Message)
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info'
            }
            'Remove' {
                foreach ($Role in $Roles) {
                    try {
                        $null = New-GraphPOSTRequest -type DELETE -uri "https://graph.microsoft.com/beta/directoryRoles(roleTemplateId='$Role')/members/$($UserObj.id)/`$ref" -tenantid $TenantFilter
                    } catch {
                        $RoleError = Get-NormalizedError -Message $_.Exception.Message
                        throw $RoleError
                    }
                }
                $RoleNames = ($RoleLabels -join ', ')
                $Message = "Successfully removed roles ($RoleNames) from $DisplayName ($UserPrincipalName)"
                $Results.Add($Message)
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info'
            }
            'AddTemporary' {
                foreach ($Role in $Roles) {
                    try {
                        $Body = @{
                            '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($UserObj.id)"
                        } | ConvertTo-Json -Compress
                        $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/beta/directoryRoles(roleTemplateId='$Role')/members/`$ref" -tenantid $TenantFilter -body $Body
                    } catch {
                        $RoleError = Get-NormalizedError -Message $_.Exception.Message
                        if ($RoleError -notmatch 'already exist') {
                            throw $RoleError
                        }
                    }
                }

                $Expiration = ([System.DateTimeOffset]::FromUnixTimeSeconds($Request.Body.expiration)).DateTime

                $RemoveTaskBody = [pscustomobject]@{
                    TenantFilter  = $TenantFilter
                    Name          = "Role Assignment (Remove): $UserPrincipalName"
                    Command       = @{
                        value = 'Invoke-ExecRoleAssignment'
                        label = 'Invoke-ExecRoleAssignment'
                    }
                    Parameters    = [pscustomobject]@{
                        Body = @{
                            tenantFilter      = $TenantFilter
                            userId            = $UserObj.id
                            userPrincipalName = $UserPrincipalName
                            displayName       = $DisplayName
                            roles             = $Request.Body.roles
                            action            = 'Remove'
                            reason            = "Scheduled removal - $Reason"
                        }
                    }
                    ScheduledTime = $Request.Body.expiration
                    PostExecution = @{
                        Webhook = $false
                        Email   = $false
                        PSA     = $false
                    }
                }
                $null = Add-CIPPScheduledTask -Task $RemoveTaskBody -hidden $false

                $RoleNames = ($RoleLabels -join ', ')
                $Message = "Successfully assigned temporary roles ($RoleNames) to $DisplayName ($UserPrincipalName). Roles will be removed on $($Expiration.ToString('g')). Reason: $Reason"
                $Results.Add($Message)
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info'
            }
        }

        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results.Add("Failed to $Action role assignment. $($ErrorMessage.NormalizedError)")
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to $Action role assignment for $UserPrincipalName. $($ErrorMessage.NormalizedError)" -Sev 'Error'
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = @($Results) }
    }
}
