function Invoke-ExecSetManager {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $HttpResponse = [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{'Results' = @("Default response, you should never see this.") }
    }

    try {
        $Users = if ($Request.Body -is [array]) { $Request.Body } else { @($Request.Body) }

        $InvalidUsers = $Users | Where-Object {
            ([string]::IsNullOrWhiteSpace($_.userPrincipalName) -and [string]::IsNullOrWhiteSpace($_.id)) -or
            [string]::IsNullOrWhiteSpace($_.tenantFilter) -or
            [string]::IsNullOrWhiteSpace($_.managerId)
        }

        if ($InvalidUsers.Count -gt 0) {
            $HttpResponse.StatusCode = [HttpStatusCode]::BadRequest
            $HttpResponse.Body = @{'Results' = @('Failed to set manager. Some users are missing userPrincipalName/id, tenantFilter, or managerId') }
            return $HttpResponse
        }

        $TotalSuccessCount = 0
        $AllErrorMessages = @()

        foreach ($User in $Users) {
            try {
                $userIdentifier = if ($User.userPrincipalName) { $User.userPrincipalName } else { $User.id }
                $managerIdentifier = if ($User.managerId.value) { $User.managerId.value } else { $User.managerId }
                $result = Set-CIPPManager -User $userIdentifier -Manager $managerIdentifier -TenantFilter $User.tenantFilter -Headers $Headers -APIName $APIName
                $TotalSuccessCount++
                Write-LogMessage -headers $Headers -API $APIName -tenant $User.tenantFilter -message $result -Sev 'Info'
            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                $AllErrorMessages += "Failed to set manager for $($User.userPrincipalName): $($ErrorMessage.NormalizedError)"
                Write-LogMessage -headers $Headers -API $APIName -tenant $User.tenantFilter -message "Failed to set manager for $($User.userPrincipalName). Error: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
            }
        }

        if ($AllErrorMessages.Count -eq 0) {
            $HttpResponse.Body = @{'Results' = @("Successfully set manager for $TotalSuccessCount user$(if($TotalSuccessCount -ne 1){'s'})") }
        } else {
            $HttpResponse.StatusCode = [HttpStatusCode]::BadRequest
            $HttpResponse.Body = @{'Results' = $AllErrorMessages + @("Successfully updated $TotalSuccessCount of $($Users.Count) users") }
        }
    } catch {
        $HttpResponse.StatusCode = [HttpStatusCode]::InternalServerError
        $HttpResponse.Body = @{'Results' = @("Failed to set manager. Error: $($_.Exception.Message)") }
    }

    return $HttpResponse
}
