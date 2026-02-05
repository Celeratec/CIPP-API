function Get-CIPPTable {
    <#
    .FUNCTIONALITY
    Internal
    #>
    [CmdletBinding()]
    param (
        $tablename = 'CippLogs'
    )
    $Context = New-AzDataTableContext -ConnectionString $env:AzureWebJobsStorage -TableName $tablename

    # Retry logic for table creation during concurrent operations (e.g., TableBeingDeleted conflicts)
    $maxRetries = 3
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        try {
            New-AzDataTable -Context $Context -ErrorAction Stop | Out-Null
            break
        } catch {
            if ($_.Exception.Message -match 'TableBeingDeleted|being deleted') {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Seconds ([math]::Pow(2, $retryCount))  # Exponential backoff: 2, 4, 8 seconds
                    continue
                }
            }
            # For non-retryable errors or max retries exceeded, throw
            throw
        }
    }

    @{
        Context = $Context
    }
}