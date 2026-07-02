Function Invoke-EditQuarantinePolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Spamfilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers


    $TenantFilter = $Request.Query.TenantFilter ?? $Request.Body.TenantFilter

    # Built-in policies (e.g. the global settings policy) report an all-zeros Guid that
    # Set-QuarantinePolicy cannot resolve as an objectId, so fall back to the policy name.
    $Identity = $Request.Body.Identity
    if ($Identity -eq '00000000-0000-0000-0000-000000000000') {
        $Identity = $Request.Body.Name ?? $Identity
    }

    if ($Request.Query.Type -eq "GlobalQuarantinePolicy") {

        $Frequency = $Request.Body.EndUserSpamNotificationFrequency.value ?? $Request.Body.EndUserSpamNotificationFrequency
        # If request EndUserSpamNotificationFrequency it not set to a ISO 8601 timeformat, convert it to one.
        # This happens if the user doesn't change the Notification Frequency value in the UI. Because of a "bug" with setDefaultValue function with the cippApiDialog, where "label" is set to both label and value.
        $EndUserSpamNotificationFrequency = switch ($Frequency) {
            "4 Hours" { "PT4H" }
            "Daily" { "P1D" }
            "Weekly" { "P7D" }
            Default { $Frequency }
        }

        $Params = @{
            Identity = $Identity
            # Convert the requested frequency from ISO 8601 to a TimeSpan object
            EndUserSpamNotificationFrequency = [System.Xml.XmlConvert]::ToTimeSpan($EndUserSpamNotificationFrequency)
            EndUserSpamNotificationCustomFromAddress = $Request.Body.EndUserSpamNotificationCustomFromAddress
            OrganizationBrandingEnabled = $Request.Body.OrganizationBrandingEnabled
        }
    }
    else {
        $ReleaseActionPreference = $Request.Body.ReleaseActionPreference.value ?? $Request.Body.ReleaseActionPreference

        $EndUserQuarantinePermissions   = @{
            PermissionToBlockSender = $Request.Body.BlockSender
            PermissionToDelete  = $Request.Body.Delete
            PermissionToPreview = $Request.Body.Preview
            PermissionToRelease = $ReleaseActionPreference -eq "Release" ? $true : $false
            PermissionToRequestRelease  = $ReleaseActionPreference -eq "RequestRelease" ? $true : $false
            PermissionToAllowSender = $Request.Body.AllowSender
        }

        $Params = @{
            Identity = $Identity
            EndUserQuarantinePermissions = $EndUserQuarantinePermissions
            ESNEnabled = $Request.Body.QuarantineNotification
            IncludeMessagesFromBlockedSenderAddress = $Request.Body.IncludeMessagesFromBlockedSenderAddress
            action = $Request.Body.Action ?? "Set"
        }
    }

    try {
        Set-CIPPQuarantinePolicy @Params -tenantFilter $TenantFilter -APIName $APIName

        $Result = "Updated Quarantine policy '$($Request.Body.Name)'"
        $StatusCode = [HttpStatusCode]::OK
        Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev Info
    }
    catch {
        $Result = "Failed to update Quarantine policy '$($Request.Body.Name)' - $($_)"
        $StatusCode = [HttpStatusCode]::Forbidden
        Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev Error -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{Results = $Result }
        })

}
