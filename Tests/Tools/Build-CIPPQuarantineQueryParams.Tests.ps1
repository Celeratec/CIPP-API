# Pester tests for Build-CIPPQuarantineQueryParams and related quarantine query helpers

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Build-CIPPQuarantineQueryParams.ps1'
    . $FunctionPath
}

Describe 'ConvertTo-CippQuarantineStringArray' {
    It 'parses comma-separated release status values' {
        $result = ConvertTo-CippQuarantineStringArray 'NOTRELEASED,RELEASED'
        $result | Should -Be @('NOTRELEASED', 'RELEASED')
    }

    It 'parses semicolon-separated quarantine types' {
        $result = ConvertTo-CippQuarantineStringArray 'Spam;Phish'
        $result | Should -Be @('Spam', 'Phish')
    }

    It 'returns a single value array for scalar input' {
        $result = ConvertTo-CippQuarantineStringArray 'Malware'
        $result | Should -Be @('Malware')
    }

    It 'normalizes array inputs from autocomplete payloads' {
        $result = ConvertTo-CippQuarantineStringArray @(
            @{ value = 'HostedContentFilterPolicy' },
            @{ value = 'AntiPhishPolicy' }
        )
        $result | Should -Be @('HostedContentFilterPolicy', 'AntiPhishPolicy')
    }
}

Describe 'ConvertTo-CippQuarantineReleaseStatusApiValue' {
    It 'maps frontend release status values to EXO values' {
        ConvertTo-CippQuarantineReleaseStatusApiValue 'NOTRELEASED' | Should -Be 'NotReleased'
        ConvertTo-CippQuarantineReleaseStatusApiValue 'PREPARINGTORELEASE' | Should -Be 'PreparingToRelease'
    }
}

Describe 'Build-CIPPQuarantineQueryParams' {
    It 'applies the default 7-day date range when requested' {
        $testInput = @{}
        $splat = @{ QueryInput = $testInput; ApplyDefaultDateRange = $true }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.AppliedFilters.days | Should -Be 7
        $result.CmdParams.StartReceivedDate | Should -BeOfType [datetime]
        $result.CmdParams.EndReceivedDate | Should -BeOfType [datetime]
        ($result.CmdParams.EndReceivedDate - $result.CmdParams.StartReceivedDate).TotalDays | Should -BeGreaterThan 6
    }

    It 'maps explicit start and end dates' {
        $testInput = @{
            startDate = '2026-01-01T00:00:00Z'
            endDate   = '2026-01-31T23:59:59Z'
        }
        $splat = @{ QueryInput = $testInput }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.CmdParams.StartReceivedDate.ToString('yyyy-MM-dd') | Should -Be '2026-01-01'
        $result.CmdParams.EndReceivedDate.ToString('yyyy-MM-dd') | Should -Be '2026-01-31'
        $result.AppliedFilters.startDate | Should -Not -BeNullOrEmpty
        $result.AppliedFilters.endDate | Should -Not -BeNullOrEmpty
    }

    It 'maps sender and recipient values with guest UPN encoding' {
        $testInput = @{
            sender    = @(@{ value = 'guest#EXT#@contoso.onmicrosoft.com' })
            recipient = @(@{ value = 'user@contoso.com' })
        }
        $splat = @{ QueryInput = $testInput }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.CmdParams.SenderAddress | Should -Be @('guest%23EXT%23@contoso.onmicrosoft.com')
        $result.CmdParams.RecipientAddress | Should -Be @('user@contoso.com')
        $result.AppliedFilters.sender | Should -Be 'guest#EXT#@contoso.onmicrosoft.com'
        $result.AppliedFilters.recipient | Should -Be 'user@contoso.com'
    }

    It 'maps comma-separated release status and policy filters' {
        $testInput = @{
            releaseStatus  = 'NOTRELEASED,REQUESTED'
            quarantineType = 'Spam,Phish'
            policyTypes    = 'HostedContentFilterPolicy,AntiPhishPolicy'
            policyName     = 'Default Spam Policy'
        }
        $splat = @{ QueryInput = $testInput }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.CmdParams.ReleaseStatus | Should -Be @('NotReleased', 'Requested')
        $result.CmdParams.QuarantineTypes | Should -Be @('Spam', 'Phish')
        $result.CmdParams.PolicyTypes | Should -Be @('HostedContentFilterPolicy', 'AntiPhishPolicy')
        $result.CmdParams.PolicyName | Should -Be 'Default Spam Policy'
    }

    It 'maps message ID and skips date filters' {
        $testInput = @{
            messageId = '<abc@contoso.com>'
            days      = 7
        }
        $splat = @{ QueryInput = $testInput; ApplyDefaultDateRange = $true }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.CmdParams.MessageId | Should -Be '<abc@contoso.com>'
        $result.CmdParams.StartReceivedDate | Should -BeNullOrEmpty
        $result.PostFilters.Count | Should -Be 0
    }

    It 'stores subject and domain values as post-filters' {
        $testInput = @{
            subject         = 'invoice'
            senderDomain    = '@example.com'
            recipientDomain = 'contoso.com'
        }
        $splat = @{ QueryInput = $testInput }
        $result = Build-CIPPQuarantineQueryParams @splat

        $result.PostFilters.subjectContains | Should -Be 'invoice'
        $result.PostFilters.senderDomain | Should -Be 'example.com'
        $result.PostFilters.recipientDomain | Should -Be 'contoso.com'
        $result.CmdParams.Subject | Should -BeNullOrEmpty
    }
}

Describe 'Apply-CippQuarantinePostFilters' {
    It 'filters by partial subject and sender domain' {
        $messages = @(
            [pscustomobject]@{ Subject = 'Invoice due'; SenderAddress = 'a@example.com'; RecipientAddress = 'user@contoso.com' },
            [pscustomobject]@{ Subject = 'Hello'; SenderAddress = 'b@other.com'; RecipientAddress = 'user@contoso.com' }
        )
        $postFilters = @{
            subjectContains = 'invoice'
            senderDomain    = 'example.com'
        }

        $result = Apply-CippQuarantinePostFilters -Messages $messages -PostFilters $postFilters
        $result.Count | Should -Be 1
        $result[0].Subject | Should -Be 'Invoice due'
    }
}

Describe 'ConvertTo-CippQuarantineDisplayObject' {
    It 'normalizes release status casing for the frontend' {
        $display = ConvertTo-CippQuarantineDisplayObject -Message ([pscustomobject]@{
                Identity      = 'id-1'
                ReleaseStatus = 'NotReleased'
                SenderAddress = 'sender@contoso.com'
            })

        $display.ReleaseStatus | Should -Be 'NOTRELEASED'
        $display.SenderAddress | Should -Be 'sender@contoso.com'
    }
}
