function Set-CIPPDBCacheUserPhotos {
    <#
    .SYNOPSIS
        Caches user profile photos for a tenant
    
    .DESCRIPTION
        Fetches and caches all user profile photos for a tenant.
        Photos are stored as base64 encoded strings with metadata.
        Cache TTL is 7 days by default.
    
    .PARAMETER TenantFilter
        The tenant to cache photos for
    
    .PARAMETER UserIds
        Optional array of specific user IDs to cache photos for.
        If not specified, fetches photos for all users.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,
        
        [Parameter(Mandatory = $false)]
        [string[]]$UserIds
    )

    try {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Starting user photo cache' -sev Debug
        
        $Table = Get-CippTable -tablename 'CacheUserPhotos'
        $CachedCount = 0
        $SkippedCount = 0
        
        # Get users to process
        if ($UserIds) {
            $UsersToProcess = $UserIds
        } else {
            # Get all users for the tenant
            $Users = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/users?$select=id&$top=999' -tenantid $TenantFilter
            $UsersToProcess = $Users | ForEach-Object { $_.id }
        }
        
        foreach ($UserId in $UsersToProcess) {
            try {
                # Check if photo exists in Graph
                $PhotoUri = "https://graph.microsoft.com/v1.0/users/$UserId/photo/`$value"
                
                try {
                    $PhotoResponse = New-GraphGetRequest -uri $PhotoUri -tenantid $TenantFilter -AsBytes
                    
                    if ($PhotoResponse -and $PhotoResponse.Length -gt 0) {
                        # Convert to base64
                        $PhotoBase64 = [Convert]::ToBase64String($PhotoResponse)
                        
                        # Store in cache
                        $Entity = @{
                            PartitionKey = $TenantFilter
                            RowKey       = $UserId
                            PhotoData    = $PhotoBase64
                            ContentType  = 'image/jpeg'
                            HasPhoto     = $true
                            CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                        }
                        
                        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
                        $CachedCount++
                    } else {
                        # User has no photo - cache this fact to avoid repeated lookups
                        $Entity = @{
                            PartitionKey = $TenantFilter
                            RowKey       = $UserId
                            PhotoData    = ''
                            HasPhoto     = $false
                            CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                        }
                        
                        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
                        $SkippedCount++
                    }
                } catch {
                    # User doesn't have a photo or error occurred - cache as no photo
                    $Entity = @{
                        PartitionKey = $TenantFilter
                        RowKey       = $UserId
                        PhotoData    = ''
                        HasPhoto     = $false
                        CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                    }
                    
                    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
                    $SkippedCount++
                }
                
            } catch {
                Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache photo for user $UserId : $($_.Exception.Message)" -sev Debug
            }
        }
        
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Cached $CachedCount user photos, $SkippedCount users have no photo" -sev Info
        
    } catch {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache user photos: $($_.Exception.Message)" -sev Error -LogData (Get-CippException -Exception $_)
    }
}
