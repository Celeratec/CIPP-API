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
        $Enable = [bool]$Request.Body.enable

        # Support both single protocol and multiple protocols (comma-separated)
        $ProtocolsInput = if ($Request.Body.protocols) {
            $Request.Body.protocols
        } else {
            $Request.Body.protocol
        }

        # Split comma-separated protocols into array
        $ProtocolList = @($ProtocolsInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        # Map protocol names to CAS mailbox parameters
        $ProtocolMap = @{
            'EWS'        = 'EwsEnabled'
            'MAPI'       = 'MAPIEnabled'
            'OWA'        = 'OWAEnabled'
            'IMAP'       = 'ImapEnabled'
            'POP'        = 'PopEnabled'
            'ActiveSync' = 'ActiveSyncEnabled'
        }

        # Validate all protocols
        foreach ($Protocol in $ProtocolList) {
            if (-not $ProtocolMap.ContainsKey($Protocol)) {
                throw "Invalid protocol specified: $Protocol. Valid protocols are: $($ProtocolMap.Keys -join ', ')"
            }
        }

        # Build command parameters for all protocols
        $CmdParams = @{
            Identity = $Username
        }
        foreach ($Protocol in $ProtocolList) {
            $ParamName = $ProtocolMap[$Protocol]
            $CmdParams[$ParamName] = $Enable
        }

        $Results = try {
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-CASMailbox' -cmdParams $CmdParams
            $StatusText = if ($Enable) { 'enabled' } else { 'disabled' }
            $ProtocolNames = $ProtocolList -join ', '
            $Message = "Successfully $StatusText $ProtocolNames for $Username"
            Write-LogMessage -headers $Request.Headers -API $APINAME -message $Message -Sev 'Info' -tenant $TenantFilter
            $Message
        } catch {
            $ProtocolNames = $ProtocolList -join ', '
            $ErrorMessage = "Failed to set $ProtocolNames for $Username. Error: $($_.Exception.Message)"
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
