Function Invoke-ListUserPhoto {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Identity.User.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    
    $tenantFilter = $Request.Query.tenantFilter
    $userId = $Request.Query.UserID
    $skipCache = $Request.Query.skipCache -eq 'true'

    if ([string]::IsNullOrWhiteSpace($tenantFilter) -or [string]::IsNullOrWhiteSpace($userId)) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'TenantFilter and UserID are required'
        })
    }

    # Cache TTL: 7 days
    $CacheTTLDays = 7

    try {
        # Check cache first (unless skipCache is specified)
        if (-not $skipCache) {
            try {
                $Table = Get-CippTable -tablename 'CacheUserPhotos'
                $CacheAge = (Get-Date).AddDays(-$CacheTTLDays).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                $Filter = "PartitionKey eq '$tenantFilter' and RowKey eq '$userId' and CachedAt ge '$CacheAge'"
                $CachedPhoto = Get-CIPPAzDataTableEntity @Table -Filter $Filter
                
                if ($CachedPhoto) {
                    if ($CachedPhoto.HasPhoto -eq $true -and $CachedPhoto.PhotoData) {
                        # Return cached photo
                        $Body = [Convert]::FromBase64String($CachedPhoto.PhotoData)
                        return ([HttpResponseContext]@{
                            StatusCode  = [HttpStatusCode]::OK
                            ContentType = $CachedPhoto.ContentType ?? 'image/jpeg'
                            Headers     = @{ 'X-Cache' = 'HIT' }
                            Body        = $Body
                        })
                    } elseif ($CachedPhoto.HasPhoto -eq $false) {
                        # We know this user has no photo
                        return ([HttpResponseContext]@{
                            StatusCode = [HttpStatusCode]::NotFound
                            Headers    = @{ 'X-Cache' = 'HIT-NOPHOTO' }
                            Body       = 'User does not have a profile photo'
                        })
                    }
                }
            } catch {
                # Cache lookup failed, continue to fetch from Graph
                Write-Information "Cache lookup failed: $($_.Exception.Message)"
            }
        }

        # Fetch from Microsoft Graph
        $URI = "/users/$userId/photo/`$value"

        $Requests = @(
            @{
                id     = 'photo'
                url    = $URI
                method = 'GET'
            }
        )

        $ImageData = New-GraphBulkRequest -Requests $Requests -tenantid $tenantFilter -NoAuthCheck $true

        # Check if the response indicates an error (404 = no photo)
        if ($null -eq $ImageData -or $null -eq $ImageData.body -or $ImageData.status -eq 404) {
            # Cache the "no photo" result to avoid repeated lookups
            try {
                $Table = Get-CippTable -tablename 'CacheUserPhotos'
                $Entity = @{
                    PartitionKey = $tenantFilter
                    RowKey       = $userId
                    PhotoData    = ''
                    HasPhoto     = $false
                    CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }
                Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
            } catch {
                Write-Information "Failed to cache no-photo result: $($_.Exception.Message)"
            }
            
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NotFound
                Headers    = @{ 'X-Cache' = 'MISS' }
                Body       = 'User does not have a profile photo'
            })
        }

        # Check for error responses from Graph
        if ($ImageData.status -ge 400) {
            return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NotFound
                Headers    = @{ 'X-Cache' = 'MISS' }
                Body       = 'Unable to retrieve user photo'
            })
        }

        # Cache the photo for future requests
        try {
            $Table = Get-CippTable -tablename 'CacheUserPhotos'
            $Entity = @{
                PartitionKey = $tenantFilter
                RowKey       = $userId
                PhotoData    = $ImageData.body  # Already base64 encoded
                ContentType  = $ImageData.headers.'Content-Type' ?? 'image/jpeg'
                HasPhoto     = $true
                CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
        } catch {
            Write-Information "Failed to cache photo: $($_.Exception.Message)"
        }

        # Convert body from base64 to byte array and return
        $Body = [Convert]::FromBase64String($ImageData.body)

        return ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::OK
            ContentType = $ImageData.headers.'Content-Type'
            Headers     = @{ 'X-Cache' = 'MISS' }
            Body        = $Body
        })
    } catch {
        # User likely doesn't have a photo or other error
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::NotFound
            Body       = 'User photo not available'
        })
    }
}
