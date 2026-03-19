function Invoke-ExecTempFileCleanup {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Site.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $Files = @($Request.Body.files)

    if (-not $TenantFilter) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'TenantFilter is required' }
        })
    }

    if (-not $Files -or $Files.Count -eq 0) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Files array is required and must not be empty' }
        })
    }

    if ($Files.Count -gt 100) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Maximum 100 files per request. Please split into multiple requests.' }
        })
    }

    try {
        $Results = [System.Collections.Generic.List[object]]::new()
        $SuccessCount = 0
        $FailureCount = 0

        foreach ($File in $Files) {
            if (-not $File.driveId -or -not $File.id) {
                $Results.Add(@{
                    id      = $File.id ?? 'unknown'
                    name    = $File.name ?? 'unknown'
                    status  = 'failed'
                    message = 'Missing required file properties (driveId, id)'
                })
                $FailureCount++
                continue
            }

            try {
                $Uri = "https://graph.microsoft.com/v1.0/drives/$($File.driveId)/items/$($File.id)"
                $null = New-GraphPostRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type DELETE -body '{}'

                $Results.Add(@{
                    id      = $File.id
                    name    = $File.name
                    status  = 'deleted'
                    message = 'Moved to recycle bin'
                })
                $SuccessCount++
            } catch {
                $ErrorInfo = Get-CippException -Exception $_
                $Results.Add(@{
                    id      = $File.id
                    name    = $File.name
                    status  = 'failed'
                    message = $ErrorInfo.NormalizedError
                })
                $FailureCount++
            }
        }

        $Summary = @{
            Total   = $Files.Count
            Success = $SuccessCount
            Failed  = $FailureCount
        }

        $LogMessage = "Temp file cleanup completed: $SuccessCount deleted, $FailureCount failed out of $($Files.Count) files"
        $LogSeverity = if ($FailureCount -eq 0) { 'Info' } elseif ($SuccessCount -eq 0) { 'Error' } else { 'Warning' }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $LogMessage -Sev $LogSeverity

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results = @($Results)
            Summary = $Summary
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Temp file cleanup failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = "Failed to process cleanup request: $($ErrorMessage.NormalizedError)" }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
