function Invoke-CippGraphWebhookRenewal {
    $StartTime = Get-Date
    $MaxExecutionMinutes = 8  # Leave buffer before 10-minute timeout
    $RenewalDate = (Get-Date).AddDays(1).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $body = @{
        'expirationDateTime' = "$RenewalDate"
    } | ConvertTo-Json

    $Tenants = Get-Tenants -IncludeErrors
    $TenantDomains = $Tenants.defaultDomainName
    $TenantCustomerIds = $Tenants.customerId

    $WebhookTable = Get-CIPPTable -TableName webhookTable
    try {
        $WebhookData = Get-AzDataTableEntity @WebhookTable | Where-Object { $null -ne $_.SubscriptionID -and $_.SubscriptionID -ne '' -and ((Get-Date($_.Expiration)) -le ((Get-Date).AddHours(2))) }
    } catch {
        $WebhookData = @()
    }

    $WebhookCount = ($WebhookData | Measure-Object).Count
    if ($WebhookCount -gt 0) {
        Write-LogMessage -API 'Scheduler_RenewGraphSubscriptions' -tenant 'none' -message "Starting Graph Subscription Renewal for $WebhookCount webhooks" -sev Info

        $ProcessedCount = 0
        $SuccessCount = 0
        $FailedCount = 0
        $SkippedCount = 0

        foreach ($UpdateSub in $WebhookData) {
            # Check if we're approaching the timeout
            $ElapsedMinutes = ((Get-Date) - $StartTime).TotalMinutes
            if ($ElapsedMinutes -ge $MaxExecutionMinutes) {
                $RemainingCount = $WebhookCount - $ProcessedCount
                Write-LogMessage -API 'Scheduler_RenewGraphSubscriptions' -tenant 'none' -message "Stopping webhook renewal after $ProcessedCount of $WebhookCount - approaching timeout. $RemainingCount webhooks will be processed in next run." -sev Warning
                break
            }

            $ProcessedCount++
            try {
                $TenantFilter = $UpdateSub.PartitionKey
                if ($TenantDomains -notcontains $TenantFilter -and $TenantCustomerIds -notcontains $TenantFilter) {
                    Write-LogMessage -API 'Renew_Graph_Subscriptions' -message "Removing Subscription Renewal for $($UpdateSub.SubscriptionID) as tenant $TenantFilter is not in the tenant list." -Sev 'Warning' -tenant $TenantFilter
                    try {
                        Remove-AzDataTableEntity -Force @WebhookTable -Entity $UpdateSub -ErrorAction Stop
                    } catch {
                        # Ignore if entity was already deleted (404/ResourceNotFound)
                        if ($_.Exception.Message -notmatch 'does not exist|ResourceNotFound') {
                            throw
                        }
                    }
                    $SkippedCount++
                    continue
                }

                try {
                    $null = New-GraphPostRequest -uri "https://graph.microsoft.com/beta/subscriptions/$($UpdateSub.SubscriptionID)" -tenantid $TenantFilter -type PATCH -body $body -Verbose
                    $UpdateSub.Expiration = $RenewalDate
                    $null = Add-AzDataTableEntity @WebhookTable -Entity $UpdateSub -Force
                    $SuccessCount++

                } catch {
                    # Rebuild creation parameters
                    $BaseURL = "$(([uri]($UpdateSub.WebhookNotificationUrl)).Host)"
                    if ($UpdateSub.TypeofSubscription) {
                        $TypeofSubscription = "$($UpdateSub.TypeofSubscription)"
                    } else {
                        $TypeofSubscription = 'updated'
                    }
                    $Resource = "$($UpdateSub.Resource)"
                    $EventType = "$($UpdateSub.EventType)"

                    Write-LogMessage -API 'Renew_Graph_Subscriptions' -message "Recreating: $($UpdateSub.SubscriptionID) as renewal failed." -Sev 'Info' -tenant $TenantFilter
                    $CreateResult = New-CIPPGraphSubscription -TenantFilter $TenantFilter -TypeofSubscription $TypeofSubscription -BaseURL $BaseURL -Resource $Resource -EventType $EventType -Headers 'GraphSubscriptionRenewal' -Recreate

                    if ($CreateResult -match 'Created Webhook subscription for') {
                        try {
                            Remove-AzDataTableEntity -Force @WebhookTable -Entity $UpdateSub -ErrorAction Stop
                        } catch {
                            # Ignore if entity was already deleted (404/ResourceNotFound)
                            if ($_.Exception.Message -notmatch 'does not exist|ResourceNotFound') {
                                throw
                            }
                        }
                        $SuccessCount++
                    } else {
                        $FailedCount++
                    }
                }
            } catch {
                Write-LogMessage -API 'Renew_Graph_Subscriptions' -message "Failed to renew Webhook Subscription: $($UpdateSub.SubscriptionID). Error: $($_.Exception.message)" -Sev 'Error' -tenant $TenantFilter
                $FailedCount++
            }

            # Log progress every 50 webhooks
            if ($ProcessedCount % 50 -eq 0) {
                $ElapsedMinutes = [math]::Round(((Get-Date) - $StartTime).TotalMinutes, 2)
                Write-LogMessage -API 'Scheduler_RenewGraphSubscriptions' -tenant 'none' -message "Webhook renewal progress: $ProcessedCount/$WebhookCount processed in $ElapsedMinutes minutes" -sev Info
            }
        }

        $TotalElapsed = [math]::Round(((Get-Date) - $StartTime).TotalMinutes, 2)
        Write-LogMessage -API 'Scheduler_RenewGraphSubscriptions' -tenant 'none' -message "Completed Graph Subscription Renewal: $SuccessCount succeeded, $FailedCount failed, $SkippedCount skipped out of $ProcessedCount processed in $TotalElapsed minutes" -sev Info
    }
}
