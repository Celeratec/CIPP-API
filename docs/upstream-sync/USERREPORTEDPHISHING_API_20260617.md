# UserReportedPhishing API — Upstream Import

Generated: 2026-06-17  
Branch: `manage365/userreportedphishing-api-20260617`  
Backup tag: `backup/pre-userreportedphishing-api-20260617` → `15df6c850`  
Base: `master` @ `15df6c850` (docs: upstream delta inventory)

## Upstream Commit

| Field | Value |
|-------|-------|
| SHA | `2869564fb` (short: `2869564f`) |
| Title | Add AlertUserReportPhising |
| Author | KelvinTegelaar |
| Date | 2026-05-12 |

## Pre-Apply Verification

`git show --stat 2869564f` — 2 files, 51 insertions:

- `Config/SAMManifest.json`
- `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertUserReportedPhishing.ps1`

No quarantine, Email Troubleshooter, tenant switching, auth flow, `Start-TableCleanup`, or unrelated standards files touched.

## Apply Result

| Status | Detail |
|--------|--------|
| **Applied with adaptation** | Cherry-pick `-x` conflicted on `Config/SAMManifest.json` (fork has additional Graph Role permissions after upstream insertion point). Resolved by keeping all fork permissions and appending the new Role at end of Microsoft Graph `resourceAccess`. Alert handler applied cleanly. |

Applied commit on branch: cherry-pick of `2869564f` (amended to include lib/data manifest parity + this doc).

## Files Changed

| File | Change |
|------|--------|
| `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertUserReportedPhishing.ps1` | **Added** — alert entrypoint |
| `Config/SAMManifest.json` | **Updated** — Graph application permission |
| `Modules/CIPPCore/lib/data/SAMManifest.json` | **Updated** — same permission for fork manifest parity |
| `docs/upstream-sync/USERREPORTEDPHISHING_API_20260617.md` | **Added** — this tracking doc |

## Permission Added

| GUID | Type | Permission | Translator |
|------|------|------------|------------|
| `d72bdbf4-a59b-405c-8b04-5995895819ac` | Role (Application) | `ThreatSubmission.ReadWrite.All` | Present in `Config/PermissionsTranslator.json` and `Modules/CIPPCore/lib/data/PermissionsTranslator.json` |

**CPV/SAM:** `Get-CippSamPermissions` reads `Config/SAMManifest.json`. After merge, run Manage365 CPV permission refresh so client tenants receive `ThreatSubmission.ReadWrite.All` on the CIPP service principal. App registration in MSP tenant must also expose this permission (verify before prod deploy).

## Implementation Notes

- Alert follows CIPPAlerts pattern: `.FUNCTIONALITY Entrypoint`, `Write-AlertTrace`, try/catch with `Write-AlertMessage`.
- Uses app-only Graph: `New-GraphGetRequest ... -AsApp $true` against beta `security/threatSubmission/emailThreats`.
- Filters to user-reported submissions only (`source -eq 'user'`).
- Default lookback: 24 hours (`HoursBack` configurable via alert input).

## Tests

| Suite | Result |
|-------|--------|
| `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | 34 passed |
| `Tests/Tools` | 13 passed |
| **Total** | **47/47 passed** |

No dedicated SAM manifest shape tests in repo.

## Frontend Dependency

**Pending** — do not add CIPP frontend `7054bfc4` (`src/data/alerts.json` `UserReportedPhishing` entry) until:

1. This API branch is reviewed and merged
2. SAM/CPV permission push path is confirmed in non-prod
3. Non-prod alert smoke test passes (or is explicitly waived)

Alert name mapping when frontend is added: `UserReportedPhishing` → `Get-CIPPAlertUserReportedPhishing`.

## Next Steps

1. Open PR from `manage365/userreportedphishing-api-20260617` → `master`
2. Review SAM diff and confirm MSP app registration includes `ThreatSubmission.ReadWrite.All`
3. Merge API PR; trigger CPV permission update
4. Smoke test alert in non-prod tenant (Graph beta emailThreats + user source filter)
5. Then import frontend `7054bfc4` on paired CIPP branch
