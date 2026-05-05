function Invoke-ExecExpirePassword {
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

    # Get parameters from query or body
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    $UserID = $Request.Query.ID ?? $Request.Body.ID
    $DisplayName = $Request.Query.displayName ?? $Request.Body.displayName ?? $UserID

    try {
        # Set forceChangePasswordNextSignIn without changing the password
        $Body = [PSCustomObject]@{
            'passwordProfile' = @{
                'forceChangePasswordNextSignIn' = $true
            }
        } | ConvertTo-Json -Depth 5 -Compress

        Write-Host "Expiring password for user: $UserID with body: $Body"
        $null = New-GraphPostRequest -uri "https://graph.microsoft.com/v1.0/users/$($UserID)" -tenantid $TenantFilter -type PATCH -body $Body -verbose

        $Result = @{
            resultText = "Successfully set password to expire for $DisplayName ($UserID). The user will be required to change their password on next sign-in. Use 'Revoke all user sessions' to force immediate re-authentication."
            state      = 'success'
        }

        Write-LogMessage -headers $Headers -API $APIName -message "Set password to expire for $DisplayName ($UserID)" -Sev 'Info' -tenant $TenantFilter
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = @{
            resultText = "Failed to expire password for $DisplayName ($UserID). Error: $($ErrorMessage.NormalizedError)"
            state      = 'error'
        }
        Write-LogMessage -headers $Headers -API $APIName -message "Failed to expire password for $DisplayName ($UserID). Error: $($ErrorMessage.NormalizedError)" -Sev 'Error' -tenant $TenantFilter -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = @{ Results = $Result }
    }
}
