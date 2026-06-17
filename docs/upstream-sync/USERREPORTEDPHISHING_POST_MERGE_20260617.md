# UserReportedPhishing API — Post-Merge Validation

Generated: 2026-06-17  
Repo: Celeratec/CIPP-API  
Master tip: `4b00ffeb6`

## Merge Summary

| Field | Value |
|-------|--------|
| **PR** | https://github.com/Celeratec/CIPP-API/pull/2 |
| **Merge commit** | `4b00ffeb6` |
| **Feature commit** | `7fed45fd7` |
| **Title** | Add user reported phishing alert backend |
| **Backup tag (retained)** | `backup/pre-userreportedphishing-api-20260617` → `15df6c850` |

## Files Merged

| File | Change |
|------|--------|
| `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertUserReportedPhishing.ps1` | New alert handler |
| `Config/SAMManifest.json` | +1 Graph application Role |
| `Modules/CIPPCore/lib/data/SAMManifest.json` | +1 Graph application Role (fork parity) |
| `docs/upstream-sync/USERREPORTEDPHISHING_API_20260617.md` | Import tracking doc |

## Pester Regression

| Suite | Result |
|-------|--------|
| `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | 34 passed |
| `Tests/Tools` | 13 passed |
| **Total (post-merge re-run)** | **47/47 passed** |

## SAM Manifest Status

| Item | Status |
|------|--------|
| Permission GUID | `d72bdbf4-a59b-405c-8b04-5995895819ac` |
| Permission name | `ThreatSubmission.ReadWrite.All` |
| Graph resource app ID | `00000003-0000-0000-c000-000000000000` |
| Permission type | Role (Application) |
| In `Config/SAMManifest.json` | Yes |
| In `Modules/CIPPCore/lib/data/SAMManifest.json` | Yes |
| `PermissionsTranslator.json` mapping | Already present (no change required) |
| Roles removed vs pre-merge | **None** (append-only) |
| Roles added vs pre-merge | ThreatSubmission only (both manifests) |

### Pre-existing SAM parity gap (unchanged by this PR)

`Config/SAMManifest.json` contains Graph Role `7e05723c-0bb0-42da-be95-ae9f08a6e53c` that `Modules/CIPPCore/lib/data/SAMManifest.json` lacks. This PR did **not** widen the gap — both manifests received the same new permission. CPV runtime reads **`Config/SAMManifest.json`** via `Get-CippSamPermissions`.

Graph Role counts after merge: Config **62**, lib/data **61**.

## Frontend Status

**Still deferred.** Do not add CIPP frontend `7054bfc4` (`src/data/alerts.json` `UserReportedPhishing` entry) until SAM/CPV rollout, tenant consent, and non-prod backend smoke test are complete (or explicitly waived).

---

## Task 2 — SAM / CPV Permission Rollout Path

### How permissions flow in this fork

```text
Config/SAMManifest.json
        │
        ▼
Get-CippSamPermissions          ← compares manifest vs AppPermissions table
        │
        ├── MissingPermissions diff (dry-run signal)
        │
        ▼
Update-CippSamPermissions       ← Invoke-ExecPermissionRepair (MSP table merge)
        │
        ▼
AppPermissions table (CIPP-SAM)
        │
        ▼
Start-UpdatePermissionsOrchestrator  ← Invoke-ExecCPVRefresh (tenant push)
        │
        ▼
Push-UpdatePermissionsQueue per tenant
        │
        ├── Add-CIPPApplicationPermission (CIPPDefaults → app Roles)
        └── Add-CIPPDelegatedPermission
```

**Note:** `Modules/CIPPCore/lib/data/SAMManifest.json` is maintained for fork parity but is **not** read by `Get-CippSamPermissions`. Only `Config/SAMManifest.json` drives CPV.

### Dry-run / read-only validation (recommended before any push)

No dedicated `-WhatIf` / dry-run flag exists on CPV orchestration. Use these **read-only** steps in non-prod Manage365/CIPP:

| Step | Endpoint / function | Purpose |
|------|---------------------|---------|
| 1 | `Invoke-ExecSAMAppPermissions` (GET, default action) | Returns `Get-CippSamPermissions` output including `MissingPermissions` |
| 2 | CIPP Settings → Access Check / `Test-CIPPAccessPermissions` | Surfaces missing SAM permissions and tenants needing CPV refresh |
| 3 | Local static validation (below) | Confirms manifest JSON, GUID, translator, no regressions |

**Expected dry-run signal after deploy:** `MissingPermissions` for Microsoft Graph should include:

```json
{
  "id": "d72bdbf4-a59b-405c-8b04-5995895819ac",
  "value": "ThreatSubmission.ReadWrite.All"
}
```

until `Update-CippSamPermissions` merges it into the `AppPermissions` table.

### Static validation (local, 2026-06-17)

Executed against `master` @ `4b00ffeb6` without Azure connectivity:

| Check | Result |
|-------|--------|
| Config JSON valid | Pass |
| lib/data JSON valid | Pass |
| Target GUID in Config | Pass |
| Target GUID in lib/data | Pass |
| Permission type Role | Pass |
| Graph resource app ID | Pass |
| PermissionsTranslator maps GUID → `ThreatSubmission.ReadWrite.All` | Pass |
| Config roles removed vs pre-merge | **None** |
| lib/data roles removed vs pre-merge | **None** |
| Config roles added | `d72bdbf4-...` only |
| lib/data roles added | `d72bdbf4-...` only |
| Pre-existing Config-only role `7e05723c-...` preserved | Pass |

### Production push steps (operator — not executed in this session)

Requires explicit approval and non-prod validation first:

1. **Deploy** `master` @ `4b00ffeb6` to non-prod Function App.
2. **MSP SAM table merge:** CIPP Settings → Permission Repair (`Invoke-ExecPermissionRepair` / `Update-CippSamPermissions`).
3. **Verify** `ExecSAMAppPermissions` GET shows no missing Graph application permissions (or ThreatSubmission absent from `MissingPermissions`).
4. **CPV refresh (single test tenant first):** `Invoke-ExecCPVPermissions` for one internal tenant, or `Invoke-ExecCPVRefresh` for orchestrated rollout after test-tenant success.
5. **Confirm** CIPP service principal in test tenant has `ThreatSubmission.ReadWrite.All` app role assignment on Microsoft Graph resource SP.
6. **Prod rollout** only after non-prod smoke test passes.

**Not run:** `Start-UpdatePermissionsOrchestrator` / tenant-wide CPV push (production side effect).

---

## Task 3 — Test Tenant Readiness

**Status: BLOCKED — requires deployed non-prod Function App**

This validation session had no Azure Function App runtime, SAM tokens, or tenant credentials. Operator must complete in non-prod:

| Check | How |
|-------|-----|
| Service principal can receive permission | Entra → Enterprise apps → CIPP SAM app → Permissions; confirm `ThreatSubmission.ReadWrite.All` listed |
| Admin consent completable | Grant admin consent in test tenant after CPV push |
| Existing permissions intact | Compare app role assignments before/after CPV on Graph resource SP |
| Graph beta endpoint reachable | App-only GET `https://graph.microsoft.com/beta/security/threatSubmission/emailThreats?$top=1` in test tenant |

Suggested tenant: internal/non-production managed tenant with Defender for Office 365 reporting enabled.

---

## Task 4 — Backend Smoke Test

**Status: BLOCKED — requires deployed non-prod Function App**

Safest execution paths (do **not** enable frontend alert globally):

### Option A — Direct function invoke (non-prod only)

```powershell
# After SAM auth and module import in Function App context or local harness with CIPPRootPath set
Get-CIPPAlertUserReportedPhishing -TenantFilter '<test-tenant-domain>' -InputValue @{ HoursBack = 24 }
```

### Option B — Scheduler bridge (only if alert enabled in SchedulerConfig for test tenant)

`Push-SchedulerAlert` calls `Get-CIPPAlertUserReportedPhishing` when `UserReportedPhishing` is enabled in tenant alert config. **Do not enable globally** — use Option A or a one-off scheduler row for test tenant only.

### Expected outcomes

| Scenario | Expected |
|----------|----------|
| No user submissions in window | No alert trace; no fatal error |
| User submissions exist | `Write-AlertTrace` output with filtered records |
| Missing consent | Explicit Graph permission error via `Write-AlertMessage`; attributable to missing `ThreatSubmission.ReadWrite.All`, not code failure |

**Not executed in this session.**

---

## Frontend Gate Decision

| Question | Answer |
|----------|--------|
| Can frontend alert proceed? | **No** |
| Blockers | (1) Non-prod deploy of merged API not confirmed in this session; (2) `Update-CippSamPermissions` + CPV push not run; (3) Test tenant consent not verified; (4) `Get-CIPPAlertUserReportedPhishing` live smoke test not run |

### Unblock sequence

1. Deploy `master` to non-prod Function App
2. Run SAM permission repair (MSP) → confirm ThreatSubmission in AppPermissions table
3. CPV refresh on one test tenant → grant admin consent
4. Smoke test handler (Option A above)
5. Operator sign-off or explicit waiver
6. Then open CIPP frontend PR for `7054bfc4`

---

## Related Docs

- Import tracking: `docs/upstream-sync/USERREPORTEDPHISHING_API_20260617.md`
- Upstream delta: `docs/upstream-sync/UPSTREAM_DELTA_CIPP_API_20260617.md`
