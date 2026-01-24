function Invoke-ExecOffboardUser {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $RawUsers = $Request.Body.user
    $AllUsers = @()
    if ($null -ne $RawUsers) {
        if ($RawUsers -is [System.Collections.IEnumerable] -and -not ($RawUsers -is [string])) {
            foreach ($UserItem in $RawUsers) {
                if ($null -eq $UserItem) { continue }
                if ($UserItem -is [string]) {
                    $AllUsers += $UserItem
                    continue
                }
                if ($UserItem.value) {
                    $AllUsers += $UserItem.value
                    continue
                }
                if ($UserItem.userPrincipalName) {
                    $AllUsers += $UserItem.userPrincipalName
                    continue
                }
            }
        } else {
            if ($RawUsers.value) {
                $AllUsers += $RawUsers.value
            } elseif ($RawUsers -is [string]) {
                $AllUsers += $RawUsers
            } elseif ($RawUsers.userPrincipalName) {
                $AllUsers += $RawUsers.userPrincipalName
            }
        }
    }
    if (-not $AllUsers -or $AllUsers.Count -eq 0) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = [pscustomobject]@{ Results = @("No users were provided for offboarding.") }
            })
    }
    $TenantFilter = $request.Body.tenantFilter.value ? $request.Body.tenantFilter.value : $request.Body.tenantFilter
    $OffboardingOptions = $Request.Body | Select-Object * -ExcludeProperty user, tenantFilter, Scheduled
    $Results = foreach ($username in $AllUsers) {
        try {
            $APIName = 'ExecOffboardUser'
            $Headers = $Request.Headers


            if ($Request.Body.Scheduled.enabled) {
                $taskObject = [PSCustomObject]@{
                    TenantFilter  = $TenantFilter
                    Name          = "Offboarding: $Username"
                    Command       = @{
                        value = 'Invoke-CIPPOffboardingJob'
                    }
                    Parameters    = [pscustomobject]@{
                        Username     = $Username
                        APIName      = 'Scheduled Offboarding'
                        options      = $OffboardingOptions
                        RunScheduled = $true
                    }
                    ScheduledTime = $Request.Body.Scheduled.date
                    PostExecution = @{
                        Webhook = [bool]$Request.Body.PostExecution.webhook
                        Email   = [bool]$Request.Body.PostExecution.email
                        PSA     = [bool]$Request.Body.PostExecution.psa
                    }
                    Reference     = $Request.Body.reference
                }
                Add-CIPPScheduledTask -Task $taskObject -hidden $false -Headers $Headers
            } else {
                Invoke-CIPPOffboardingJob -Username $Username -TenantFilter $TenantFilter -Options $OffboardingOptions -APIName $APIName -Headers $Headers
            }
            $StatusCode = [HttpStatusCode]::OK

        } catch {
            $StatusCode = [HttpStatusCode]::Forbidden
            $_.Exception.message
        }
    }
    $body = [pscustomobject]@{'Results' = @($Results) }
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })

}
