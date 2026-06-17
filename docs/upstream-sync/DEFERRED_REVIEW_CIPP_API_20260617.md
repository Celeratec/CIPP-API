# Deferred Conflict Review — CIPP-API Upstream Sync

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Baseline: `master` @ `de78a343e`  
Regression baseline: **47/47 passed** (Levenshtein + `Tests/Tools`) after batches 1–6

This document completes the deferred-conflict review pass requested before any further cherry-picks. **No new upstream commits were applied** during this review.

---

## Executive Summary

Of the **9 deferred upstream commits**, review concludes:

| Outcome | Count | Commits |
|---------|-------|---------|
| **Already implemented** | 3 | `64836c02`, `2ab0e0e2`, `503eac5b` (cache portion) |
| **Apply with adaptation** | 3 | `ddc264a7`, `503eac5b` (CIS test only), `961462f3` |
| **Skip (cherry-pick not applicable)** | 2 | `ee0b8229`, `fdf313e5` |
| **Skip (feature absent / rename-only)** | 1 | `57b7de1f` |
| **Needs product decision** | 1 | `785e71c5` |

**Key findings**

1. **`CippReportingDB` cleanup (`ee0b8229` / `fdf313e5`)** — The fork **does** use `CippReportingDB` heavily as the tenant cache table, but **does not** have upstream’s timer cleanup block. Upstream’s final rule (`fdf313e5`) deletes **all** rows older than 30 days with **no partition filter**. That is a data-retention/product decision, not a missing-feature deferral. **Do not cherry-pick these commits verbatim.**

2. **Rerun fixes (`64836c02` / `2ab0e0e2`)** — Already present on `master` via `d9a8c33b5` and `76b390f1a` (same file, equivalent logic including `LastScheduledTime` and `Add-Member -Force`). Mark superseded.

3. **Apps and services (`503eac5b`)** — Fork cache is **ahead** of upstream (bulk Graph fetch + dedicated `AppsAndServices` type). Only the **CIS 1.3.4 test** adaptation is still useful.

4. **Role assignment tests (`961462f3`)** — Fork CIS 1.1.x tests still use legacy `RoleAssignments` cache; upstream’s PIM-aware `Get-CippDbRole` + `RoleAssignmentScheduleInstances` pattern is **not** equivalent and should be adapted file-by-file. Supporting helpers/cache already exist in the fork.

5. **Applied standard `fd6e30f6` / `610cb089b`** — Correctly applied in **`CIPPStandards`** (runtime module). Stale duplicate under `Modules/CIPPCore/Public/Standards/` still targets `azureADJoin`; mirror or remove in a follow-up (non-blocking for deploy path).

---

## Per-Commit Decision Table

| Upstream SHA | Title | Recommendation | Risk | Protected M365? | Upstream-only deps? |
|--------------|-------|----------------|------|-----------------|---------------------|
| `ee0b8229` | fix: change cleanup to 30 days | **Skip** (needs custom design, not cherry-pick) | **High** if applied blindly | Yes — `Start-TableCleanup.ps1` (+ custom quarantine rule) | No — block absent in fork |
| `fdf313e5` | fix: remove partitionkey | **Skip** (same; dangerous as-is) | **High** | Yes — same file | No |
| `57b7de1f` | Rename usedInTemplates → usage | **Skip** | Low | No | Yes — full usage-tracking block missing |
| `785e71c5` | fix user select | **Needs product decision** | **Medium** | No (Autopilot profile) | No |
| `ddc264a7` | Update GenericTest002 | **Apply with adaptation** | Low | No | No |
| `64836c02` | rerun detection on scheduled tasks | **Already implemented** | — | No | No |
| `2ab0e0e2` | fix: rerun issue | **Already implemented** | — | No | No |
| `503eac5b` | fix: apps and services test | **Already implemented** (cache) / **Apply with adaptation** (CIS test) | Low | No — cache structure | No |
| `961462f3` | fix: role assignment checks | **Apply with adaptation** (defer until dedicated batch) | Medium | No — CIS/ZTNA tests only | No — `Get-CippDbRole` exists |
| `fd6e30f6` | azureADRegistration standard fix | **Applied** (`610cb089b`) — validate in tenant | Medium | Yes — standards | No |

---

## A. CippReportingDB Cleanup Commits

**Commits:** `ee0b8229`, `fdf313e5`  
**File:** `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-TableCleanup.ps1`

### What upstream changed

| Commit | Change |
|--------|--------|
| `ee0b8229` | On existing `CippReportingDB` cleanup rule: `AddHours(-30)` → `AddDays(-30)` (fixes a typo — 30 hours was almost certainly meant to be 30 days). Filter still `PartitionKey eq 'Search'`. |
| `fdf313e5` | Removes `PartitionKey eq 'Search'` filter entirely. Final upstream rule: delete **all** `CippReportingDB` entities with `Timestamp` older than 30 days. |

Upstream current `master` places this rule **second** in the batch (after `webhookTable`), before `AuditLogSearches`.

### What our fork currently does

- **No** `CippReportingDB` entry in `Start-TableCleanup.ps1`.
- **Does** use `CippReportingDB` extensively as the **primary tenant-scoped read cache** (`Add-CIPPDbItem`, `New-CIPPDbRequest`, nightly `Set-CIPPDBCache*` functions). Partition keys are **tenant IDs**, not `'Search'`.
- **Does** clean `AuditLogSearches` with `PartitionKey eq 'Search'` at **12 hours** (line 22–27) — separate table from `CippReportingDB`.
- **Custom protected rule:** `cacheQuarantineMessages` 1-day retention (Manage365 quarantine portal).

No fork code writes `PartitionKey = 'Search'` into `CippReportingDB`. Search-partition entities live in `AuditLogSearches` / audit webhook flows.

### Conflict cause

Cherry-pick expects an existing `CippReportingDB` cleanup block to modify. Block never existed in the fork (diverged before upstream added it, or fork never adopted upstream reporting-DB timer cleanup).

### Risk assessment

| Action | Risk |
|--------|------|
| Cherry-pick `ee0b8229` alone | N/A — nothing to patch |
| Add upstream block with `Search` partition only | **Low effect** — likely no-op (no such rows in our table) |
| Add upstream block after `fdf313e5` (no partition filter, 30-day TTL) | **High** — deletes **all** tenant cache snapshots older than 30 days across every partition. Nightly refresh usually rewrites cache, but failed/inactive tenants or long-lived row keys could cause standards/tests to skip until manual cache refresh. |

### Protected Manage365 areas

Touches `Start-TableCleanup.ps1` — **protected** (custom quarantine cleanup must be preserved).

### Upstream-only dependencies

None — table and cache infrastructure exist in fork; only the **timer retention policy** is missing.

### Recommendation

**Skip both commits as cherry-picks.** This is **not** “defer until reporting DB feature chain arrives” — the cache table is already central to the fork. Instead:

1. **Product decision:** Should `CippReportingDB` rows ever expire automatically? If yes, define Manage365-specific retention (e.g., tenant-partition scoped, align with cache refresh cadence, exclude `-Count` rows, etc.).
2. **Do not** add upstream’s post-`fdf313e5` rule verbatim.
3. If retention is desired later, implement a **new adapted block** — do not replay `ee0b8229` → `fdf313e5` sequence.

---

## B. Intune Templates Property Rename

**Commit:** `57b7de1f`  
**File:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntuneTemplates.ps1`

### What upstream changed

Single-line rename inside a **~60-line standards usage-tracking block** (not in fork):

```powershell
# upstream (inside StandardsTemplateV2 lookup loop)
$Tpl | Add-Member -NotePropertyName 'usage' -NotePropertyValue @($Usage) -Force
# was: usedInTemplates
```

### What our fork currently does

Fork `Invoke-ListIntuneTemplates.ps1` (98 lines) lists templates from Azure Table `templates` partition — **no** `$Usage` computation, **no** `usedInTemplates` or `usage` property on returned objects.

### Frontend expectation (CIPP `main` @ sync baseline)

File: `src/pages/endpoint/MEM/list-templates/index.js`

```javascript
const simpleColumns = ["displayName", "isSynced", "package", "description", "Type"];
```

Repo-wide search: **no** references to `usedInTemplates` or template-level `.usage`. Unrelated `usageLocation` fields exist elsewhere.

**Conclusion:** Frontend expects **neither** `usedInTemplates` **nor** `usage`.

### Conflict cause

Rename sits inside upstream-only usage block; fork file ends before that block.

### Is upstream’s larger usage-tracking block required?

**Yes.** The rename alone is meaningless without:

- Standards template cross-reference (`StandardsTemplateV2` / package tags)
- Population of `$Usage` array per template GUID

### Recommendation

**Skip permanently** unless Manage365 intentionally imports the full Intune template ↔ standards usage feature (API + UI column). Renaming in isolation provides no value.

**Risk:** Low  
**Protected areas:** No  
**Defer until feature chain:** Only if product wants usage column in MEM templates UI — treat as a **feature import**, not a bugfix cherry-pick.

---

## C. Autopilot User-Select Behavior

**Commit:** `785e71c5`  
**File:** `Modules/CIPPCore/Public/Set-CIPPDefaultAPDeploymentProfile.ps1`

### Fork behavior (current)

```powershell
if ($Language -in @('user-select', 'os-default')) { $Language = "$null" }
# ...
'locale' = "$($Language)"   # JSON serializes as string "$null" for both modes
```

Both `user-select` and `os-default` become the **literal string** `"$null"` in the Graph body (PowerShell double-quoted expansion of `$null`).

### Upstream behavior

```powershell
if ($Language -eq 'os-default') { $Language = $null }
# locale = "$($Language)"  → omitted/null for os-default
if ($Language -eq 'user-select') {
    $ObjBody.locale = ''
    $ObjBody | Add-Member -Name 'language' -Value '' -Force
}
```

- **`os-default`** → `$null` locale (OS default during OOBE)
- **`user-select`** → empty `locale` + empty `language` (user chooses during OOBE; Graph treats empty string differently from null)

### Safety analysis

| Mode | Fork (likely Graph effect) | Upstream (intended) | Safer |
|------|---------------------------|---------------------|-------|
| `os-default` | String `"$null"` in locale | Null / omitted locale | **Upstream** |
| `user-select` | Same string `"$null"` | Empty locale + language | **Upstream** |

Fork behavior is almost certainly **incorrect** for both modes — `"$null"` is not a valid locale tag and may confuse Autopilot OOBE language selection.

**Behavior change risk:** Tenants with profiles already created under fork logic may have `"$null"` stored as locale. PATCH after fix could change OOBE language behavior on **profile update** (not retroactive on enrolled devices until profile reapplied).

### Recommendation

**Needs product decision** before apply.

- **Technical direction:** Upstream fix aligns with Graph API semantics; fork `"$null"` string is a bug.
- **Operational concern:** Audit existing Autopilot deployment profiles for `"$null"` locale before mass remediate; communicate to clients using `user-select` / `os-default`.
- **Do not apply** until stakeholders accept potential profile locale migration.

**Risk:** Medium  
**Protected areas:** No (shared Autopilot helper, not quarantine/custom branding)

---

## D. Generic Test Conflict

**Commit:** `ddc264a7`  
**File:** `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest002.ps1`

### What upstream changed

Display cap only: **100 → 500** licensed users in markdown output (4 lines).

### What our fork currently does

Fork implementation **diverged** (LicenseOverview cache, `UserLicenseMap` hashtable, string `$Result` vs upstream `StringBuilder`) but **still uses cap 100** at lines 57–61.

Cherry-pick conflict is structural (different surrounding code), not logical opposition.

### Recommendation

**Apply with adaptation** — manual 4-line change; no need for full cherry-pick.

**Minimal patch:**

```powershell
# line ~57
if ($DisplayCount -ge 500) { break }
# line ~60-61
if ($UserLicenseMap.Count -gt 500) {
    $Result += "`n*Showing 500 of $($UserLicenseMap.Count) licensed users.*`n"
```

**Risk:** Low (informational test output only)  
**Protected areas:** No

---

## E. Rerun Logic (Combined Review)

**Commits:** `64836c02`, `2ab0e0e2`  
**File:** `Modules/CIPPCore/Public/Test-CIPPRerun.ps1`

### What upstream changed

| Commit | Change |
|--------|--------|
| `64836c02` | Track `LastScheduledTime`; when `$BaseTime` differs from cached value, treat as new execution (fixes scheduled-task rerun false positives). |
| `2ab0e0e2` | Use `Add-Member -Force` instead of direct property assignment on table entities (Azure Table entity objects). |

### What our fork currently does

`Test-CIPPRerun.ps1` on sync branch **already contains both behaviors** (lines 66–79, `Add-Member -Force` pattern throughout).

Present on `master` before sync branch:

- `d9a8c33b5` — fix: rerun detection on scheduled tasks
- `76b390f1a` — fix: rerun issue

`git diff 64836c02 HEAD -- Test-CIPPRerun.ps1` shows only the `Add-Member` delta (already applied). `git diff 2ab0e0e2 HEAD` is empty.

### Conflict cause at cherry-pick time

Fork already had v10.5.2-intake equivalents; upstream SHAs patch an older baseline → conflict, not missing logic.

### Recommendation

**Already implemented** — mark superseded in tracking; **skip** cherry-picks.

**Risk if re-applied:** Low conflict noise; no functional gain  
**v10.5.2 intake:** Compatible — fixes were absorbed pre-sync

---

## F. Apps and Services Cache / Test

**Commit:** `503eac5b`  
**Files:** `Set-CIPPDBCacheSettings.ps1`, `Invoke-CippTestCIS_1_3_4.ps1`

### What upstream changed

1. **Cache:** Separate `New-GraphGetRequest` to `/admin/appsAndServices` → `Add-CIPPDbItem -Type 'AppsAndServices'`.
2. **Test:** Read `AppsAndServices` type first; fall back to nested object in `Settings` cache; stricter property presence check.

### What our fork currently does

**Cache (`Set-CIPPDBCacheSettings.ps1`):** Already caches `AppsAndServices` via **bulk Graph request** (lines 28–66), plus `FormsSettings` — **more complete** than upstream commit.

**Test (`Invoke-CippTestCIS_1_3_4.ps1`):** Still reads **only** `Settings` cache and extracts `appsAndServices` child — upstream test improvement **not** yet applied.

### Does CIS 1.3.4 need the dedicated cache type?

**Not strictly** — fork bulk cache also writes `Settings` with full directory settings. Test can pass today **if** `appsAndServices` appears in Settings payload.

**Adapted test still valuable:** Prefer dedicated `AppsAndServices` type (already populated) with Settings fallback — matches upstream intent and avoids false skips if Settings shape changes.

### Conflict cause

Fork restructured cache function (bulk + Forms); upstream added sequential block → textual conflict. Feature not missing.

### Recommendation

| Part | Action |
|------|--------|
| Cache portion of `503eac5b` | **Already implemented differently** — skip |
| CIS test portion | **Apply with adaptation** (manual merge of test file only) |

**Minimal patch for `Invoke-CippTestCIS_1_3_4.ps1`:** Replace Settings-only lookup with upstream’s AppsAndServices-first + fallback + property guard (see `503eac5b` diff).

**Risk:** Low  
**Protected areas:** No (standard cache file, not quarantine)

---

## G. Role Assignment Checks

**Commit:** `961462f3`  
**Files:** `Invoke-CippTestCIS_1_1_1.ps1`, `_1_1_2`, `_1_1_3`, `_1_1_4`, `Invoke-CippTestZTNA21782.ps1`

### What upstream changed

Replaces legacy `RoleAssignments` cache joins with:

- `Get-CippDbRole -IncludePrivilegedRoles` (role members from DB role objects)
- `RoleAssignmentScheduleInstances` cache (PIM permanent assignments, `assignmentType -eq 'Assigned'`, no `endDateTime`)
- HashSet-based privileged user ID aggregation

### What our fork currently does

| File | Fork pattern |
|------|--------------|
| CIS 1.1.1–1.1.4 | `Get-CIPPTestData -Type 'Roles'` + `RoleAssignments` + `-in` filters |
| ZTNA21782 | `RoleAssignments` join with `UserRegistrationDetails` |
| Other ZTNA tests (21815, 21816, etc.) | **Already** use `Get-CippDbRole` + `RoleAssignmentScheduleInstances` |

Fork **has** `Get-CippDbRole`, `Get-CippDbRoleMembers`, `Set-CIPPDBCacheRoleAssignmentScheduleInstances` — infrastructure exists; CIS 1.1.x not migrated.

### Equivalent logic?

**No.** Legacy `RoleAssignments` can miss PIM schedule nuances and uses different role ID fields (`roleDefinitionId` vs `roleTemplateId`). Upstream fix addresses false negatives/positives for privileged user detection.

### Conflict cause

Partial migration — fork ZTNA tests updated in v10.5.2 intake; CIS 1.1.x left on old pattern; upstream patch overlaps both → 4/5 file conflicts.

### Recommendation

**Apply with adaptation** in a dedicated batch — **file-by-file manual merge**, do not blind cherry-pick.

Suggested order: `CIS_1_1_1` → `_1_1_2` → `_1_1_3` → `_1_1_4` → `ZTNA21782` (mirror patterns from existing `Invoke-CippTestZTNA21816.ps1`).

**Risk:** Medium (test assertions only; may change pass/fail for tenants using PIM)  
**Protected areas:** No  
**Dependencies:** Ensure `RoleAssignmentScheduleInstances` cache refresh runs (`Set-CIPPDBCacheRoleAssignmentScheduleInstances`).

---

## Applied Standard Validation: `fd6e30f6` / `610cb089b`

**File (runtime):** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1`  
**Applied SHA:** `610cb089b` (batch 6, clean cherry-pick)

### What changed

| Before | After |
|--------|-------|
| Read/write `azureADJoin.allowedToJoin` | Read/write `azureADRegistration.allowedToRegister` |
| Always remediate | Skip remediate when `azureADRegistration.isAdminConfigurable -eq $false` (common when Intune enabled) |

### Is the `azureADRegistration` change safe?

**Yes, technically correct.** Standard name and helptext describe **device registration**, not Entra join. Prior behavior targeted the wrong Graph sub-object and could report/remediate the wrong policy surface.

**Caveats:**

1. **Intune-enabled tenants:** Remediation skipped with Warning — alert/report still evaluate `azureADRegistration` state. Operators may see alerts they cannot auto-remediate (expected).
2. **Stale duplicate:** `Modules/CIPPCore/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1` still uses `azureADJoin` — **not invoked** by `Push-CIPPStandard` (loads `CIPPStandards` module). Schedule mirror cleanup to avoid future confusion.

### Rollback concern

Revert `610cb089b` restores incorrect `azureADJoin` targeting. If remediation ran on a tenant **before** apply, re-running old code would again write join policy instead of registration policy — document tenant state if rollback needed.

### Live-tenant smoke test steps

1. **Pre-check:** `GET beta/policies/deviceRegistrationPolicy` — note `azureADRegistration.allowedToRegister.@odata.type` and `isAdminConfigurable`.
2. **Tenant without Intune** (or `isAdminConfigurable = true`):
   - Enable standard with remediate ON, `disableUserDeviceRegistration = true`.
   - Confirm PUT sets `azureADRegistration.allowedToRegister` to `#microsoft.graph.noDeviceRegistrationMembership`.
   - Confirm `azureADJoin.allowedToJoin` unchanged unless separately configured.
3. **Intune-enabled tenant** (`isAdminConfigurable = false`):
   - Run remediate — expect **Warning** skip, no PUT.
   - Alert/report modes still produce meaningful compare output.
4. **Disable path:** Set `disableUserDeviceRegistration = false` — verify `#microsoft.graph.allDeviceRegistrationMembership` when remediate allowed.
5. **Log review:** Search `Standards` API logs for updated message strings (“users allowed to register”).

---

## Recommended Next Adapted-Apply Batch (max 3 commits)

| Priority | Item | Action | Rationale |
|----------|------|--------|-----------|
| 1 | `ddc264a7` | Manual 4-line cap 100→500 | Trivial, zero conflict risk, tests-only |
| 2 | `503eac5b` (test only) | Manual merge `Invoke-CippTestCIS_1_3_4.ps1` | Cache already done; improves test resilience |
| 3 | `961462f3` | Adapted file-by-file (start `CIS_1_1_1`) | Real correctness fix; use existing `Get-CippDbRole` infra |

**Do not include** in next batch: cleanup commits, template rename, Autopilot language (pending decision), rerun commits (done).

---

## Recommended Skips

| SHA | Reason |
|-----|--------|
| `ee0b8229` | No block to patch; wrong to add without retention design |
| `fdf313e5` | Blanket 30-day delete on entire cache table — unsafe verbatim |
| `57b7de1f` | Rename-only; usage feature + UI absent |
| `64836c02` | Superseded by `d9a8c33b5` on master |
| `2ab0e0e2` | Superseded by `76b390f1a` on master |
| `503eac5b` (cache hunk) | Fork bulk implementation already superior |

---

## Product Decisions Needed

1. **`CippReportingDB` retention** — Should cache rows auto-expire? If yes, define partition/type scope and TTL (not upstream’s unfiltered 30-day rule).
2. **Autopilot `user-select` / `os-default` (`785e71c5`)** — Accept upstream Graph semantics and plan audit of existing profiles with `"$null"` locale?
3. **Intune template usage tracking** — Import full upstream usage block + UI column, or permanently skip `57b7de1f` chain?

---

## Smoke Test Checklist — Applied Standards Changes

### `intuneRestrictUserDeviceRegistration` (`610cb089b`)

- [ ] Graph GET deviceRegistrationPolicy on test tenant — capture before state
- [ ] Remediate ON, non-Intune tenant — verify `azureADRegistration.allowedToRegister` changes
- [ ] Remediate ON, Intune tenant — verify skip + Warning (no PUT)
- [ ] Alert mode — alert fires when registration policy mismatches desired state
- [ ] Report/BPA — `intuneRestrictUserDeviceRegistration` field reflects new read path
- [ ] Confirm `azureADJoin.allowedToJoin` not modified by standard run
- [ ] Rollback plan documented if revert required

### Post–batch 7 (when adapted applies land)

- [ ] Run GenericTest002 on tenant with >100 licensed users — confirm 500 cap
- [ ] CIS 1.3.4 — pass/skip with AppsAndServices cache only (Settings fallback)
- [ ] CIS 1.1.1 — compare results before/after on tenant with PIM GA assignments
- [ ] Full regression: `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` + `Tests/Tools` (47 tests)

---

## Document History

| Date | Action |
|------|--------|
| 2026-06-17 | Initial deferred review complete; cherry-picks remain paused pending approval of batch 7 plan |
