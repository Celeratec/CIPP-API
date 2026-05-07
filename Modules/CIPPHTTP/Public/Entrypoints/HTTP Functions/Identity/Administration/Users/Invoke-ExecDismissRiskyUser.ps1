function Invoke-ExecDismissRiskyUser {
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
    # Interact with the query or body of the request
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    $SuspectUser = $Request.Query.userId ?? $Request.Body.userId
    $userDisplayName = $Request.Query.userDisplayName ?? $Request.Body.userDisplayName
    $userPrincipalName = $Request.Query.userPrincipalName ?? $Request.Body.userPrincipalName

    $DismissedBy = try {
        ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Headers.'x-ms-client-principal')) | ConvertFrom-Json).userDetails
    } catch { 'Unknown' }

    $GraphRequest = @{
        'uri'         = 'https://graph.microsoft.com/beta/riskyUsers/dismiss'
        'tenantid'    = $TenantFilter
        'type'        = 'POST'
        'contentType' = 'application/json; charset=utf-8'
        'body'        = @{
            'userIds' = @($SuspectUser)
        } | ConvertTo-Json
    }

    try {
        $GraphResults = New-GraphPostRequest @GraphRequest
        $Result = "Successfully dismissed User Risk for user $userDisplayName. $GraphResults"

        # Record who dismissed this risky user so it can be displayed in the UI.
        # Microsoft Graph does not return this information on its own.
        try {
            $DismissalTable = Get-CIPPTable -tablename 'RiskyUserDismissals'
            $DismissalEntity = @{
                PartitionKey      = [string]$TenantFilter
                RowKey            = [string]$SuspectUser
                UserId            = [string]$SuspectUser
                UserDisplayName   = [string]$userDisplayName
                UserPrincipalName = [string]$userPrincipalName
                DismissedBy       = [string]$DismissedBy
                DismissedDateTime = [string]([datetime]::UtcNow.ToString('o'))
            }
            Add-CIPPAzDataTableEntity @DismissalTable -Entity $DismissalEntity -Force | Out-Null
        } catch {
            # Non-fatal: the Graph dismissal succeeded, we just couldn't record the actor locally.
            $RecordError = Get-CippException -Exception $_
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Dismissal succeeded but failed to record dismissedBy metadata for $userDisplayName : $($RecordError.NormalizedError)" -sev 'Warning' -LogData $RecordError
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to dismiss user risk for $userDisplayName. $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Result }
        })
}
