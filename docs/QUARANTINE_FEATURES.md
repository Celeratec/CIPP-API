# Quarantine Feature Support Notes

Manage365/CIPP quarantine features (v5.13.0) use **Exchange Online PowerShell** via `New-ExoRequest`, not Microsoft Graph or Defender REST quarantine APIs.

See also the [Manage365 README](https://github.com/Celeratec/CIPP) Quarantine Portal section for UI behavior and navigation.

## Supported via `Get-QuarantineMessage`

- Time received range (max 30 days per query; default list uses last 7 days)
- Sender / recipient email address
- Exact subject match (`-Subject`)
- Partial subject match (client-side post-filter)
- Quarantine reason (`-QuarantineTypes`)
- Release status (`-ReleaseStatus`)
- Policy type (`-PolicyTypes`)
- Policy name (`-PolicyName`)
- Message / Internet Message ID (`-MessageId`)
- Server-side pagination (`-Page`, `-PageSize` up to 1000)

## Post-filters (not native EXO parameters)

- Sender domain / recipient domain (parsed from email addresses)
- Subject contains (partial match)

When post-filters are active, `ListMailQuarantine` scans multiple raw EXO pages per request and returns metadata such as `HasPostFilters`, `RawRowsScanned`, `FilteredRowsReturned`, and `PostFilterPaginationLimited`. Export remains the most reliable way to review a large filtered result set.

## Supported actions

| Action | EXO cmdlet | UI status |
|---|---|---|
| Release to all recipients | `Release-QuarantineMessage -ReleaseToAll` | Wired |
| Release to specific users | `Release-QuarantineMessage -User` | API/backend only |
| Deny | `Release-QuarantineMessage -ActionType Deny` | Wired |
| Delete | `Delete-QuarantineMessage` | Wired |
| Submit to Microsoft (false positive) | `Release-QuarantineMessage -ReportFalsePositive` | Wired |
| Preview / download | `Export-QuarantineMessage` | Wired via EML preview |
| Tenant allow/block sender or domain | `New-TenantAllowBlockListItems` | Wired |
| Mailbox safe sender | `Set-MailboxJunkEmailConfiguration` | Backend endpoint only (`ExecMailboxSafeSender`) |

## Not supported / limited

| Defender portal feature | Status |
|---|---|
| Sender display name filter | Not available on `Get-QuarantineMessage` |
| Recipient display name filter | Not available |
| Sending IP on quarantine list | Message trace only (`Get-MessageTraceV2 -FromIP`) |
| Threat Explorer in-app | External deep link only |
| Attachment/URL sandbox verdict in list | Parse EML on preview; not in list API |
| Admin submission portal queue UI | No dedicated EXO cmdlet exposed in CIPP |
| Transport rule creation from quarantine | Use existing transport rule pages only |
| Graph `/security/quarantineMessages` | Not used |

## Permissions

Requires `Exchange.Manage` delegated consent (SAM) and GDAP roles such as Security Administrator / Exchange Administrator in the client tenant. CIPP internal roles:

- `Exchange.SpamFilter.Read` — list/detail/export
- `Exchange.SpamFilter.ReadWrite` — release, deny, delete, allow/block
- `Exchange.TransportRule.Read` — Email Troubleshooter trace leg
- `Exchange.Mailbox.Read` — message trace details

## Performance defaults

- `ListMailQuarantine` returns one paginated page (100 rows, 7-day window) when called with `manualPagination=true`
- Legacy full-dump behavior requires `fetchAll=true`; the old implicit single-call full dump without `fetchAll` is no longer the default
- Detail metadata fetched only via `GetMailQuarantineMessage` on row open
- EML exported only via `ListMailQuarantineMessage` on preview
- AllTenants cache paginates up to 5 pages × 1000 rows per tenant (30-day window)

## Export behavior

- `ExportMailQuarantine` scans up to 5,000 **raw** EXO rows, then applies post-filters
- `Metadata.truncated` reflects the raw EXO row cap, not the final filtered export count
- `Metadata.FilteredRowsReturned` reports the number of rows in the downloaded file

## API query notes

- Quarantine Management sends multi-select GET filters (`releaseStatus`, `quarantineType`, `policyTypes`) as comma-separated strings
- Email Troubleshooter uses POST bodies and may send arrays directly
