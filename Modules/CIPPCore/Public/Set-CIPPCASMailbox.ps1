function Set-CIPPCASMailbox {
    <#
    .SYNOPSIS
        Sets CAS (Client Access Services) mailbox settings for a user
    .DESCRIPTION
        Configures mailbox protocol settings like IMAP, POP, EWS, MAPI, OWA, and ActiveSync
    .PARAMETER Username
        The user principal name or email address of the mailbox
    .PARAMETER TenantFilter
        The tenant ID or domain
    .PARAMETER ImapEnabled
        Enable or disable IMAP access
    .PARAMETER PopEnabled
        Enable or disable POP access
    .PARAMETER EwsEnabled
        Enable or disable Exchange Web Services access
    .PARAMETER MAPIEnabled
        Enable or disable MAPI access
    .PARAMETER OWAEnabled
        Enable or disable Outlook Web App access
    .PARAMETER ActiveSyncEnabled
        Enable or disable ActiveSync access
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$ImapEnabled,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$PopEnabled,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$EwsEnabled,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$MAPIEnabled,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$OWAEnabled,

        [Parameter(Mandatory = $false)]
        [nullable[bool]]$ActiveSyncEnabled,

        [Parameter(Mandatory = $false)]
        $Headers
    )

    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        # Build the command parameters - only include explicitly set values
        $CmdParams = @{
            Identity = $Username
        }

        $ProtocolsChanged = @()

        if ($null -ne $ImapEnabled) {
            $CmdParams['ImapEnabled'] = $ImapEnabled
            $ProtocolsChanged += "IMAP=$ImapEnabled"
        }
        if ($null -ne $PopEnabled) {
            $CmdParams['PopEnabled'] = $PopEnabled
            $ProtocolsChanged += "POP=$PopEnabled"
        }
        if ($null -ne $EwsEnabled) {
            $CmdParams['EwsEnabled'] = $EwsEnabled
            $ProtocolsChanged += "EWS=$EwsEnabled"
        }
        if ($null -ne $MAPIEnabled) {
            $CmdParams['MAPIEnabled'] = $MAPIEnabled
            $ProtocolsChanged += "MAPI=$MAPIEnabled"
        }
        if ($null -ne $OWAEnabled) {
            $CmdParams['OWAEnabled'] = $OWAEnabled
            $ProtocolsChanged += "OWA=$OWAEnabled"
        }
        if ($null -ne $ActiveSyncEnabled) {
            $CmdParams['ActiveSyncEnabled'] = $ActiveSyncEnabled
            $ProtocolsChanged += "ActiveSync=$ActiveSyncEnabled"
        }

        if ($ProtocolsChanged.Count -eq 0) {
            $Results.Add("No protocol changes specified for $Username")
            return $Results
        }

        # Execute the command
        $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-CASMailbox' -cmdParams $CmdParams

        $Message = "Successfully updated CAS mailbox settings for $Username ($($ProtocolsChanged -join ', '))"
        $Results.Add($Message)
        Write-LogMessage -headers $Headers -API 'Set-CIPPCASMailbox' -tenant $TenantFilter -message $Message -Sev 'Info'

    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $Results.Add("Failed to update CAS mailbox settings for $Username. Error: $ErrorMessage")
        Write-LogMessage -headers $Headers -API 'Set-CIPPCASMailbox' -tenant $TenantFilter -message "Failed to update CAS mailbox for $Username. Error: $ErrorMessage" -Sev 'Error'
        throw $ErrorMessage
    }

    return $Results
}
