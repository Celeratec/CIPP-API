# UserReportedPhishing — Operational Rollout Runbook

Generated: 2026-06-17  
Repo: Celeratec/CIPP-API  
Related: PR #2 (merged), `USERREPORTEDPHISHING_POST_MERGE_20260617.md`

Operator runbook for SAM/CPV permission rollout and backend smoke test **before** enabling the CIPP frontend alert (`7054bfc4`).

---

## 1. Current Status

| Item | Status |
|------|--------|
| API handler merged | Yes — `Get-CIPPAlertUserReportedPhishing` on `master` |
| Frontend alert enabled | **No** — `UserReportedPhishing` not in CIPP `alerts.json` |
| SAM manifest (Config) | `ThreatSubmission.ReadWrite.All` added |
| SAM manifest (lib/data) | Same permission added (fork parity copy) |
| CPV runtime manifest source | **`Config/SAMManifest.json`** via `Get-CippSamPermissions` |
| lib/data manifest | Parity copy only — **not** read by CPV |
| PermissionsTranslator | GUID already mapped — no change required |
| Production permission push | **Not executed** |
| Live backend smoke test | **Not executed** |
| Backup tag | `backup/pre-userreportedphishing-api-20260617` → `15df6c850` |

**Master commits of record:**

| SHA | Description |
|-----|-------------|
| `4b00ffeb6` | Merge PR #2 |
| `7fed45fd7` | Feature: alert handler + SAM manifests |
| `7b6ea11ff` | Post-merge validation doc |

---

## 2. Permission Details

| Field | Value |
|-------|--------|
| **Permission name** | `ThreatSubmission.ReadWrite.All` |
| **GUID** | `d72bdbf4-a59b-405c-8b04-5995895819ac` |
| **Resource** | Microsoft Graph |
| **Resource App ID** | `00000003-0000-0000-c000-000000000000` |
| **Type** | Application / Role |

**Graph API used by alert handler:**

```http
GET https://graph.microsoft.com/beta/security/threatSubmission/emailThreats?$filter=createdDateTime ge {Since}
Authorization: Bearer {app-only token}
```

Handler filters results to `source -eq 'user'`.

---

## 3. Pre-Flight Read-Only Checks

> **Safe:** These steps do not modify permissions or push CPV to tenants.

### Prerequisites

1. Deploy current `master` (includes PR #2) to **non-prod** Function App first.
2. Confirm MSP app registration exposes `ThreatSubmission.ReadWrite.All` in Entra (App registration → API permissions).

### Check A — SAM manifest diff (Manage365 / CIPP UI)

**UI:** CIPP → Advanced → Super Admin → **SAM App Permissions**  
(`src/pages/cipp/advanced/super-admin/sam-app-permissions.js`)

**API (read-only GET):**

```http
GET /api/ExecSAMAppPermissions
```

**PowerShell equivalent (Function App Kudu / debug session with modules loaded):**

```powershell
Get-CippSamPermissions
# Inspect: .MissingPermissions.'00000003-0000-0000-c000-000000000000'.applicationPermissions
```

**Expected before SAM table repair:**

- `MissingPermissions` for Microsoft Graph may include:

```json
{
  "id": "d72bdbf4-a59b-405c-8b04-5995895819ac",
  "value": "ThreatSubmission.ReadWrite.All"
}
```

This is normal until `Update-CippSamPermissions` merges the manifest into the `AppPermissions` table.

### Check B — Access permissions report

**UI:** CIPP → Settings → **Permission Check** (Permissions tab)

**API:**

```http
POST /api/ExecAccessChecks?Type=Permissions&SkipCache=true
```

Runs `Test-CIPPAccessPermissions`, which calls `Get-CippSamPermissions` and reports:

- `MissingPermissions` — SAM permissions not yet in AppPermissions table
- `CPVRefreshList` — tenants whose CPV timestamp is older than last SAM update
- `ErrorMessages` — auth/SAM configuration issues

**Expected before repair:**

- ThreatSubmission may appear under `MissingPermissions`
- Message may indicate tenants need CPV refresh (expected until rollout completes)

### Check C — Local static validation (no Azure)

From repo root on any machine:

```powershell
$GraphAppId = '00000003-0000-0000-c000-000000000000'
$Guid = 'd72bdbf4-a59b-405c-8b04-5995895819ac'
$cfg = Get-Content Config/SAMManifest.json -Raw | ConvertFrom-Json
$graph = $cfg.requiredResourceAccess | Where-Object resourceAppId -eq $GraphAppId
$graph.resourceAccess | Where-Object { $_.id -eq $Guid -and $_.type -eq 'Role' }
```

Should return one Role entry. Repeat against `Modules/CIPPCore/lib/data/SAMManifest.json` for parity confirmation.

---

## 4. Production-Side-Effect Steps

> **WARNING:** Steps below modify MSP SAM configuration and/or tenant service principal permissions.  
> **Require explicit operator approval** before execution. Complete Section 3 first.

### Step 1 — SAM table merge (MSP partner tenant)

Merges manifest permissions into Azure Table `AppPermissions` (`CIPP-SAM` row).

**UI:** Permission Check → **Add Missing Permissions** button  
**API:**

```http
POST /api/ExecPermissionRepair
Content-Type: application/json

{}
```

**Function:** `Update-CippSamPermissions`

**Verify after:**

```http
GET /api/ExecSAMAppPermissions
```

ThreatSubmission should be **absent** from `MissingPermissions`.

### Step 2 — CPV refresh (test tenant first)

**Preferred:** Single tenant before orchestrated rollout.

**UI:** Tenant → CPV / Permissions refresh (or tenant settings equivalent)  
**API (single tenant):**

```http
POST /api/ExecCPVPermissions
Content-Type: application/json

{ "tenantFilter": "<test-tenant-customer-id-or-domain>" }
```

**Function:** `Set-CIPPCPVConsent` + `Add-CIPPApplicationPermission` + `Add-CIPPDelegatedPermission`

**Tenant-wide orchestrator (use only after test tenant succeeds):**

```http
POST /api/ExecCPVRefresh
Content-Type: application/json

{}
```

**Function:** `Start-UpdatePermissionsOrchestrator` → `Push-UpdatePermissionsQueue` per tenant

Internally calls `Add-CIPPApplicationPermission -RequiredResourceAccess 'CIPPDefaults'`, which reads merged permissions from `Get-CippSamPermissions -NoDiff` and grants missing app roles on the CIPP service principal in each tenant.

### Step 3 — Admin consent (test tenant)

After CPV push, in the **test tenant** Entra portal:

1. Enterprise applications → CIPP SAM application
2. Permissions → confirm `ThreatSubmission.ReadWrite.All` appears
3. Grant admin consent if prompted
4. Verify existing application permissions unchanged except the new grant

---

## 5. Test Tenant Smoke Plan

Use **one** internal/non-production managed tenant with Defender reporting enabled.

### 5.1 Permission validation

| Step | Pass criteria |
|------|---------------|
| CPV push completed | No Failed results for ThreatSubmission grant |
| Entra SP permissions | `ThreatSubmission.ReadWrite.All` listed under Application permissions |
| Admin consent | Granted without removing existing roles |
| Existing permissions | Spot-check Graph app role assignments count ≥ pre-rollout count |

### 5.2 Direct Graph probe (app-only)

In Function App context or authenticated harness:

```powershell
$Tenant = '<test-tenant-domain-or-id>'
$Since = (Get-Date).AddHours(-24).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$Uri = "https://graph.microsoft.com/beta/security/threatSubmission/emailThreats?`$filter=createdDateTime ge $Since&`$top=1"
New-GraphGetRequest -uri $Uri -tenantid $Tenant -AsApp $true
```

| Result | Meaning |
|--------|---------|
| 200 + array (possibly empty) | Permission and endpoint OK |
| 403 / Authorization_RequestDenied | Missing consent or app registration permission |
| Other 4xx | Investigate; likely not handler bug |

### 5.3 Alert handler smoke

**Do not** enable `UserReportedPhishing` in global SchedulerConfig.

```powershell
Get-CIPPAlertUserReportedPhishing -TenantFilter '<test-tenant-domain>' -InputValue @{ HoursBack = 24 }
```

| Scenario | Expected |
|----------|----------|
| No user submissions in window | Completes without fatal error; no `Write-AlertTrace` output |
| User-reported submissions exist | `Write-AlertTrace` with filtered records (`source = user`) |
| Missing consent | `Write-AlertMessage` with explicit Graph permission error — **not** unhandled exception |

### 5.4 Sign-off

Record: date, operator, tenant ID/domain, Graph probe result, handler result.  
Attach to this runbook or `USERREPORTEDPHISHING_POST_MERGE_20260617.md`.

---

## 6. Frontend Gate

Frontend CIPP commit **`7054bfc4`** (`src/data/alerts.json` → `UserReportedPhishing`) remains **blocked** until **all** of:

- [ ] API deployed to target environment
- [ ] SAM table merge completed (`ExecPermissionRepair`)
- [ ] CPV refresh completed on test tenant (then prod rollout as approved)
- [ ] Test tenant admin consent confirmed
- [ ] Backend smoke test passed **or explicitly waived**

Alert name mapping when enabled: `UserReportedPhishing` → `Get-CIPPAlertUserReportedPhishing`.

---

## 7. Rollback / Safety

| Control | Guidance |
|---------|----------|
| Dormant handler | Safe — backend function exists but produces no user-visible alerts without frontend + scheduler config |
| Scheduler config | **Do not** globally enable `UserReportedPhishing` until smoke test passes |
| Permission rollback | Removing app role assignment in tenant Entra is manual; test on one tenant before prod-wide CPV |
| Code rollback | Backup tag `backup/pre-userreportedphishing-api-20260617` marks pre-feature `master` (`15df6c850`); revert only if handler causes harm |
| Frontend | Keep `7054bfc4` out of CIPP until backend rollout sign-off |

### Pre-existing manifest parity note

`Config/SAMManifest.json` contains Graph Role `7e05723c-0bb0-42da-be95-ae9f08a6e53c` not present in `lib/data/SAMManifest.json`. This predates UserReportedPhishing and does not block rollout (CPV uses Config only). Address separately if full parity is required.

---

## Quick Reference — Operator Command Summary

| Action | Method | Side effects |
|--------|--------|--------------|
| Read SAM diff | `GET /api/ExecSAMAppPermissions` | None |
| Read access report | `POST /api/ExecAccessChecks?Type=Permissions&SkipCache=true` | None |
| Merge SAM table | `POST /api/ExecPermissionRepair` | **Yes** — MSP table |
| CPV single tenant | `POST /api/ExecCPVPermissions` + `{ tenantFilter }` | **Yes** — one tenant |
| CPV all tenants | `POST /api/ExecCPVRefresh` | **Yes** — all eligible tenants |
| Smoke handler | `Get-CIPPAlertUserReportedPhishing -TenantFilter ... -InputValue @{ HoursBack = 24 }` | Read-only Graph query |

---

## Related Docs

- `docs/upstream-sync/USERREPORTEDPHISHING_API_20260617.md` — import tracking
- `docs/upstream-sync/USERREPORTEDPHISHING_POST_MERGE_20260617.md` — post-merge validation record
