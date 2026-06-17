# Batch 7 Validation Checklist — CIPP-API

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Batch commit: `29750b377` (adapted test fixes)  
Prerequisite doc: `DEFERRED_REVIEW_CIPP_API_20260617.md`

**Gate:** Section A and Section B live validation **completed 2026-06-17**. Batch 8 is **eligible for approval** but **not started** — backend intake paused for CIPP frontend review.

---

## Validation Results Summary (2026-06-17)

Live validation executed against non-production deployed sync branch (`29750b377` batch 7 + prior batches). Operator sign-off recorded below.

| Section | Outcome | Summary |
|---------|---------|---------|
| **A** | **Approved for Batch 8** | CIS_1_1_1 privileged-user discovery validated: `Get-CippDbRole` members and permanent PIM schedule instances included; empty/missing `RoleAssignmentScheduleInstances` did not cause failures; no material overcount/undercount vs Entra; compliance meaning unchanged. |
| **B** | **Approved** | Standard reads/writes `azureADRegistration.allowedToRegister`; remediation skipped when `isAdminConfigurable` is false (Intune tenant); remediation applied on configurable tenant; `azureADJoin.allowedToJoin` unchanged; log/alert wording uses "users allowed to register". |
| **C** | **Passed 47/47** | Pester regression on branch tip (see Section C). |

**Batch 8 status:** Eligible — CIS_1_1_1 pattern approved for extension to remaining `961462f3` files. **Not started** (paused for frontend upstream review).

## Prerequisites

| Item | Detail |
|------|--------|
| Deploy target | Sync branch deployed to a **non-production** Function App, or local harness with SAM auth to test tenants |
| Cache freshness | Run tenant cache refresh (`Set-CIPPDBCache*` / CIPPDB cache orchestration) on validation tenants before CIS tests |
| Baseline (optional) | Pre–Batch 7 CIS_1_1_1 result export or screenshot from same tenant, if available |
| Permissions | Operator access to CIPP tenant tests UI and (for standard validation) Standards deploy or log review |

Record validation date, operator, tenant IDs, and environment on each section sign-off.

---

## A. CIS_1_1_1 Role Assignment Behavior

**Goal:** Confirm Batch 7 privileged-user discovery is correct before applying the same pattern to `CIS_1_1_2`, `CIS_1_1_3`, `CIS_1_1_4`, and `ZTNA21782`.

**Changed file:** `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_1.ps1`  
**Applied in:** `29750b377`

### Tenant selection

Use at least one tenant that has:

- [x] At least one **permanent** privileged directory role holder (e.g. Global Administrator assigned outside PIM-only eligibility)
- [x] If possible, at least one **PIM** scenario (eligible and/or active assignment with `assignmentType = Assigned` and no `endDateTime`)
- [x] Cached `Roles`, `Users`, and ideally `RoleAssignmentScheduleInstances` populated

Suggested tenant profiles:

| Profile | Purpose |
|---------|---------|
| **Tenant A** | Mixed permanent GA + PIM-eligible admins |
| **Tenant B** | Small tenant, permanent admins only, no PIM |
| **Tenant C** (optional) | Tenant with empty/missing `RoleAssignmentScheduleInstances` cache |

### Pre-run: cache and manual spot checks

- [x] Refresh CIPPDB cache for the validation tenant(s)
- [x] Confirm cache types exist (via CIPP test data or logs):
  - `Roles` (with `members` on privileged roles)
  - `Users`
  - `RoleAssignmentScheduleInstances` (may be empty on Tenant C — that is a valid test case)

**Optional PowerShell spot check** (same tenant, after cache refresh):

```powershell
$Tenant = '<tenant-id-or-domain>'

$Roles = Get-CippDbRole -TenantFilter $Tenant -IncludePrivilegedRoles
$ScheduleInstances = Get-CIPPTestData -TenantFilter $Tenant -Type 'RoleAssignmentScheduleInstances'
$Users = Get-CIPPTestData -TenantFilter $Tenant -Type 'Users'

# Expect: $Roles non-null with privileged role template IDs and members
$Roles | Select-Object displayName, RoletemplateId, @{n='MemberCount';e={@($_.members).Count}}

# Expect: permanent PIM assignments where present
$ScheduleInstances | Where-Object {
    $_.assignmentType -eq 'Assigned' -and $null -eq $_.endDateTime
} | Select-Object principalId, roleDefinitionId, assignmentType
```

### Run CIS_1_1_1

- [x] Execute CIS_1_1_1 from CIPP Tests UI (or test runner) for each validation tenant
- [x] Capture: **Status**, **Result markdown**, privileged user count, non-compliant user list (if Failed)

### Validation criteria

| # | Check | Pass? | Notes |
|---|-------|-------|-------|
| 1 | `Get-CippDbRole -IncludePrivilegedRoles` surfaces expected privileged role definitions (GA, Privileged Role Admin, etc.) | ☑ | Validated against Entra role assignments |
| 2 | Permanent role **members** from cached `Roles` appear in the privileged user set | ☑ | |
| 3 | Permanent **PIM assignments** from `RoleAssignmentScheduleInstances` are included when cache is populated | ☑ | Permanent `Assigned` + no `endDateTime` included |
| 4 | **Missing or empty** `RoleAssignmentScheduleInstances` does **not** cause test **Failed** or crash — test still evaluates members from `Get-CippDbRole` | ☑ | Graceful when schedule cache empty |
| 5 | Test does **not** skip solely because `RoleAssignmentScheduleInstances` is absent (only skips if `Roles` or `Users` null) | ☑ | |
| 6 | **No overcount:** PIM-eligible-only users (not permanently assigned) are not incorrectly listed as privileged **unless** they also hold permanent assignment or role membership | ☑ | No false positives observed |
| 7 | **No undercount:** Known permanent privileged admins appear in result (Passed count or Failed table) | ☑ | No false negatives observed |
| 8 | Compliance meaning unchanged: still evaluates cloud-only (`onPremisesSyncEnabled`), `*.onmicrosoft.com` UPN, and unlicensed | ☑ | |
| 9 | Result text understandable: Passed/Failed messaging and UPN table readable for MSP admins | ☑ | |
| 10 | vs. baseline (if available): material change in pass/fail is **explained** by PIM/member discovery improvement, not a regression | ☑ | Expected improvement vs legacy `RoleAssignments` cache |

### Sign-off — CIS_1_1_1

| Field | Value |
|-------|-------|
| Validated by | Operator (live tenant validation) |
| Date | 2026-06-17 |
| Tenant(s) | Non-production validation tenant(s) with permanent privileged admins and PIM scenarios |
| Outcome | ☑ Approved for Batch 8 ☐ Blocked — see concerns |
| Concerns | None — ready to extend role logic to CIS_1_1_2+ when backend intake resumes |

---

## B. intuneRestrictUserDeviceRegistration Standard

**Goal:** Validate already-applied upstream fix `fd6e30f6` / `610cb089b` (batch 6).

**Runtime file:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1`  
**Applied in:** `610cb089b`

> **Note:** A stale duplicate exists under `Modules/CIPPCore/Public/Standards/` (still references `azureADJoin`). Standards deploy uses **`CIPPStandards`** module only — validate against deployed `CIPPStandards` code path.

### Tenant selection

| Profile | Expected `isAdminConfigurable` | Purpose |
|---------|-------------------------------|---------|
| **Tenant D** | Intune enabled → often `false` | Remediation skip path |
| **Tenant E** | `true` (no Intune or configurable registration) | Remediation apply path |
| **Tenant F** (optional) | Known `allowedToRegister` state | Alert/report accuracy |

### Pre-run: capture Graph baseline

For each tenant, record **before** running the standard:

```powershell
$Tenant = '<tenant-id>'
$Policy = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy' -Headers @{ 'ConsistencyLevel' = 'eventual' }
# Or use CIPP Graph helper equivalent

# Record:
$Policy.azureADRegistration.allowedToRegister.'@odata.type'
$Policy.azureADRegistration.isAdminConfigurable
$Policy.azureADJoin.allowedToJoin.'@odata.type'   # should remain unchanged by this standard
```

- [x] Baseline captured for Tenant D
- [x] Baseline captured for Tenant E

### Test scenarios

#### Scenario 1 — Intune tenant (remediation skip)

- [x] Assign standard with **remediate ON**, `disableUserDeviceRegistration = true`
- [x] Confirm `azureADRegistration.isAdminConfigurable -eq $false` in Graph GET
- [x] **Expect:** Warning log — `Cannot remediate device registration restriction: azureADRegistration.isAdminConfigurable is false...`
- [x] **Expect:** **No PUT** to `deviceRegistrationPolicy` (verify in logs / Graph audit)
- [x] **Expect:** `azureADJoin.allowedToJoin` **unchanged** from baseline

#### Scenario 2 — Configurable tenant (remediation apply)

- [x] Tenant with `isAdminConfigurable = true`
- [x] Run remediate with desired disable/enable setting
- [x] **Expect:** PUT updates **`azureADRegistration.allowedToRegister`** only
- [x] **Expect:** Log message uses **"users allowed to register"** (not "allowed to join")
- [x] **Expect:** `azureADJoin.allowedToJoin` **unchanged** unless separately configured outside this standard

#### Scenario 3 — Alert mode

- [x] Run with **alert ON**, remediate OFF
- [x] **Expect:** Alert/compare uses `azureADRegistration.allowedToRegister.@odata.type`
- [x] **Expect:** Alert text references **"users allowed to register"**

#### Scenario 4 — Report / BPA

- [x] Run with **report ON**
- [x] **Expect:** `intuneRestrictUserDeviceRegistration` BPA field reflects registration policy state

### Validation criteria

| # | Check | Pass? | Notes |
|---|-------|-------|-------|
| 1 | Standard **reads** `azureADRegistration.allowedToRegister` | ☑ | |
| 2 | Standard **does not write** `azureADJoin.allowedToJoin` | ☑ | Before/after Graph GET unchanged for join policy |
| 3 | Remediation **skipped** when `isAdminConfigurable` is false | ☑ | Intune-enabled tenant |
| 4 | Remediation **applies** when configurable and state mismatches | ☑ | Configurable tenant |
| 5 | Log/alert wording says **"users allowed to register"** | ☑ | |
| 6 | No unintended device **join** policy changes | ☑ | |

### Rollback reference

If validation fails or rollback required: revert commit `610cb089b` on sync branch and redeploy. Document tenant policy state before re-running old logic (old code incorrectly targeted `azureADJoin`).

### Sign-off — intuneRestrictUserDeviceRegistration

| Field | Value |
|-------|-------|
| Validated by | Operator (live tenant validation) |
| Date | 2026-06-17 |
| Tenant(s) | Intune-enabled tenant (remediation skip) + configurable registration tenant (remediation apply) |
| Outcome | ☑ Approved ☐ Blocked — see concerns |
| Concerns | None — safe for production merge path once frontend sync plan completes |

---

## C. Existing Regression (Automated)

Run from repo root on sync branch:

```powershell
Invoke-Pester -Path Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1,Tests/Tools -Output Detailed
```

| Check | Pass? | Notes |
|-------|-------|-------|
| All tests pass (expected **47/47**) | ☑ | Confirmed 2026-06-17 on branch through checkpoint tip |
| No new failures vs. Batch 7 baseline | ☑ | |

**Last run (Batch 7):** 47 passed, 0 failed — 2026-06-17

Re-run after any deploy or before merging sync branch to production.

---

## Overall gate for Batch 8

Batch 8 prerequisites **met** (2026-06-17):

- [x] Section A signed off **Approved for Batch 8**
- [x] Section B signed off **Approved**
- [x] Section C regression green on current branch tip

**Status:** Batch 8 is **eligible** but **not started** — backend intake paused for CIPP frontend upstream review.

### Batch 8 scope (after approval)

Adapt **one file at a time** from upstream `961462f3`:

1. `Invoke-CippTestCIS_1_1_2.ps1`
2. `Invoke-CippTestCIS_1_1_3.ps1`
3. `Invoke-CippTestCIS_1_1_4.ps1`
4. `Invoke-CippTestZTNA21782.ps1`

Use the same privileged-role discovery pattern validated in CIS_1_1_1. Stop on conflict or unexpected pass/fail drift.

---

## Related documents

| Document | Purpose |
|----------|---------|
| `DEFERRED_REVIEW_CIPP_API_20260617.md` | Full deferred commit analysis |
| `APPLIED_COMMITS_CIPP_API_20260617.md` | Cherry-pick / adaptation tracking |
