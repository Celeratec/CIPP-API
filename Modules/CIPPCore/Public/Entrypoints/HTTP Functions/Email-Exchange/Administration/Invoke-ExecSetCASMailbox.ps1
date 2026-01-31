Function Invoke-ExecSetCASMailbox {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    try {
        $APIName = $Request.Params.CIPPEndpoint
        Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

        $Username = $Request.Body.user
        $TenantFilter = $Request.Body.tenantFilter
        $Protocol = $Request.Body.protocol
        $Enable = [bool]$Request.Body.enable

        # Map protocol names to CAS mailbox parameters
        $ProtocolMap = @{
            'EWS'        = 'EwsEnabled'
            'MAPI'       = 'MAPIEnabled'
            'OWA'        = 'OWAEnabled'
            'IMAP'       = 'ImapEnabled'
            'POP'        = 'PopEnabled'
            'ActiveSync' = 'ActiveSyncEnabled'
        }

        if (-not $ProtocolMap.ContainsKey($Protocol)) {
            throw "Invalid protocol specified: $Protocol. Valid protocols are: $($ProtocolMap.Keys -join ', ')"
        }

        $ParamName = $ProtocolMap[$Protocol]
        $CmdParams = @{
            Identity = $Username
            $ParamName = $Enable
        }

        $Results = try {
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-CASMailbox' -cmdParams $CmdParams
            $StatusText = if ($Enable) { 'enabled' } else { 'disabled' }
            $Message = "Successfully $StatusText $Protocol for $Username"
            Write-LogMessage -headers $Request.Headers -API $APINAME -message $Message -Sev 'Info' -tenant $TenantFilter
            $Message
        } catch {
            $ErrorMessage = "Failed to set $Protocol for $Username. Error: $($_.Exception.Message)"
            Write-LogMessage -headers $Request.Headers -API $APINAME -message $ErrorMessage -Sev 'Error' -tenant $TenantFilter
            throw $ErrorMessage
        }

        $Body = [pscustomobject]@{ 'Results' = @($Results) }
    } catch {
        $Body = [pscustomobject]@{ 'Results' = @("Error: $($_.Exception.Message)") }
    }

    return ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
}
