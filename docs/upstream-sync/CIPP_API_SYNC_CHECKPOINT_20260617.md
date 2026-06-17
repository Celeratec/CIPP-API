# CIPP-API Upstream Sync Checkpoint

Generated: 2026-06-17  
Status: **Paused at validation gate — Batch 8 blocked**

---

## Branch and Base

| Field | Value |
|-------|-------|
| **Sync branch** | `manage365/upstream-sync-cipp-api-20260617` |
| **Branch tip** | `eee27ab30` — `docs: add batch 7 validation checklist for CIPP-API` |
| **Production base (`master`)** | `de78a343e` — `refactor: enhance quarantine message retrieval and filtering` |
| **Backup tag (pre-sync)** | `backup/pre-upstream-sync-cipp-api-20260617` |
| **Upstream remote** | `KelvinTegelaar/CIPP-API` (`upstream/master`) |
| **Commits on sync branch (since base)** | 25 (includes code cherry-picks, adapted applies, and sync documentation) |
| **Working tree** | Clean |

**Not pushed:** Sync branch and backup tag remain local unless explicitly approved.

---

## Batches Completed (1–7)

Upstream work was applied selectively via cherry-pick (`-x`) or manual adaptation. No blind merges.

| Batch | Scope | Outcome |
|-------|-------|---------|
| **1** | Levenshtein helper + tests; custom test alert statuses | 2 clean, 1 adapted partial |
| **2** | Intune policy OData fallback; table cleanup (deferred) | 1 clean; 2 deferred; 1 superseded |
| **3** | Standards fixes (compliance default, spam filter, Chrome extension) | 3 clean; 1 deferred (Intune template usage rename) |
| **4** | Standards/batch orchestrator safeguards | 2 clean (+ CIPPCore mirror); 1 deferred (Autopilot language) |
| **5** | Copilot test fix; test dedup infra | 2 clean; 3 deferred/superseded |
| **6** | Device registration standard fix; apps/services + role tests (deferred) | 1 clean; 2 deferred |
| **7** | Adapted test fixes only (no cherry-picks) | 3 upstream intents applied manually; partial role test |

Regression baseline throughout: **Pester 47/47** (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` + `Tests/Tools`).

---

## Commits Applied Cleanly

| Upstream | Applied SHA | Summary |
|----------|-------------|---------|
| `2b441244` | `365937de8` | Levenshtein distance function + tests |
| `6aa66c74` | `1784ccb99` | Custom test configurable alert statuses |
| `5ccf15a9` | `5d08be470` | Intune policy definition OData fallback |
| `9ba48711` | `a091f6f42` | Intune compliance check-in default 130→120 |
| `897dfaa4` | `69e5f37d9` | Spam filter rule Enabled verification (#5997) |
| `23c8994d` | `d1a696258` | Chrome extension toolbar state typo (#5990) |
| `ecbc9a50` | `6698dded1` | Missing standard function graceful skip |
| `78193020` | `b6ced9be6` | Orchestrator batch `$Item` shadowing fix |
| `95d48d1f` | `7bccfcdb5` | Copilot desktop activations cache field |
| `f5f7ae70` | `55e95d467` | Test dedup + CIPPTests-scoped discovery |
| `fd6e30f6` | `610cb089b` | `intuneRestrictUserDeviceRegistration` → `azureADRegistration.allowedToRegister` |

**Count:** 11 upstream commits applied cleanly.

**Follow-up mirrors (fork maintenance, not separate upstream SHAs):** `8c60b61f8` mirrored batch 4 safeguards to `CIPPCore`.

---

## Commits Applied With Adaptation

| Upstream | Applied SHA | Adaptation |
|----------|-------------|------------|
| `133f9295` | `05f48e4fb` | Levenshtein test path fallback only; skipped fuzzy-match test file absent in fork |
| `ddc264a7` | `29750b377` | GenericTest002 display cap 100→500 (4 lines); fork retains LicenseOverview logic |
| `503eac5b` | `29750b377` | **Test-only:** CIS 1.3.4 reads `AppsAndServices` cache first; cache hunk skipped (fork bulk fetch already present) |
| `961462f3` | `29750b377` | **Partial:** `CIS_1_1_1` only — `Get-CippDbRole` + `RoleAssignmentScheduleInstances` privileged user discovery |

**Count:** 4 upstream intents (3 full/partial adaptations in batch 7 commit `29750b377`).

---

## Commits Already Implemented or Superseded

| Upstream | Reason |
|----------|--------|
| `4214bc7d` | Merge commit; substantive change is `5ccf15a9` (already applied) |
| `64836c02` | Equivalent on `master` as `d9a8c33b5` (rerun scheduled-task detection) |
| `2ab0e0e2` | Equivalent on `master` as `76b390f1a` (rerun `Add-Member -Force` fix) |
| `cbcc61b5` | ORCA103 fix already from v10.5.2 intake (`2699da195`) |
| `503eac5b` (cache portion) | Fork `Set-CIPPDBCacheSettings.ps1` already caches `AppsAndServices` via bulk Graph |

**Count:** 5 upstream commits marked superseded/already present (cache portion of `503eac5b` tracked separately from test adaptation).

---

## Commits Deferred

| Upstream | Title / area | Recommendation | Blocker |
|----------|--------------|----------------|---------|
| `ee0b8229` | CippReportingDB cleanup 30 days | Skip cherry-pick; needs custom TTL design | Product decision |
| `fdf313e5` | CippReportingDB remove partition filter | Skip cherry-pick; unfiltered 30-day delete unsafe verbatim | Product decision |
| `57b7de1f` | Intune template `usedInTemplates` → `usage` | Skip; usage feature + UI absent | Product decision |
| `785e71c5` | Autopilot user-select / os-default | Needs product decision | Behavior change risk |
| `961462f3` (remainder) | Role assignment tests | Partial apply done; **4 files remain** | Batch 8 gate (CIS_1_1_1 validation) |

**Count:** 5 upstream commit records deferred (including partial `961462f3`).

---

## Product Decisions Still Required

| Topic | Upstream commits | Question |
|-------|------------------|----------|
| **CippReportingDB cleanup policy** | `ee0b8229`, `fdf313e5` | Should tenant cache rows auto-expire? If yes, define Manage365-specific retention — do not adopt upstream unfiltered 30-day rule. |
| **Autopilot user-select / os-default** | `785e71c5` | Adopt upstream Graph locale/language semantics? Fork currently sends literal `"$null"` string; may affect existing deployment profiles. |
| **Intune template usage tracking** | `57b7de1f` (+ upstream usage block) | Import full template ↔ standards usage feature and UI column, or skip permanently? |

See `DEFERRED_REVIEW_CIPP_API_20260617.md` for full analysis.

---

## Validation Status

Checklist: `BATCH7_VALIDATION_CIPP_API_20260617.md`

| Section | Item | Status |
|---------|------|--------|
| **A** | CIS_1_1_1 role assignment behavior | **Pending** — live tenant validation required |
| **B** | `intuneRestrictUserDeviceRegistration` (`610cb089b`) | **Pending** — live tenant validation required |
| **C** | Pester regression | **Passed 47/47** (last run 2026-06-17 on tip `eee27ab30`) |

**Gate:** Batch 8 and production merge both depend on completing live validation.

---

## Batch 8 Gate (Explicit)

**Do not adapt** the following until CIS_1_1_1 is live-tenant validated and approved (or explicitly waived):

- `Invoke-CippTestCIS_1_1_2.ps1`
- `Invoke-CippTestCIS_1_1_3.ps1`
- `Invoke-CippTestCIS_1_1_4.ps1`
- `Invoke-CippTestZTNA21782.ps1`

Upstream source: remainder of `961462f3`. Apply **one file at a time** after Section A sign-off.

**No new cherry-picks** should be applied while at this checkpoint.

---

## Merge Readiness

| Criterion | Status |
|-----------|--------|
| Automated regression (Section C) | ✅ Passed |
| CIS_1_1_1 live validation (Section A) | ❌ Pending |
| Device registration standard validation (Section B) | ❌ Pending |
| Batch 8 role tests | ❌ Blocked |
| Product decisions (cleanup, Autopilot, template usage) | ❌ Open |
| CIPP frontend upstream sync | ❌ Not started (separate branch/workstream) |

**Verdict:** **Not ready to merge to production** until Sections A and B are complete and documented.

---

## Protected Areas — No Regressions Observed

Custom fork areas were not overwritten during batches 1–7:

- Quarantine Portal 5.13.0 (`cacheQuarantineMessages` cleanup, query helpers)
- Manage365 branding / version tooling
- Email Troubleshooter
- Tenant workflows and navigation customizations

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `UPSTREAM_SYNC_CIPP_API_20260617.md` | Full 315-commit upstream inventory |
| `APPLIED_COMMITS_CIPP_API_20260617.md` | Per-commit tracking table |
| `DEFERRED_REVIEW_CIPP_API_20260617.md` | Deferred conflict analysis (sections A–G) |
| `BATCH7_VALIDATION_CIPP_API_20260617.md` | Live validation checklist |
| `CUSTOM_FEATURE_MAP_20260617.md` | Protected custom feature inventory |

---

## Recommended Next Action

1. **Deploy** `manage365/upstream-sync-cipp-api-20260617` to a **non-production** Function App.
2. **Run** `BATCH7_VALIDATION_CIPP_API_20260617.md`:
   - Section A: CIS_1_1_1 against tenant(s) with permanent and PIM privileged roles
   - Section B: `intuneRestrictUserDeviceRegistration` on Intune vs configurable tenants
   - Section C: Reconfirm Pester 47/47 post-deploy if desired
3. **Record** validation results and sign off Section A before any Batch 8 work.
4. **Do not merge to `master`** until Section B complete for production readiness.

---

## Checkpoint History

| Date | Event |
|------|-------|
| 2026-06-17 | Batches 1–7 complete; deferred review and validation checklist committed; sync paused at validation gate |
