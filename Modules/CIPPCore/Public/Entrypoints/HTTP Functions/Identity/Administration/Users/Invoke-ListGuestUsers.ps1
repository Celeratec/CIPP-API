function Invoke-ListGuestUsers {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter is required.' }
        })
    }

    try {
        $SelectFields = 'id,displayName,mail,userPrincipalName,createdDateTime,accountEnabled,externalUserState,externalUserStateChangeDateTime,userType,signInActivity'
        $GuestUsers = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/users?`$filter=userType eq 'Guest'&`$select=$SelectFields&`$top=999" -tenantid $TenantFilter -AsApp $true -ComplexFilter

        $Now = Get-Date
        $StaleThresholdDays = 90

        $EnrichedGuests = @($GuestUsers | ForEach-Object {
            $Guest = $_
            $SourceDomain = if ($Guest.mail) { ($Guest.mail -split '@')[1] } else { 'Unknown' }
            $LastSignIn = $Guest.signInActivity.lastSignInDateTime
            $DaysSinceSignIn = if ($LastSignIn) {
                [math]::Round(($Now - [datetime]$LastSignIn).TotalDays)
            } else {
                $null
            }
            $IsStale = $null -ne $DaysSinceSignIn -and $DaysSinceSignIn -gt $StaleThresholdDays
            $NeverSignedIn = $null -eq $LastSignIn

            $Status = if (-not $Guest.accountEnabled) {
                'Disabled'
            } elseif ($Guest.externalUserState -eq 'PendingAcceptance') {
                'Pending'
            } elseif ($IsStale) {
                'Stale'
            } elseif ($NeverSignedIn) {
                'Never Signed In'
            } else {
                'Active'
            }

            [PSCustomObject]@{
                id                = $Guest.id
                displayName       = $Guest.displayName
                mail              = $Guest.mail
                userPrincipalName = $Guest.userPrincipalName
                sourceDomain      = $SourceDomain
                status            = $Status
                accountEnabled    = $Guest.accountEnabled
                externalUserState = $Guest.externalUserState
                createdDateTime   = $Guest.createdDateTime
                lastSignIn        = $LastSignIn
                daysSinceSignIn   = $DaysSinceSignIn
                isStale           = $IsStale
                neverSignedIn     = $NeverSignedIn
            }
        })

        $Summary = @{
            totalGuests      = $EnrichedGuests.Count
            activeGuests     = ($EnrichedGuests | Where-Object { $_.status -eq 'Active' }).Count
            staleGuests      = ($EnrichedGuests | Where-Object { $_.status -eq 'Stale' }).Count
            pendingGuests    = ($EnrichedGuests | Where-Object { $_.status -eq 'Pending' }).Count
            disabledGuests   = ($EnrichedGuests | Where-Object { $_.status -eq 'Disabled' }).Count
            neverSignedIn    = ($EnrichedGuests | Where-Object { $_.status -eq 'Never Signed In' }).Count
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Listed $($EnrichedGuests.Count) guest users" -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results = @{
                guests  = $EnrichedGuests
                summary = $Summary
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to list guest users: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to list guest users: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
