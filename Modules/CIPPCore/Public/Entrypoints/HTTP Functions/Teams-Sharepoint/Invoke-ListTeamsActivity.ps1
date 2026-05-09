Function Invoke-ListTeamsActivity {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Activity.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Query.tenantFilter
    $type = $request.Query.Type
    $GraphRequest = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/reports/get$($type)Detail(period='D30')" -tenantid $TenantFilter | ConvertFrom-Csv | Select-Object @{ Name = 'UPN'; Expression = { $_.'User Principal Name' } },
    @{ Name = 'displayName'; Expression = { $_.'Display Name' } },
    @{ Name = 'LastActive'; Expression = { $_.'Last Activity Date' } },
    @{ Name = 'TeamsChat'; Expression = { [int]($_.'Team Chat Message Count') } },
    @{ Name = 'PrivateChat'; Expression = { [int]($_.'Private Chat Message Count') } },
    @{ Name = 'CallCount'; Expression = { [int]($_.'Call Count') } },
    @{ Name = 'MeetingCount'; Expression = { [int]($_.'Meeting Count' ) } },
    @{ Name = 'MeetingsOrganized'; Expression = { [int]($_.'Meetings Organized Count') } },
    @{ Name = 'MeetingsAttended'; Expression = { [int]($_.'Meetings Attended Count') } },
    @{ Name = 'AdHocMeetingsOrganized'; Expression = { [int]($_.'Ad Hoc Meetings Organized Count') } },
    @{ Name = 'AdHocMeetingsAttended'; Expression = { [int]($_.'Ad Hoc Meetings Attended Count') } },
    @{ Name = 'ScheduledMeetingsOrganized'; Expression = { [int]($_.'Scheduled One-time Meetings Organized Count') } },
    @{ Name = 'ScheduledMeetingsAttended'; Expression = { [int]($_.'Scheduled One-time Meetings Attended Count') } },
    @{ Name = 'AudioDuration'; Expression = { $_.'Audio Duration' } },
    @{ Name = 'VideoDuration'; Expression = { $_.'Video Duration' } },
    @{ Name = 'ScreenShareDuration'; Expression = { $_.'Screen Share Duration' } },
    @{ Name = 'hasOtherAction'; Expression = { $_.'Has Other Action' } },
    @{ Name = 'reportRefreshDate'; Expression = { $_.'Report Refresh Date' } },
    @{ Name = 'reportPeriod'; Expression = { $_.'Report Period' } },
    @{ Name = 'totalActivity'; Expression = { [int]($_.'Team Chat Message Count') + [int]($_.'Private Chat Message Count') + [int]($_.'Call Count') + [int]($_.'Meeting Count') } }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @($GraphRequest)
        })

}
