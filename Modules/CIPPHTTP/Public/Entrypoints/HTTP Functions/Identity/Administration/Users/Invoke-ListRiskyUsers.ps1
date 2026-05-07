function Invoke-ListRiskyUsers {
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
        $GraphUri = "https://graph.microsoft.com/beta/identityProtection/riskyUsers?`$top=500&`$orderby=riskLastUpdatedDateTime desc"
        $RiskyUsers = New-GraphGetRequest -uri $GraphUri -tenantid $TenantFilter

        # Pull our locally-recorded dismissal metadata for this tenant so we can
        # show *who* dismissed each risky user. Microsoft Graph does not surface
        # the actor on the riskyUsers resource.
        $DismissalsByUserId = @{}
        try {
            $DismissalTable = Get-CIPPTable -tablename 'RiskyUserDismissals'
            $Filter = "PartitionKey eq '{0}'" -f $TenantFilter.Replace("'", "''")
            $DismissalRecords = Get-CIPPAzDataTableEntity @DismissalTable -Filter $Filter -ErrorAction SilentlyContinue
            foreach ($Record in $DismissalRecords) {
                if ($Record.UserId) {
                    $DismissalsByUserId[$Record.UserId] = $Record
                }
            }
        } catch {
            # Table may not exist yet (no one has ever dismissed). Treat as empty.
            $RecordError = Get-CippException -Exception $_
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Could not load RiskyUserDismissals metadata: $($RecordError.NormalizedError)" -Sev 'Debug'
        }

        $EnrichedUsers = @(foreach ($User in $RiskyUsers) {
                $Dismissal = $null
                if ($User.id -and $DismissalsByUserId.ContainsKey($User.id)) {
                    $Dismissal = $DismissalsByUserId[$User.id]
                }

                # Only surface dismissal metadata when the user is actually in a
                # dismissed state (so stale records from a prior dismiss/re-flag
                # cycle don't get displayed against an active risk).
                $IsDismissed = ([string]$User.riskState).ToLower() -eq 'dismissed'
                $DismissedBy = if ($IsDismissed -and $Dismissal) { $Dismissal.DismissedBy } else { $null }
                $DismissedDateTime = if ($IsDismissed -and $Dismissal) { $Dismissal.DismissedDateTime } else { $null }

                $Enriched = [ordered]@{}
                foreach ($Property in $User.PSObject.Properties) {
                    $Enriched[$Property.Name] = $Property.Value
                }
                $Enriched['dismissedBy'] = $DismissedBy
                $Enriched['dismissedDateTime'] = $DismissedDateTime
                [PSCustomObject]$Enriched
            })

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Listed $($EnrichedUsers.Count) risky users" -Sev 'Debug'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $EnrichedUsers }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to list risky users: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to list risky users: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
