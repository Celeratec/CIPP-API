function Invoke-ExecCreateSharingLink {
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

    $DriveId = $Request.Body.driveId
    $ItemId = $Request.Body.itemId
    $LinkType = $Request.Body.linkType
    $LinkScope = $Request.Body.linkScope
    $Recipients = $Request.Body.recipients
    $ExpirationDateTime = $Request.Body.expirationDateTime
    $Password = $Request.Body.password

    if (-not $TenantFilter -or -not $DriveId -or -not $ItemId) {
        return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter, driveId, and itemId are required.' }
        })
    }

    if (-not $LinkType) { $LinkType = 'view' }
    if (-not $LinkScope) { $LinkScope = 'organization' }

    try {
        $LinkBody = @{
            type  = $LinkType
            scope = $LinkScope
        }

        if ($ExpirationDateTime) {
            $LinkBody['expirationDateTime'] = $ExpirationDateTime
        }

        if ($Password) {
            $LinkBody['password'] = $Password
        }

        if ($LinkScope -eq 'users' -and $Recipients) {
            $RecipientList = @($Recipients | ForEach-Object {
                if ($_ -is [string]) {
                    @{ email = $_ }
                } else {
                    @{ email = $_.email ?? $_.value ?? $_ }
                }
            })
            $LinkBody['recipients'] = $RecipientList
        }

        $LinkBodyJson = ConvertTo-Json -InputObject $LinkBody -Depth 10 -Compress
        $Uri = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$ItemId/createLink"

        $Result = New-GraphPostRequest -uri $Uri -tenantid $TenantFilter -type POST -body $LinkBodyJson -AsApp $true

        $ScopeLabel = switch ($LinkScope) {
            'anonymous'    { 'Anyone with the link' }
            'organization' { 'People in the organization' }
            'users'        { 'Specific people' }
            default        { $LinkScope }
        }
        $TypeLabel = switch ($LinkType) {
            'view'  { 'View' }
            'edit'  { 'Edit' }
            'embed' { 'Embed' }
            default { $LinkType }
        }

        $LinkUrl = $Result.link.webUrl
        $Message = "Created $TypeLabel sharing link ($ScopeLabel)"
        if ($ExpirationDateTime) {
            $Message += " expiring $ExpirationDateTime"
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info'

        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results = $Message
            Link    = @{
                webUrl     = $LinkUrl
                type       = $LinkType
                scope      = $LinkScope
                id         = $Result.id
                expiration = $Result.expirationDateTime
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $NormError = [string]$ErrorMessage.NormalizedError

        if ($NormError -match 'accessDenied' -or $NormError -match '403') {
            $ErrorText = "Failed to create sharing link: Access denied. Ensure CIPP has Sites.ReadWrite.All or Sites.Manage.All application permission and CPV has been refreshed."
        } elseif ($NormError -match 'invalidRequest' -or $NormError -match 'notAllowed') {
            $ErrorText = "Failed to create sharing link: The requested sharing type is not allowed. Check the site and tenant sharing policies."
        } else {
            $ErrorText = "Failed to create sharing link: $NormError"
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ErrorText -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{ Results = $ErrorText }
    }

    return ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    })
}
