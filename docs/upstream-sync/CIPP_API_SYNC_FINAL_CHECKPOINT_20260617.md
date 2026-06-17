# CIPP-API Upstream Sync — Final Checkpoint

Generated: 2026-06-17  
Status: **Batch 8 complete — sync branch ready for PR/review into `master`**

---

## 1. Branch / Base / Tip

| Field | Value |
|-------|-------|
| **Sync branch** | `manage365/upstream-sync-cipp-api-20260617` |
| **Production base (`master`)** | `de78a343e1b8074afcbb417b344a6325704b94ee` — `refactor: enhance quarantine message retrieval and filtering` |
| **Branch tip** | `792d516edaedf11748f563ea1bac8af4e07a3721` — `docs: set API branch tip after Batch 8` |
| **Batch 8 code commit** | `5aba180616f806d8a99bd3948b2a1e7da9d7673e` — `test: adapt remaining role assignment checks for Manage365` |
| **Backup tag (pre-sync)** | `backup/pre-upstream-sync-cipp-api-20260617` (local, not pushed) |
| **Upstream remote** | `KelvinTegelaar/CIPP-API` (`upstream/master`) |
| **Working tree** | Clean |
| **Pushed to remote** | No — branch and tags remain local unless explicitly approved |

---

## 2. Batches Completed

Upstream work applied selectively via cherry-pick (`-x`) or manual adaptation. No blind merges.

| Batch | Scope | Outcome |
|-------|-------|---------|
| **1** | Levenshtein helper + tests; custom test alert statuses | 2 clean, 1 adapted partial |
| **2** | Intune policy OData fallback; table cleanup (deferred) | 1 clean; 2 deferred; 1 superseded |
| **3** | Standards fixes (compliance default, spam filter, Chrome extension) | 3 clean; 1 deferred (Intune template usage rename) |
| **4** | Standards/batch orchestrator safeguards | 2 clean (+ CIPPCore mirror); 1 deferred (Autopilot language) |
| **5** | Copilot test fix; test dedup infra | 2 clean; 3 deferred/superseded |
| **6** | Device registration standard fix | 1 clean |
| **7** | Adapted test fixes (GenericTest002 cap, CIS 1.3.4, CIS_1_1_1 role discovery) | 3 upstream intents in `29750b377`; Sections A/B/C validation completed |
| **8** | Remaining `961462f3` role-assignment tests | 4 files adapted in `5aba18061`; Pester 47/47 after each file |

---

## 3. Totals

| Category | Count | Notes |
|----------|-------|-------|
| **Applied cleanly** | **11** | Cherry-pick `-x` or direct apply with no fork adaptation |
| **Applied with adaptation** | **4** | `133f9295` (Levenshtein test path), `ddc264a7` (GenericTest002 cap), `503eac5b` (CIS 1.3.4 test-only), `961462f3` (CIS_1_1_1–1_1_4 + ZTNA21782 role discovery) |
| **Already implemented / superseded** | **5** | `4214bc7d`, `64836c02`, `2ab0e0e2`, `cbcc61b5`, `503eac5b` cache hunk (fork bulk fetch already present) |
| **Skipped / deferred** | **4** | Product decisions or permanent skip — see §9 |

**961462f3 status:** Fully adapted across all five test files:

- `Invoke-CippTestCIS_1_1_1.ps1` (Batch 7 — `Get-CippDbRole` + schedule instances)
- `Invoke-CippTestCIS_1_1_2.ps1` (Batch 8 — GA members + schedule instances)
- `Invoke-CippTestCIS_1_1_3.ps1` (Batch 8 — GA member HashSet count)
- `Invoke-CippTestCIS_1_1_4.ps1` (Batch 8 — CIS_1_1_1 privileged discovery pattern)
- `Invoke-CippTestZTNA21782.ps1` (Batch 8 — privileged-only principal map)

---

## 4. Tests Run and Results

| Test scope | Command | Result |
|------------|---------|--------|
| **Regression baseline** | `Invoke-Pester -Path Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1,Tests/Tools -Output Detailed` | **47/47 passed** after every batch and after each Batch 8 file |
| **Levenshtein only** | `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | 34 passed (Batch 1) |
| **Individual CIPPTests** | No dedicated Pester suite | Requires live tenant cache — see smoke tests below |

Batch 8 per-file regression:

| File | Pester after change |
|------|---------------------|
| `Invoke-CippTestCIS_1_1_2.ps1` | 47/47 |
| `Invoke-CippTestCIS_1_1_3.ps1` | 47/47 |
| `Invoke-CippTestCIS_1_1_4.ps1` | 47/47 |
| `Invoke-CippTestZTNA21782.ps1` | 47/47 |

---

## 5. Live Validation Completed

Checklist: `BATCH7_VALIDATION_CIPP_API_20260617.md`

| Section | Item | Status | Date |
|---------|------|--------|------|
| **A** | CIS_1_1_1 role assignment behavior (`Get-CippDbRole` + `RoleAssignmentScheduleInstances`) | **Approved** — pattern validated for Batch 8 extension | 2026-06-17 |
| **B** | `intuneRestrictUserDeviceRegistration` (`610cb089b`) — `azureADRegistration.allowedToRegister` | **Approved** | 2026-06-17 |
| **C** | Pester regression on branch tip | **Passed 47/47** | 2026-06-17 |

**Not yet live-validated:** CIS_1_1_2, CIS_1_1_3, CIS_1_1_4, ZTNA21782 post–Batch 8 (recommended smoke tests in §12).

---

## 6. Remaining Product Decisions

| Topic | Upstream commits | Recommendation |
|-------|------------------|----------------|
| **CippReportingDB cleanup policy** | `ee0b8229`, `fdf313e5` | Skip cherry-pick until Manage365 defines cache TTL; do not adopt upstream unfiltered 30-day delete |
| **Autopilot user-select / os-default language** | `785e71c5` | Needs product decision — fork sends literal `"$null"` string; upstream uses Graph locale semantics |
| **Intune template usage tracking** | `57b7de1f` (+ upstream usage block) | Skip permanently unless full usage feature + UI imported |

See `DEFERRED_REVIEW_CIPP_API_20260617.md` for full analysis (sections A–G).

**Already on master (no cherry-pick needed):** `64836c02`, `2ab0e0e2` (rerun detection fixes).

---

## 7. Known Concerns

| Concern | Detail |
|---------|--------|
| **ZTNA21782 behavior change** | Batch 8 filters **privileged roles only** (via role members + PIM schedule instances). Results may differ from pre-sync logic that matched all role assignments. Smoke test recommended before production. |
| **Stale CIPPCore ZTNA duplicate** | `CIPPCore/Public/Tests/ZTNA/Identity/Invoke-CippTestZTNA21782.ps1` still has old logic. **Not updated** — active test path is `Modules/CIPPTests/Public/Tests/ZTNA/Identity/Invoke-CippTestZTNA21782.ps1`. Consider mirror cleanup in a follow-up housekeeping PR. |
| **Start-TableCleanup / CippReportingDB** | Upstream cleanup commits (`ee0b8229`, `fdf313e5`) **not imported** — requires product decision on retention policy. |
| **Autopilot language fix** | `785e71c5` **not imported** — requires product decision on locale/language behavior for deployment profiles. |
| **Stale standards duplicate** | `CIPPCore/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1` may duplicate ActivityTriggers/CIPPCore mirror — review on merge. |

---

## 8. Protected Areas — No Regressions Observed

Custom fork areas were not overwritten during batches 1–8:

- Quarantine Portal 5.13.0 (`cacheQuarantineMessages` cleanup, query helpers)
- Manage365 branding / version tooling
- Email Troubleshooter
- Tenant workflows and navigation customizations

---

## 9. Merge Recommendation

**Ready for PR/review into `master`**, pending:

1. Final code review of sync branch diff (`de78a343e..792d516ed`)
2. Optional smoke tests for Batch 8 role-assignment tests (§12)
3. Acknowledgment of open product decisions (no blocker for merge of already-applied work)

| Criterion | Status |
|-----------|--------|
| Automated regression (Section C) | ✅ 47/47 |
| CIS_1_1_1 live validation (Section A) | ✅ Approved |
| Device registration standard (Section B) | ✅ Approved |
| Batch 8 role tests (`961462f3`) | ✅ Applied; live smoke optional |
| Product decisions (cleanup, Autopilot, template usage) | ⏸ Open — intentionally deferred |
| CIPP frontend sync | 🔄 Parked at `3c0ef6904` — separate PR track |

**Verdict:** Backend upstream sync intake is **complete for planned scope**. Open PR for review; do not merge to production without optional smoke tests and reviewer sign-off.

---

## 10. Suggested Smoke Tests Before Production

Run against non-production tenants with refreshed CIPPDB cache:

1. **CIS_1_1_1 through CIS_1_1_4** — Tenant with known permanent privileged roles and PIM schedule instances; confirm privileged user counts match Entra expectations.
2. **ZTNA21782** — Tenant with known privileged and non-privileged role holders; confirm only privileged users appear in results and phishing-resistant method detection is correct.
3. **`intuneRestrictUserDeviceRegistration`** — Intune-enabled tenant; confirm read/write of `azureADRegistration.allowedToRegister` and skip when `isAdminConfigurable` is false.
4. **Custom Test AlertStatuses** — If frontend (`manage365/upstream-sync-cipp-20260617`) and API branches tested together: create/edit custom script with multi-status alerts; confirm API stores and test runner honors `AlertStatuses`.

---

## 11. Next Recommended Upstream-Sync Work

| Option | Action |
|--------|--------|
| **A (recommended)** | Open PRs for completed sync branches — CIPP-API (`792d516ed`) and CIPP frontend (`3c0ef6904`) — for review; pause further cherry-picks until merged or rebased |
| **B** | Resume CIPP frontend mini-batch 3 (adapted `b1902421` tab margin, shape JSON commits) on `manage365/upstream-sync-cipp-20260617` |
| **C** | Housekeeping PR — remove or sync stale `CIPPCore` mirrors (ZTNA21782 test, standards duplicate) |
| **D** | Product decision sessions — CippReportingDB TTL, Autopilot language, Intune template usage |

**No further upstream cherry-picks** on the API sync branch until PR review completes or operator directs next intake batch.

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `UPSTREAM_SYNC_CIPP_API_20260617.md` | Full upstream inventory |
| `APPLIED_COMMITS_CIPP_API_20260617.md` | Per-commit tracking table |
| `DEFERRED_REVIEW_CIPP_API_20260617.md` | Deferred conflict analysis |
| `BATCH7_VALIDATION_CIPP_API_20260617.md` | Live validation checklist (Sections A–C) |
| `CIPP_API_SYNC_CHECKPOINT_20260617.md` | Pre–Batch 8 checkpoint (superseded by this document) |
| `CIPP_SYNC_CHECKPOINT_20260617.md` | CIPP frontend checkpoint (companion repo) |

---

## Checkpoint History

| Date | Event |
|------|-------|
| 2026-06-17 | Batches 1–7 complete; Sections A/B/C validation passed |
| 2026-06-17 | Batch 8 complete — all `961462f3` role-assignment tests adapted; Pester 47/47 |
| 2026-06-17 | **Final checkpoint** — sync branch ready for PR/review |
