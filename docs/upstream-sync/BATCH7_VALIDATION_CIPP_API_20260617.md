# Batch 7 Validation Checklist — CIPP-API

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Batch commit: `29750b377` (adapted test fixes)  
Prerequisite doc: `DEFERRED_REVIEW_CIPP_API_20260617.md`

**Gate:** Do **not** start Batch 8 (`961462f3` remaining files) until this checklist is completed or CIS_1_1_1 validation is explicitly approved to proceed.

---

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

- [ ] At least one **permanent** privileged directory role holder (e.g. Global Administrator assigned outside PIM-only eligibility)
- [ ] If possible, at least one **PIM** scenario (eligible and/or active assignment with `assignmentType = Assigned` and no `endDateTime`)
- [ ] Cached `Roles`, `Users`, and ideally `RoleAssignmentScheduleInstances` populated

Suggested tenant profiles:

| Profile | Purpose |
|---------|---------|
| **Tenant A** | Mixed permanent GA + PIM-eligible admins |
| **Tenant B** | Small tenant, permanent admins only, no PIM |
| **Tenant C** (optional) | Tenant with empty/missing `RoleAssignmentScheduleInstances` cache |

### Pre-run: cache and manual spot checks

- [ ] Refresh CIPPDB cache for the validation tenant(s)
- [ ] Confirm cache types exist (via CIPP test data or logs):
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

- [ ] Execute CIS_1_1_1 from CIPP Tests UI (or test runner) for each validation tenant
- [ ] Capture: **Status**, **Result markdown**, privileged user count, non-compliant user list (if Failed)

### Validation criteria

| # | Check | Pass? | Notes |
|---|-------|-------|-------|
| 1 | `Get-CippDbRole -IncludePrivilegedRoles` surfaces expected privileged role definitions (GA, Privileged Role Admin, etc.) | ☐ | |
| 2 | Permanent role **members** from cached `Roles` appear in the privileged user set | ☐ | Compare to Entra admin center role assignments |
| 3 | Permanent **PIM assignments** from `RoleAssignmentScheduleInstances` are included when cache is populated | ☐ | Users with `Assigned` + no `endDateTime` on privileged template IDs |
| 4 | **Missing or empty** `RoleAssignmentScheduleInstances` does **not** cause test **Failed** or crash — test still evaluates members from `Get-CippDbRole` | ☐ | Use Tenant C or temporarily verify empty cache |
| 5 | Test does **not** skip solely because `RoleAssignmentScheduleInstances` is absent (only skips if `Roles` or `Users` null) | ☐ | |
| 6 | **No overcount:** PIM-eligible-only users (not permanently assigned) are not incorrectly listed as privileged **unless** they also hold permanent assignment or role membership | ☐ | |
| 7 | **No undercount:** Known permanent privileged admins appear in result (Passed count or Failed table) | ☐ | |
| 8 | Compliance meaning unchanged: still evaluates cloud-only (`onPremisesSyncEnabled`), `*.onmicrosoft.com` UPN, and unlicensed | ☐ | |
| 9 | Result text understandable: Passed/Failed messaging and UPN table readable for MSP admins | ☐ | |
| 10 | vs. baseline (if available): material change in pass/fail is **explained** by PIM/member discovery improvement, not a regression | ☐ | |

### Sign-off — CIS_1_1_1

| Field | Value |
|-------|-------|
| Validated by | |
| Date | |
| Tenant(s) | |
| Outcome | ☐ Approved for Batch 8 ☐ Blocked — see concerns |
| Concerns | |

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

- [ ] Baseline captured for Tenant D
- [ ] Baseline captured for Tenant E

### Test scenarios

#### Scenario 1 — Intune tenant (remediation skip)

- [ ] Assign standard with **remediate ON**, `disableUserDeviceRegistration = true`
- [ ] Confirm `azureADRegistration.isAdminConfigurable -eq $false` in Graph GET
- [ ] **Expect:** Warning log — `Cannot remediate device registration restriction: azureADRegistration.isAdminConfigurable is false...`
- [ ] **Expect:** **No PUT** to `deviceRegistrationPolicy` (verify in logs / Graph audit)
- [ ] **Expect:** `azureADJoin.allowedToJoin` **unchanged** from baseline

#### Scenario 2 — Configurable tenant (remediation apply)

- [ ] Tenant with `isAdminConfigurable = true`
- [ ] Run remediate with desired disable/enable setting
- [ ] **Expect:** PUT updates **`azureADRegistration.allowedToRegister`** only
- [ ] **Expect:** Log message uses **"users allowed to register"** (not "allowed to join")
- [ ] **Expect:** `azureADJoin.allowedToJoin` **unchanged** unless separately configured outside this standard

#### Scenario 3 — Alert mode

- [ ] Run with **alert ON**, remediate OFF
- [ ] **Expect:** Alert/compare uses `azureADRegistration.allowedToRegister.@odata.type`
- [ ] **Expect:** Alert text references **"users allowed to register"**

#### Scenario 4 — Report / BPA

- [ ] Run with **report ON**
- [ ] **Expect:** `intuneRestrictUserDeviceRegistration` BPA field reflects registration policy state

### Validation criteria

| # | Check | Pass? | Notes |
|---|-------|-------|-------|
| 1 | Standard **reads** `azureADRegistration.allowedToRegister` | ☐ | |
| 2 | Standard **does not write** `azureADJoin.allowedToJoin` | ☐ | Compare before/after Graph GET |
| 3 | Remediation **skipped** when `isAdminConfigurable` is false | ☐ | Tenant D |
| 4 | Remediation **applies** when configurable and state mismatches | ☐ | Tenant E |
| 5 | Log/alert wording says **"users allowed to register"** | ☐ | |
| 6 | No unintended device **join** policy changes | ☐ | |

### Rollback reference

If validation fails or rollback required: revert commit `610cb089b` on sync branch and redeploy. Document tenant policy state before re-running old logic (old code incorrectly targeted `azureADJoin`).

### Sign-off — intuneRestrictUserDeviceRegistration

| Field | Value |
|-------|-------|
| Validated by | |
| Date | |
| Tenant(s) | |
| Outcome | ☐ Approved ☐ Blocked — see concerns |
| Concerns | |

---

## C. Existing Regression (Automated)

Run from repo root on sync branch:

```powershell
Invoke-Pester -Path Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1,Tests/Tools -Output Detailed
```

| Check | Pass? | Notes |
|-------|-------|-------|
| All tests pass (expected **47/47**) | ☐ | Last known good after Batch 7: 47 passed |
| No new failures vs. Batch 7 baseline | ☐ | |

**Last run (Batch 7):** 47 passed, 0 failed — 2026-06-17

Re-run after any deploy or before merging sync branch to production.

---

## Overall gate for Batch 8

Batch 8 may proceed **only when**:

- [ ] Section A signed off **Approved for Batch 8**, **or** explicit written approval to proceed despite concerns
- [ ] Section B signed off (standard validation — independent of CIS role tests but recommended before merge)
- [ ] Section C regression green on current branch tip

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
