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
