function Build-CIPPQuarantineQueryParams {
    <#
    .SYNOPSIS
        Maps CIPP request input to Get-QuarantineMessage cmdlet parameters and client-side post-filters.
    .DESCRIPTION
        Server-side filters use Exchange Online Get-QuarantineMessage parameters.
        Post-filters (subjectContains, senderDomain, recipientDomain) are applied after the EXO call
        because EXO does not support partial subject match or domain-only filtering.

        Related quarantine helpers live in sibling files (one function per file) because the
        CIPPCore module exports functions by file basename; functions co-located in this file
        would stay private to CIPPCore and be invisible to the CIPPHTTP/CIPPActivityTriggers
        modules that call them.
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
