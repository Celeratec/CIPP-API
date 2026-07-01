function Get-CippQuarantineInputValue {
    <#
    .SYNOPSIS
        Normalizes autocomplete/form values from CIPP frontend payloads.
    #>
    [CmdletBinding()]
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) {
        $First = $Value | Select-Object -First 1
        if ($null -ne $First -and $null -ne $First.value) { return [string]$First.value }
        return [string]$First
    }
    if ($null -ne $Value.value) { return [string]$Value.value }
    return [string]$Value
}

function ConvertTo-CippQuarantineStringArray {
    <#
    .SYNOPSIS
        Converts scalar, comma-separated, or JSON array inputs into string arrays.
    #>
    [CmdletBinding()]
    param($InputObject)

    if ($null -eq $InputObject -or $InputObject -eq '') { return @() }
    if ($InputObject -is [array]) {
        return @(
            $InputObject |
                ForEach-Object { Get-CippQuarantineInputValue $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
    if ($InputObject -is [string] -and $InputObject.Trim().StartsWith('[')) {
        try {
            return @($InputObject | ConvertFrom-Json | ForEach-Object { [string]$_ } | Where-Object { $_ })
        } catch {
            # fall through to comma split
        }
    }
    return @(
        ($InputObject -split '[,;]') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function ConvertTo-CippQuarantineReleaseStatusApiValue {
    [CmdletBinding()]
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) { return $null }
    switch ($Status.ToUpperInvariant()) {
        'NOTRELEASED' { return 'NotReleased' }
        'RELEASED' { return 'Released' }
        'REQUESTED' { return 'Requested' }
        'DENIED' { return 'Denied' }
        'ERROR' { return 'Error' }
        'APPROVED' { return 'Approved' }
        'PREPARINGTORELEASE' { return 'PreparingToRelease' }
        default { return $Status }
    }
}

function ConvertTo-CippQuarantineDisplayObject {
    <#
    .SYNOPSIS
        Normalizes Get-QuarantineMessage output for CIPP frontend consumption.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Message
    )

    process {
        if (-not $Message) { return }
        $DisplayStatus = switch ([string]$Message.ReleaseStatus) {
            'NotReleased' { 'NOTRELEASED' }
            'Released' { 'RELEASED' }
            'Requested' { 'REQUESTED' }
            'Denied' { 'DENIED' }
            'Error' { 'ERROR' }
            'Approved' { 'APPROVED' }
            'PreparingToRelease' { 'PREPARINGTORELEASE' }
            default { [string]$Message.ReleaseStatus }
        }

        $Recipient = $Message.RecipientAddress
        if ($Recipient -is [array]) {
            $Recipient = ($Recipient -join '; ')
        }

        [PSCustomObject]@{
            Identity         = $Message.Identity
            MessageId        = $Message.MessageId
            ReceivedTime     = $Message.ReceivedTime
            Subject          = $Message.Subject
            SenderAddress    = $Message.SenderAddress
            SenderName       = $Message.SenderName
            RecipientAddress = $Recipient
            Type             = $Message.Type
            QuarantineReason = $Message.QuarantineReason ?? $Message.Type
            PolicyName       = $Message.PolicyName
            PolicyType       = $Message.PolicyType
            ReleaseStatus    = $DisplayStatus
            Expires          = $Message.Expires
            ReleasedBy       = $Message.ReleasedUser ?? $Message.ReleasedBy
            ReleasedTime     = $Message.ReleasedTime
            Direction        = $Message.Direction
            Size             = $Message.Size
            SystemReleased   = $Message.SystemReleased
            Reported         = $Message.Reported
            Tenant           = $Message.Tenant
            CustomData       = $Message.CustomData
        }
    }
}

function Build-CIPPQuarantineQueryParams {
    <#
    .SYNOPSIS
        Maps CIPP request input to Get-QuarantineMessage cmdlet parameters and client-side post-filters.
    .DESCRIPTION
        Server-side filters use Exchange Online Get-QuarantineMessage parameters.
        Post-filters (subjectContains, senderDomain, recipientDomain) are applied after the EXO call
        because EXO does not support partial subject match or domain-only filtering.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$QueryInput,
        [switch]$ApplyDefaultDateRange
    )

    $CmdParams = @{
        PageSize = 100
        Page     = 1
    }

    $PostFilters = @{}
    $AppliedFilters = @{}

    if ($QueryInput.pageSize) {
        $PageSize = [int]$QueryInput.pageSize
        if ($PageSize -lt 1) { $PageSize = 1 }
        if ($PageSize -gt 1000) { $PageSize = 1000 }
        $CmdParams.PageSize = $PageSize
    }
    if ($QueryInput.page) {
        $Page = [int]$QueryInput.page
        if ($Page -lt 1) { $Page = 1 }
        if ($Page -gt 1000) { $Page = 1000 }
        $CmdParams.Page = $Page
    }
    if ($QueryInput.nextLink -match '^\d+$') {
        $CmdParams.Page = [int]$QueryInput.nextLink
    }

    $MessageId = Get-CippQuarantineInputValue $QueryInput.messageId
    if (-not [string]::IsNullOrWhiteSpace($MessageId)) {
        $CmdParams.MessageId = $MessageId
        $AppliedFilters.messageId = $MessageId
        return [PSCustomObject]@{
            CmdParams      = $CmdParams
            PostFilters    = $PostFilters
            AppliedFilters = $AppliedFilters
        }
    }

    $HasDate = $false
    if ($QueryInput.days) {
        $Days = [int](Get-CippQuarantineInputValue $QueryInput.days)
        $CmdParams.StartReceivedDate = (Get-Date).AddDays(-$Days).ToUniversalTime()
        $CmdParams.EndReceivedDate = (Get-Date).ToUniversalTime()
        $AppliedFilters.days = $Days
        $HasDate = $true
    } elseif ($QueryInput.startDate) {
        $StartDate = $QueryInput.startDate
        if ($StartDate -match '^\d+$') {
            $CmdParams.StartReceivedDate = [DateTimeOffset]::FromUnixTimeSeconds([int64]$StartDate).UtcDateTime
        } else {
            $CmdParams.StartReceivedDate = [DateTime]::Parse($StartDate).ToUniversalTime()
        }
        if ($QueryInput.endDate) {
            $EndDate = $QueryInput.endDate
            if ($EndDate -match '^\d+$') {
                $CmdParams.EndReceivedDate = [DateTimeOffset]::FromUnixTimeSeconds([int64]$EndDate).UtcDateTime
            } else {
                $CmdParams.EndReceivedDate = [DateTime]::Parse($EndDate).ToUniversalTime()
            }
        } else {
            $CmdParams.EndReceivedDate = (Get-Date).ToUniversalTime()
        }
        $AppliedFilters.startDate = $CmdParams.StartReceivedDate
        $AppliedFilters.endDate = $CmdParams.EndReceivedDate
        $HasDate = $true
    } elseif ($ApplyDefaultDateRange.IsPresent) {
        $CmdParams.StartReceivedDate = (Get-Date).AddDays(-7).ToUniversalTime()
        $CmdParams.EndReceivedDate = (Get-Date).ToUniversalTime()
        $AppliedFilters.days = 7
        $HasDate = $true
    }

    $Sender = Get-CippQuarantineInputValue $QueryInput.sender
    if (-not [string]::IsNullOrWhiteSpace($Sender)) {
        $SenderApi = $Sender -replace '#', '%23'
        $CmdParams.SenderAddress = @($SenderApi)
        $AppliedFilters.sender = $Sender
    }

    $Recipient = Get-CippQuarantineInputValue $QueryInput.recipient
    if (-not [string]::IsNullOrWhiteSpace($Recipient)) {
        $RecipientApi = $Recipient -replace '#', '%23'
        $CmdParams.RecipientAddress = @($RecipientApi)
        $AppliedFilters.recipient = $Recipient
    }

    $SubjectExact = Get-CippQuarantineInputValue $QueryInput.subjectExact
    if (-not [string]::IsNullOrWhiteSpace($SubjectExact)) {
        $CmdParams.Subject = $SubjectExact
        $AppliedFilters.subjectExact = $SubjectExact
    }

    $SubjectContains = Get-CippQuarantineInputValue $QueryInput.subject
    if (-not [string]::IsNullOrWhiteSpace($SubjectContains) -and -not $CmdParams.Subject) {
        $PostFilters.subjectContains = $SubjectContains
        $AppliedFilters.subject = $SubjectContains
    }

    $QuarantineTypes = ConvertTo-CippQuarantineStringArray $QueryInput.quarantineType
    if ($QuarantineTypes.Count -gt 0) {
        $CmdParams.QuarantineTypes = $QuarantineTypes
        $AppliedFilters.quarantineType = $QuarantineTypes
    }

    $ReleaseStatuses = ConvertTo-CippQuarantineStringArray $QueryInput.releaseStatus
    if ($ReleaseStatuses.Count -gt 0) {
        $CmdParams.ReleaseStatus = @($ReleaseStatuses | ForEach-Object { ConvertTo-CippQuarantineReleaseStatusApiValue $_ })
        $AppliedFilters.releaseStatus = $ReleaseStatuses
    }

    $PolicyTypes = ConvertTo-CippQuarantineStringArray $QueryInput.policyTypes
    if ($PolicyTypes.Count -gt 0) {
        $CmdParams.PolicyTypes = $PolicyTypes
        $AppliedFilters.policyTypes = $PolicyTypes
    }

    $PolicyName = Get-CippQuarantineInputValue $QueryInput.policyName
    if (-not [string]::IsNullOrWhiteSpace($PolicyName)) {
        $CmdParams.PolicyName = $PolicyName
        $AppliedFilters.policyName = $PolicyName
    }

    $SenderDomain = Get-CippQuarantineInputValue $QueryInput.senderDomain
    if (-not [string]::IsNullOrWhiteSpace($SenderDomain)) {
        $PostFilters.senderDomain = $SenderDomain.Trim().TrimStart('@').ToLowerInvariant()
        $AppliedFilters.senderDomain = $PostFilters.senderDomain
    }

    $RecipientDomain = Get-CippQuarantineInputValue $QueryInput.recipientDomain
    if (-not [string]::IsNullOrWhiteSpace($RecipientDomain)) {
        $PostFilters.recipientDomain = $RecipientDomain.Trim().TrimStart('@').ToLowerInvariant()
        $AppliedFilters.recipientDomain = $PostFilters.recipientDomain
    }

    if ($QueryInput.entityType) {
        $CmdParams.EntityType = Get-CippQuarantineInputValue $QueryInput.entityType
        $AppliedFilters.entityType = $CmdParams.EntityType
    }

    [PSCustomObject]@{
        CmdParams      = $CmdParams
        PostFilters    = $PostFilters
        AppliedFilters = $AppliedFilters
    }
}

function Invoke-CippQuarantineExoRequest {
    <#
    .SYNOPSIS
        Wraps New-ExoRequest with retry/backoff for transient quarantine API failures.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)][string]$Cmdlet,
        [hashtable]$CmdParams,
        [int]$MaxAttempts = 3
    )

    $Attempt = 0
    $DelaySeconds = 2
    while ($true) {
        $Attempt++
        try {
            return New-ExoRequest -tenantid $TenantId -cmdlet $Cmdlet -cmdParams $CmdParams
        } catch {
            $Message = $_.Exception.Message
            $IsTransient = $Message -match '429|503|throttl|temporar|busy|timeout|Too many requests'
            if (-not $IsTransient -or $Attempt -ge $MaxAttempts) {
                throw
            }
            Start-Sleep -Seconds $DelaySeconds
            $DelaySeconds = [Math]::Min($DelaySeconds * 2, 30)
        }
    }
}

function Get-CippQuarantinePagedResults {
    <#
    .SYNOPSIS
        Fetches one client page of quarantine results, scanning multiple EXO pages when post-filters are active.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)]$Query,
        [string]$NextLink,
        [int]$TargetPageSize = 100
    )

    $HasPostFilters = $Query.PostFilters.Count -gt 0
    $ExoPageSize = $Query.CmdParams.PageSize
    $StartExoPage = 1
    if ($NextLink -match '^\d+$') {
        $StartExoPage = [int]$NextLink
    }

    if (-not $HasPostFilters) {
        $Query.CmdParams.Page = $StartExoPage
        $RawResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantId -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
            Select-Object -ExcludeProperty *data.type*)
        $Filtered = @(Apply-CippQuarantinePostFilters -Messages $RawResults -PostFilters $Query.PostFilters)
        $HasMore = (@($RawResults).Count -eq $ExoPageSize -and $StartExoPage -lt 1000)

        return [PSCustomObject]@{
            Results  = $Filtered
            Metadata = [PSCustomObject]@{
                appliedFilters              = $Query.AppliedFilters
                page                        = $StartExoPage
                pageSize                    = $ExoPageSize
                nextLink                    = if ($HasMore) { [string]($StartExoPage + 1) } else { $null }
                HasPostFilters              = $false
                RawRowsScanned              = @($RawResults).Count
                FilteredRowsReturned        = $Filtered.Count
                PostFilterPaginationLimited = $false
            }
        }
    }

    $Collected = [System.Collections.Generic.List[object]]::new()
    $RawScanned = 0
    $ExoPage = $StartExoPage
    $MaxRawPagesPerRequest = 25
    $PagesFetched = 0
    $LastPageResultCount = 0
    $PostFilterLimited = $false

    while ($Collected.Count -lt $TargetPageSize -and $PagesFetched -lt $MaxRawPagesPerRequest -and $ExoPage -le 1000) {
        $Query.CmdParams.Page = $ExoPage
        $PageResults = @(Invoke-CippQuarantineExoRequest -TenantId $TenantId -Cmdlet 'Get-QuarantineMessage' -CmdParams $Query.CmdParams |
            Select-Object -ExcludeProperty *data.type*)
        $LastPageResultCount = @($PageResults).Count
        $RawScanned += $LastPageResultCount
        $FilteredPage = @(Apply-CippQuarantinePostFilters -Messages $PageResults -PostFilters $Query.PostFilters)
        # Always keep every match from a scanned EXO page. The next request resumes
        # on the following EXO page, so truncating mid-page would silently drop the
        # remaining matches on this page. The client page may therefore run slightly
        # over TargetPageSize, which is preferable to losing rows.
        foreach ($item in $FilteredPage) {
            $Collected.Add($item)
        }
        $PagesFetched++
        $ExoPage++
        if ($LastPageResultCount -lt $ExoPageSize) { break }
    }

    # More EXO pages exist whenever the last scanned page was full. Surface that as
    # HasMore even when this client page came back short (e.g. the raw-page scan
    # limit was hit before enough matches were found), so the UI can keep paging.
    $MoreExoPagesExist = ($LastPageResultCount -eq $ExoPageSize -and $ExoPage -le 1000)
    $HasMore = $MoreExoPagesExist
    if ($MoreExoPagesExist -and $Collected.Count -lt $TargetPageSize) {
        $PostFilterLimited = $true
    }

    return [PSCustomObject]@{
        Results  = @($Collected)
        Metadata = [PSCustomObject]@{
            appliedFilters              = $Query.AppliedFilters
            page                        = $StartExoPage
            pageSize                    = $TargetPageSize
            nextLink                    = if ($HasMore) { [string]$ExoPage } else { $null }
            HasPostFilters              = $true
            RawRowsScanned              = $RawScanned
            FilteredRowsReturned        = $Collected.Count
            PostFilterPaginationLimited = $PostFilterLimited
        }
    }
}

function Apply-CippQuarantinePostFilters {
    [CmdletBinding()]
    param(
        [array]$Messages,
        [hashtable]$PostFilters
    )

    $Results = @($Messages)
    if ($PostFilters.subjectContains) {
        $Pattern = "*$($PostFilters.subjectContains)*"
        $Results = $Results | Where-Object { $_.Subject -like $Pattern }
    }
    if ($PostFilters.senderDomain) {
        $Domain = $PostFilters.senderDomain
        $Results = $Results | Where-Object {
            $Addr = [string]$_.SenderAddress
            $Addr -and ($Addr.Split('@')[-1].ToLowerInvariant() -eq $Domain)
        }
    }
    if ($PostFilters.recipientDomain) {
        $Domain = $PostFilters.recipientDomain
        $Results = $Results | Where-Object {
            $Recipients = @($_.RecipientAddress)
            $Recipients | Where-Object {
                $Addr = [string]$_
                $Addr -and ($Addr.Split('@')[-1].ToLowerInvariant() -eq $Domain)
            }
        }
    }
    return @($Results)
}
