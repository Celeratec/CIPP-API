function Get-NormalizedError {
    <#
    .FUNCTIONALITY
    Internal
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'CIPP does not use this function to catch errors')]
    [CmdletBinding()]
    param (
        [string]$message
    )

    #Check if the message is valid JSON.
    try {
        $JSONMsg = $message | ConvertFrom-Json
    } catch {
    }
    #if the message is valid JSON, there can be multiple fields in which the error resides. These are:
    # $message.error.Innererror.Message
    # $message.error.Message
    # $message.error.details.message
    # $message.error.innererror.internalException.message

    # Strip Exchange Online cmdlet exception type prefix (e.g.
    # `|Microsoft.Exchange.Management.Tasks.ValidationException|...`) so the
    # user-facing message starts with the actual error sentence.
    if ($message -match '^\|Microsoft\.Exchange[^|]*\|') {
        $message = ($message -replace '^\|Microsoft\.Exchange[^|]*\|', '').Trim()
    } elseif ($message -match '^\|[A-Za-z0-9\.]+Exception\|') {
        $message = ($message -replace '^\|[A-Za-z0-9\.]+Exception\|', '').Trim()
    }

    #We need to check if the message is in one of these fields, and if so, return it.
    if ($JSONMsg.error.innererror.message) {
        Write-Information "innererror.message found: $($JSONMsg.error.innererror.message)"
        $message = $JSONMsg.error.innererror.message
    } elseif ($JSONMsg.error.message) {
        # SharePoint REST (OData verbose) returns message as { lang, value } object
        if ($JSONMsg.error.message.value) {
            $message = [string]$JSONMsg.error.message.value
        } else {
            $message = [string]$JSONMsg.error.message
        }
        Write-Information "error.message found: $message"
        if ($JSONMsg.error.details.message) {
            $detailMessages = @($JSONMsg.error.details.message) -join '; '
            Write-Information "error.details.message found: $detailMessages"
            $message = "$message $detailMessages"
        }
    } elseif ($JSONMsg.error.details.message) {
        Write-Information "error.details.message found: $($JSONMsg.error.details.message)"
        $message = @($JSONMsg.error.details.message) -join '; '
    } elseif ($JSONMsg.error.innererror.internalException.message) {
        Write-Information "error.innererror.internalException.message found: $($JSONMsg.error.innererror.internalException.message)"
        $message = $JSONMsg.error.innererror.internalException.message
    }


    #finally, put the message through the translator. If it's not in the list, just return the original message
    switch -Wildcard ($message) {
        'Request not applicable to target tenant.' { 'Required license not available for this tenant' }
        "Neither tenant is B2C or tenant doesn't have premium license" { 'This feature requires a P1 license or higher' }
        'Response status code does not indicate success: 400 (Bad Request).' { 'Error 400 occured. There is an issue with the token configuration for this tenant. Please perform an access check' }
        '*Microsoft.Skype.Sync.Pstn.Tnm.Common.Http.HttpResponseException*' { 'Could not connect to Teams Admin center - Tenant might be missing a Teams license' }
        '*Provide valid credential.*' { 'Error 400: There is an issue with your Exchange Token configuration. Please perform an access check for this tenant' }
        '*This indicate that a subscription within the tenant has lapsed*' { 'There is no subscription for this service available, Check licensing information.' }
        '*User was not found.*' { 'The partner relationship with this tenant has been removed. The customer may have terminated the relationship from their admin center, or the tenant no longer exists.' }
        '*AADSTS50020*' { 'The SAM user is a guest in this tenant, or you are using GDAP without proper group membership. Solution: Either delete the guest user from the tenant, or ensure the user is added to the correct GDAP security group with appropriate role assignments.' }
        '*AADSTS50177*' { 'The SAM user is a guest in this tenant, or you are using GDAP without proper group membership. Solution: Either delete the guest user from the tenant, or ensure the user is added to the correct GDAP security group with appropriate role assignments.' }
        '*invalid or malformed*' { 'The request is malformed. Have you finished the Setup Wizard' }
        '*Windows Store repository apps feature is not supported for this tenant*' { 'This tenant does not have WinGet support available' }
        '*AADSTS650051*' {
            if ($Message -like '*service principal name is already present*') {
                'The application service principal already exists in this tenant. This is expected and not an error.'
            } else {
                'The application does not exist yet. Try again in 30 seconds.'
            }
        }
        '*AppLifecycle_2210*' { 'Failed to call Intune APIs: Does the tenant have a license available?' }
        '*One or more added object references already exist for the following modified properties:*' { 'This user is already a member of this group.' }
        '*Microsoft.Exchange.Management.Tasks.MemberAlreadyExistsException*' { 'This user is already a member of this group.' }
        '*The property value exceeds the maximum allowed size (64KB)*' { 'One of the values exceeds the maximum allowed size (64KB).' }
        '*Unable to initialize the authorization context*' { 'GDAP authorization failed. Your GDAP security groups may not have the required role assignments for this tenant. Check: 1) GDAP relationship is active, 2) User is in the correct security group, 3) Security group has the required admin roles assigned.' }
        '*Providers.Common.V1.CoreException*' { '403 (Access Denied) - We cannot connect to this tenant.' }
        '*Authentication failed. MFA required*' { 'Authentication failed. MFA required' }
        '*Your tenant is not licensed for this feature.*' { 'Required license not available for this tenant' }
        '*AADSTS65001*' { 'AADSTS65001: Required API consent has not been granted for this tenant. The application is missing delegated permission consent for one or more APIs. Try re-running CPV Refresh for this tenant. If already refreshed, check the CPV results for failures and verify the required API service principals exist in the client tenant.' }
        '*AADSTS700082*' { 'The refresh token has expired (tokens expire after 90 days of inactivity). Run the Setup Wizard to re-authenticate and generate new tokens.' }
        '*Account is not provisioned.*' { 'The account is not provisioned. This user does not have the required Microsoft 365 license to access this service (e.g., Exchange Online, Teams, etc.).' }
        '*AADSTS5000224*' { 'This resource is not available - Has this tenant been deleted?' }
        '*AADSTS53003*' { 'Access blocked by Conditional Access policies in this tenant. The tenant may have CA policies that block partner access. Contact the tenant administrator to create an exclusion, or check if the SAM user meets the CA policy requirements (MFA, device compliance, etc.).' }
        '*AADSTS900023*' { 'This tenant is not available for this operation. Please check the selected tenant and try again.' }
        '*AADSTS9002313*' { 'The credentials used to connect to the Graph API are not available, please retry. If this issue persists you may need to execute the SAM wizard.' }
        '*One or more platform(s) is/are not configured for the customer. Please configure the platform before trying to purchase a SKU.*' { 'One or more platform(s) is/are not configured for the customer. Please configure the platform before trying to purchase a SKU.' }
        "One or more added object references already exist for the following modified properties: 'members'." { 'This user is already a member of the selected group.' }
        # Exchange Online common errors -- translated to plain English
        '*is not valid. Please input a valid message identity*' { 'The quarantine entry could not be found - it may have already been released, denied, expired, or purged. Refresh the list and try again.' }
        '*ManagementObjectNotFoundException*' { "The requested object could not be found in this tenant. It may have been deleted, renamed, or never existed. Verify the identity and try again." }
        "*Couldn't find object*" { "The requested object could not be found in this tenant. Verify the identity (UPN, alias, or GUID) is correct and the user/mailbox still exists." }
        '*The operation couldn''t be performed because object*' { "Exchange could not find the target object. Verify the identity is correct and that the mailbox/user still exists. If you just created it, wait 10-15 minutes for replication." }
        '*MailboxNotEnabledForArchive*' { 'This mailbox does not have the archive enabled. Enable the archive first, then retry.' }
        '*The user already has an archive*' { 'This mailbox already has an archive enabled.' }
        '*UserAlreadyExistsException*' { 'A user with this UPN or alias already exists in the tenant.' }
        '*The proxy address*is already being used*' { 'This email address (proxy address) is already assigned to another recipient in the tenant. Choose a different address.' }
        '*The address*is already being used*' { 'This email address is already assigned to another recipient in the tenant.' }
        '*recipient*not found*' { 'The recipient could not be found in this tenant. Verify the address or alias is correct.' }
        '*RecipientTaskException*' { 'Exchange rejected the recipient operation. Verify the user/mailbox exists and you have permission to modify it.' }
        '*MemberAlreadyExistsException*' { 'This user is already a member of that group/permission.' }
        '*MemberNotFoundException*' { 'This user is not currently assigned that permission, so it could not be removed.' }
        '*ACEAlreadyExistsException*' { 'That permission already exists. No change was made.' }
        '*ACENotFoundException*' { 'That permission was not found, so it could not be removed.' }
        '*The mailbox*already has*' { 'The requested setting already matches the current value. No change was made.' }
        '*has expired*' { 'The item has expired and can no longer be processed.' }
        '*release request*already*' { 'A release request for this message has already been submitted and is awaiting administrator review.' }
        '*Get-HostedContentFilterPolicy*' { 'Microsoft''s spam filter service is temporarily unavailable. Wait a few minutes and try again.' }
        '*Set-CASMailbox*not recognized*' { 'The CAS mailbox cmdlet is unavailable for this tenant. Confirm Exchange Online is licensed and enabled.' }
        '*Set-Mailbox*not recognized*' { 'The Set-Mailbox cmdlet is unavailable for this tenant. Confirm Exchange Online is licensed and enabled.' }
        '*Cmdlet*is not recognized*' { 'The required Exchange Online cmdlet is unavailable for this tenant. The tenant may be missing an Exchange Online license, or the SAM user may lack the required role.' }
        '*The term*is not recognized*' { 'The required cmdlet is unavailable. The tenant may be missing the appropriate license, or the SAM user may lack the required role.' }
        '*ManagedFolderAssistant*' { 'The Managed Folder Assistant could not be triggered. The mailbox may be migrating, or the tenant may be unlicensed for retention features.' }
        '*Could not set OOO*' { 'Could not update the Out of Office settings. Check that the mailbox exists and you have the Exchange Recipient Administrator role.' }
        '*MailboxNotMigrated*' { 'This mailbox has not been migrated to Exchange Online and cannot be modified through this interface.' }
        '*tenant*does not have*Exchange*' { 'This tenant does not have an Exchange Online license. Assign an Exchange license to the tenant before retrying.' }
        '*remote server returned an error: (404) Not Found*' { 'The Exchange Online endpoint returned 404 Not Found. The object may have been deleted, or the tenant may be unlicensed.' }
        '*remote server returned an error: (403) Forbidden*' { 'Exchange Online returned 403 Forbidden. The SAM user does not have permission for this operation in this tenant.' }
        default { $message }

    }
}
