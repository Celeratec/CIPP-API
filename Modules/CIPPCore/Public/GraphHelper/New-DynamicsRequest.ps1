function New-DynamicsRequest {
    <#
    .FUNCTIONALITY
    Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DynamicsUrl,

        [Parameter(Mandatory = $true)]
        [string]$Entity,

        [string]$TenantFilter,

        [string]$Select,

        [string]$Filter,

        [string]$Expand,

        [int]$Top,

        [string]$OrderBy,

        [bool]$NoAuthCheck,

        [switch]$AsApp,

        [string]$ApiVersion = 'v9.2',

        [bool]$noPagination
    )

    if ($NoAuthCheck -eq $false -and -not (Get-AuthorisedRequest -TenantID $TenantFilter)) {
        Write-Error 'Not allowed. You cannot manage your own tenant or tenants not under your scope'
        return
    }

    # Build the scope from the Dynamics URL (e.g., https://contoso.crm.dynamics.com -> https://contoso.crm.dynamics.com/.default)
    $DynamicsUrlTrimmed = $DynamicsUrl.TrimEnd('/')
    $Scope = "$DynamicsUrlTrimmed/.default"

    $Token = Get-GraphToken -Tenantid $TenantFilter -scope $Scope -AsApp $AsApp.IsPresent

    $Headers = @{
        Authorization  = $Token.Authorization
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        Accept             = 'application/json'
        Prefer             = 'odata.include-annotations="*",odata.maxpagesize=500'
        'User-Agent'       = "CIPP/$($global:CippVersion ?? '1.0')"
    }

    # Build the OData query URL
    $QueryParts = @()
    if ($Select) { $QueryParts += "`$select=$Select" }
    if ($Filter) { $QueryParts += "`$filter=$Filter" }
    if ($Expand) { $QueryParts += "`$expand=$Expand" }
    if ($Top -gt 0) { $QueryParts += "`$top=$Top" }
    if ($OrderBy) { $QueryParts += "`$orderby=$OrderBy" }

    $QueryString = if ($QueryParts.Count -gt 0) { '?' + ($QueryParts -join '&') } else { '' }
    $BaseUrl = "$DynamicsUrlTrimmed/api/data/$ApiVersion"
    $NextURL = "$BaseUrl/$Entity$QueryString"

    try {
        $ReturnedData = do {
            $RetryCount = 0
            $MaxRetries = 3
            $RequestSuccessful = $false
            Write-Information "Dynamics GET [ $NextURL ] | tenant: $TenantFilter"

            do {
                try {
                    $RequestParams = @{
                        Uri         = $NextURL
                        Method      = 'GET'
                        Headers     = $Headers
                        ContentType = 'application/json; charset=utf-8'
                    }

                    $Data = Invoke-RestMethod @RequestParams
                    $RequestSuccessful = $true

                    # Return the value array if present, otherwise the data itself
                    if ($Data.PSObject.Properties.Name -contains 'value') {
                        $Data.value
                    } else {
                        $Data
                    }

                    if ($noPagination) {
                        $NextURL = $null
                    } else {
                        $NextURL = $Data.'@odata.nextLink'
                    }
                } catch {
                    $ShouldRetry = $false
                    $WaitTime = 0
                    $Message = $null

                    try {
                        $ErrorObj = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($ErrorObj.error) {
                            $Message = $ErrorObj.error.message
                        }
                    } catch {
                        $Message = $null
                    }

                    if ([string]::IsNullOrEmpty($Message)) {
                        $Message = $_.Exception.Message
                    }

                    # Check for 429 Too Many Requests
                    if ($_.Exception.Response.StatusCode -eq 429) {
                        $RetryAfterHeader = $_.Exception.Response.Headers['Retry-After']
                        if ($RetryAfterHeader) {
                            $WaitTime = [int]$RetryAfterHeader
                        } else {
                            $WaitTime = 5
                        }
                        Write-Warning "Dynamics API rate limited (429). Waiting $WaitTime seconds. Attempt $($RetryCount + 1) of $MaxRetries"
                        $ShouldRetry = $true
                    }
                    # Check for transient errors
                    elseif ($_.Exception.Response.StatusCode -in @(502, 503, 504) -or $Message -like '*temporarily unavailable*') {
                        $WaitTime = Get-Random -Minimum 1.1 -Maximum 3.1
                        Write-Warning "Dynamics API transient error. Waiting $WaitTime seconds. Attempt $($RetryCount + 1) of $MaxRetries"
                        $ShouldRetry = $true
                    }

                    if ($ShouldRetry -and $RetryCount -lt $MaxRetries) {
                        $RetryCount++
                        Start-Sleep -Seconds $WaitTime
                    } else {
                        throw $Message
                    }
                }
            } while (-not $RequestSuccessful -and $RetryCount -le $MaxRetries)
        } until ([string]::IsNullOrEmpty($NextURL))

        return $ReturnedData
    } catch {
        throw "Dynamics API request failed for $Entity : $($_.Exception.Message)"
    }
}
