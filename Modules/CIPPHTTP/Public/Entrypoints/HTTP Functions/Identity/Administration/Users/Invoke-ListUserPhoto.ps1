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

            # Use Invoke-WebRequest instead of Invoke-RestMethod to properly handle binary image data
            $PhotoResponse = Invoke-WebRequest -Uri $URI -Headers $graphToken -Method GET -ErrorAction Stop

            # If we get here, we have photo data
            # Get content type from response headers, default to image/jpeg
            $ContentType = $PhotoResponse.Headers['Content-Type']
            if (-not $ContentType) {
                $ContentType = 'image/jpeg'
            }
            # Handle array-wrapped content types
            if ($ContentType -is [array]) {
                $ContentType = $ContentType[0]
            }

            # Return the raw binary content
            return ([HttpResponseContext]@{
                StatusCode  = [HttpStatusCode]::OK
                ContentType = $ContentType
                Body        = [byte[]]$PhotoResponse.Content
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
