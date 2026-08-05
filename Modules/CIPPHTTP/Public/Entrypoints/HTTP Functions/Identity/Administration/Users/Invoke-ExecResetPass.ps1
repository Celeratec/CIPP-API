Function Invoke-ExecResetPass {
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

    # multiPost bulk actions POST an array of user objects in one request.
    # Accessing $Request.Body.MustChange on an array enumerates to Object[],
    # which breaks [System.Convert]::ToBoolean — process each item instead.
    $Users = if ($Request.Body -is [array]) {
        $Request.Body
    } else {
        @(
            [pscustomobject]@{
                tenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
                ID           = $Request.Query.ID ?? $Request.Body.ID
                displayName  = $Request.Query.displayName ?? $Request.Body.displayName
                MustChange   = $Request.Query.MustChange ?? $Request.Body.MustChange
                password     = $Request.Query.password ?? $Request.Body.password
            }
        )
    }

    $Results = [System.Collections.Generic.List[object]]::new()
    $HadFailure = $false

    foreach ($User in $Users) {
        $TenantFilter = $User.tenantFilter
        $ID = $User.ID
        $DisplayName = $User.displayName ?? $ID
        $Password = $User.password

        # Coerce MustChange safely — null/empty => false; unwrap accidental arrays
        $MustChangeRaw = $User.MustChange
        if ($null -eq $MustChangeRaw -or $MustChangeRaw -eq '') {
            $MustChange = $false
        } elseif ($MustChangeRaw -is [bool]) {
            $MustChange = $MustChangeRaw
        } elseif ($MustChangeRaw -is [array]) {
            $MustChange = if ($MustChangeRaw.Count -gt 0) { [System.Convert]::ToBoolean($MustChangeRaw[0]) } else { $false }
        } else {
            $MustChange = [System.Convert]::ToBoolean($MustChangeRaw)
        }

        if ([string]::IsNullOrWhiteSpace($ID) -or [string]::IsNullOrWhiteSpace($TenantFilter)) {
            $Results.Add('Failed to reset password: missing ID or tenantFilter')
            $HadFailure = $true
            continue
        }

        try {
            $ResetParams = @{
                UserID                        = $ID
                tenantFilter                  = $TenantFilter
                APIName                       = $APIName
                Headers                       = $Headers
                forceChangePasswordNextSignIn = $MustChange
                DisplayName                   = $DisplayName
            }
            if ($Password) {
                $ResetParams['Password'] = $Password
            }
            $Results.Add((Set-CIPPResetPassword @ResetParams))
        } catch {
            $Results.Add("Failed to reset password for $DisplayName, $ID`: $((Get-CippException -Exception $_).NormalizedError)")
            $HadFailure = $true
        }
    }

    $StatusCode = if ($HadFailure -and $Results.Count -eq 1) {
        [HttpStatusCode]::InternalServerError
    } elseif ($HadFailure) {
        [HttpStatusCode]::BadRequest
    } else {
        [HttpStatusCode]::OK
    }

    # Preserve single-result shape for non-bulk callers
    $BodyResults = if ($Users.Count -eq 1) { $Results[0] } else { @($Results) }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{'Results' = $BodyResults }
        })

}
