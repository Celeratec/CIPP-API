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

    if ([string]::IsNullOrWhiteSpace($tenantFilter) -or [string]::IsNullOrWhiteSpace($userId)) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = 'TenantFilter and UserID are required'
        })
    }

    try {
        # Try to fetch the photo from Microsoft Graph
        $URI = "https://graph.microsoft.com/v1.0/users/$userId/photo/`$value"
        
        try {
            $graphToken = Get-GraphToken -tenantid $tenantFilter
            $PhotoResponse = Invoke-RestMethod -Uri $URI -Headers $graphToken -Method GET -ErrorAction Stop
            
            # If we get here, we have photo data
            # Determine content type (Graph returns image/jpeg or image/png)
            $ContentType = 'image/jpeg'
            
            return ([HttpResponseContext]@{
                StatusCode  = [HttpStatusCode]::OK
                ContentType = $ContentType
                Body        = $PhotoResponse
            })
        } catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            
            # 404 means user has no photo - this is expected
            if ($StatusCode -eq 404) {
                return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::NotFound
                    Body       = 'User does not have a profile photo'
                })
            }
            
            # Any other error
            throw $_
        }
    } catch {
        # Return 404 for any photo-related error (most likely no photo exists)
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::NotFound
            Body       = "Unable to retrieve user photo: $($_.Exception.Message)"
        })
    }
}
