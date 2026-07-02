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
