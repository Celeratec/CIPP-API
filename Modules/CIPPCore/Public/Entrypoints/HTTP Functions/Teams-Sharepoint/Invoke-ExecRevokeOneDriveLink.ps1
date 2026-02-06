function Invoke-ExecRevokeOneDriveLink {
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
    $DriveId = $Request.Body.DriveId
    $ItemId = $Request.Body.ItemId
    $PermissionId = $Request.Body.PermissionId
    $DisplayName = $Request.Body.DisplayName
    $RevokeAll = $Request.Body.RevokeAll

    try {
        if (-not $TenantFilter) {
            throw 'TenantFilter is required'
        }
        if (-not $DriveId) {
            throw 'DriveId is required'
        }

        $SiteLabel = if ($DisplayName) { $DisplayName } else { $DriveId }
        $RevokedCount = 0

        if ($RevokeAll -eq $true) {
            # Revoke all sharing permissions on the drive root
            $RootPermsUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/root/permissions"
            $RootPerms = New-GraphGetRequest `
                -uri $RootPermsUri `
                -tenantid $TenantFilter `
                -asApp $true

            # Only revoke link-based and external permissions (not inherited or owner)
            $RevocablePerms = $RootPerms | Where-Object {
                ($_.link -and $_.link.scope -ne 'organization') -or
                ($_.roles -and 'owner' -notin $_.roles -and $_.grantedToV2.user.email -and $_.grantedToV2.user.email -notlike '*@*.onmicrosoft.com')
            }

            foreach ($Perm in $RevocablePerms) {
                $DeleteUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/root/permissions/$($Perm.id)"
                try {
                    $null = New-GraphPOSTRequest `
                        -uri $DeleteUri `
                        -tenantid $TenantFilter `
                        -type DELETE `
                        -body '{}' `
                        -asApp $true
                    $RevokedCount++
                } catch {
                    Write-Host "Failed to revoke permission $($Perm.id): $($_.Exception.Message)"
                }
            }

            $Results = "Revoked $RevokedCount sharing link(s) from OneDrive root for '$SiteLabel'."
        } elseif ($ItemId -and $PermissionId) {
            # Revoke a specific permission on a specific item
            $DeleteUri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/permissions/$PermissionId"
            $null = New-GraphPOSTRequest `
                -uri $DeleteUri `
                -tenantid $TenantFilter `
                -type DELETE `
                -body '{}' `
                -asApp $true
            $RevokedCount = 1
            $Results = "Revoked sharing permission on item in OneDrive for '$SiteLabel'."
        } else {
            throw 'Either set RevokeAll to true, or provide both ItemId and PermissionId'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Results; RevokedCount = $RevokedCount }
        })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorText = $ErrorMessage.NormalizedError
        $Results = "Failed to revoke sharing links for '$SiteLabel'. Error: $ErrorText"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage

        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = $Results }
        })
    }
}
