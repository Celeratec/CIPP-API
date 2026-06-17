# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 11 |
| Applied with adaptation | 3 |
| Applied with adaptation (partial) | 1 |
| Skipped | 0 |
| Deferred (pending decision/adaptation) | 3 |
| Already implemented | 5 |
| Review complete | See `DEFERRED_REVIEW_CIPP_API_20260617.md` |

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` | `365937de821318968bda27b9b44180160afef4b1` | Applied cleanly | Low-risk test/helper addition; no custom overlap | `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`) | Cherry-pick `-x` succeeded with no conflicts |
| `133f929555f5d26a17757802d22ceaa8b3f6b926` | `05f48e4fb` | Applied with adaptation | Partial apply only — Levenshtein test path fallback; skipped fuzzy-match test file | `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (Levenshtein), 13 passed (`Tests/Tools`) | Full cherry-pick conflicted on modify/delete of `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1` (not in fork). Skipped fuzzy-match test path change and did not add upstream fuzzy-match helper. Added `Public/Tools/` → `Private/` path fallback per upstream intent. |
| `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` | `1784ccb993fdb316e37bf768168941deeea587f2` | Applied cleanly | Custom test alert-on-status feature; no protected-area overlap | `Invoke-AddCustomScript.ps1`, `Invoke-CippTestCustomScripts.ps1` | Pester: 47 passed (Levenshtein + `Tests/Tools` regression) | Adds configurable `AlertStatuses` for custom script test failures. No dedicated Pester suite for custom scripts. |
| `ee0b82294a849bf992ec3ff7ce09b517f4e17fba` | — | Deferred | **Conflict:** upstream modifies `CippReportingDB` cleanup rule; block absent in fork | `Start-TableCleanup.ps1` | Not run | Deferred review: **Skip cherry-pick** — needs product decision on cache TTL, not missing feature. See `DEFERRED_REVIEW_CIPP_API_20260617.md` §A. |
| `fdf313e5cfb08b2da7bba256201daf2de9ba15ff` | — | Deferred | **Conflict:** removes `PartitionKey eq 'Search'` on `CippReportingDB` cleanup; block absent | `Start-TableCleanup.ps1` | Not run | Deferred review: **Skip cherry-pick** — unfiltered 30-day delete unsafe verbatim. See §A. |
| `5ccf15a9197c67cb8fdde40606dd7b26a476ae1a` | `5d08be470412057bc8cba5fee192e374eacbe8fb` | Applied cleanly | Intune policy definition fallback when bulk Graph returns non-200; no protected-area overlap | `Invoke-ListIntunePolicy.ps1` | Pester: 47/47 passed (Levenshtein + `Tests/Tools` regression) | Adds template-based fallback for missing `settingDefinitions` on configuration policies. No Intune-specific Pester suite. |
| `9ba48711c614be8e2452ffff2e539b5b1a11b534` | `a091f6f42` | Applied cleanly | Fixes Intune compliance check-in default (130→120) to match max validator | `Config/standards.json`, `Invoke-CIPPStandardIntuneComplianceSettings.ps1` | Batch regression: 47/47 passed | Default was invalid (130 > max 120). Standards config change only. |
| `897dfaa4f07443e0f05f8f2aefa5b0a92fc91a9c` | `69e5f37d9` | Applied cleanly | Standards bugfix #5997 — verify spam filter rule is Enabled; re-enable if Disabled | `Invoke-CIPPStandardSpamFilterPolicy.ps1` | Batch regression: 47/47 passed | Uses `New-ExoRequest` in standards deploy path (not quarantine/message trace HTTP endpoints). |
| `23c8994da9a523a6fbce594181f0c74e5fb1a69e` | `d1a696258` | Applied cleanly | Typo fix #5990 — Edge toolbar unpinned state `hidden` → `default_hidden` | `Invoke-CIPPStandardDeployCheckChromeExtension.ps1` | Batch regression: 47/47 passed | Single-line standards constant fix. |
| `4214bc7de39c563d0979b2717239e9acda4752e7` | — | Already implemented | Merge commit (#2054) whose substantive change is upstream `5ccf15a9`, already applied as `5d08be470` | `Invoke-ListIntunePolicy.ps1` (same 34-line fix) | Not run | Did not cherry-pick merge commit. Superseded by prior batch 2 apply of `5ccf15a9`. |
| `57b7de1f31bcffa3ebc3ba1f05d5d47fa1b6bffe` | — | Deferred | **Conflict:** rename inside usage-tracking block absent in fork | `Invoke-ListIntuneTemplates.ps1` | Not run | Deferred review: **Skip** — frontend uses neither property. See §B. |
| `ecbc9a50ac0584e0d0ce59259214ebe6d9cf525a` | `6698dded1` | Applied cleanly | Graceful skip + Warning log when standard function missing from CIPPStandards module | `CIPPActivityTriggers/.../Push-CIPPStandard.ps1`, `CIPPCore/.../Push-CIPPStandard.ps1` (mirror) | Batch regression: 47/47 passed | Upstream cherry-pick to ActivityTriggers; **Adapted mirror fix to CIPPCore** in follow-up commit. Changes failure mode from invoke error to early return with Warning. |
| `781930205c67fc17a5ca887755361987a407012a` | `b6ced9be6` | Applied cleanly | Fixes `$Item` variable shadowing in orchestrator batch retrieval loop | `CIPPActivityTriggers/.../Push-OrchestratorBatchItems.ps1`, `CIPPCore/.../Push-OrchestratorBatchItems.ps1` (mirror) | Batch regression: 47/47 passed | Upstream cherry-pick to ActivityTriggers; **Adapted mirror fix to CIPPCore** in follow-up commit. Renames inner loop variable to `$BatchItem`. |
| `785e71c530a39b46f56cea7c598f7d609d8a8518` | — | Deferred | **Conflict:** fork `"$null"` string locale vs upstream Graph locale/language fix | `Set-CIPPDefaultAPDeploymentProfile.ps1` | Not run | Deferred review: **Needs product decision**. See `DEFERRED_REVIEW_CIPP_API_20260617.md` §C. |
| `95d48d1fe90a2e57c7459afa1330290ef659ff02` | `7bccfcdb5` | Applied cleanly | Copilot Readiness test uses correct desktop activations cache field | `Invoke-CippTestCopilotReady003.ps1` | Batch regression: 47/47 passed | Tests-only; 1 file. |
| `f5f7ae7064404c314d6cd5694ee1260d1e543c0f` | `55e95d467` | Applied cleanly | Dedup batch table writes by PartitionKey+RowKey; scope test discovery to CIPPTests module | `Add-CIPPAzDataTableEntity.ps1`, `Invoke-CIPPTestCollection.ps1` | Batch regression: 47/47 passed | Prevents duplicate test result rows. Table dedup affects all small-entity batch writes — monitor for side effects. |
| `ddc264a771b27807a35d12fd3645d4693b4a21f8` | `0c3fdeb6c` | Applied with adaptation | Manual 100→500 licensed-user display cap in fork GenericTest002 implementation | `Invoke-CippTestGenericTest002.ps1` | Batch 7 regression: 47/47 passed | Batch 7 adapted apply — no cherry-pick. Upstream commit is cap-only; fork retains LicenseOverview cache logic. |
| `64836c02a801a3718c2bd2e598bcf206c973541d` | — | Already implemented | Equivalent logic on `master` as `d9a8c33b5` (`LastScheduledTime` scheduled-task rerun detection) | `Test-CIPPRerun.ps1` | Not run | Deferred review 2026-06-17: skip cherry-pick. See `DEFERRED_REVIEW_CIPP_API_20260617.md` §E. |
| `2ab0e0e27c77d146301b427365e0d305e813137d` | — | Already implemented | Equivalent logic on `master` as `76b390f1a` (`Add-Member -Force` on rerun cache entities) | `Test-CIPPRerun.ps1` | Not run | Deferred review 2026-06-17: skip cherry-pick. See `DEFERRED_REVIEW_CIPP_API_20260617.md` §E. |
| `cbcc61b5afd8c7ea9bb9bef1da7878465afc5610` | — | Already implemented | ORCA103 test fix already present from v10.5.2 intake (`2699da195 Fixes ORCA103`) | `Invoke-CippTestORCA103.ps1` | Not run | Cherry-pick produced empty patch; skipped. |
| `503eac5bdb6322f1e42b8e90cc48ab9f3b4c4c5b` | `0c3fdeb6c` | Applied with adaptation (test-only) | CIS 1.3.4 reads `AppsAndServices` cache first with Settings fallback; cache hunk skipped — fork bulk fetch already implements `AppsAndServices` type | `Invoke-CippTestCIS_1_3_4.ps1` | Batch 7 regression: 47/47 passed | Did not modify `Set-CIPPDBCacheSettings.ps1`. See deferred review §F. |
| `961462f346d5b8fe357dc322e550dee95a644232` | `0c3fdeb6c` | Partially applied with adaptation | CIS_1_1_1 only — `Get-CippDbRole` + `RoleAssignmentScheduleInstances` privileged user discovery | `Invoke-CippTestCIS_1_1_1.ps1` | Batch 7 regression: 47/47 passed | **Remaining deferred:** `CIS_1_1_2`, `CIS_1_1_3`, `CIS_1_1_4`, `ZTNA21782`. Compliance assertion logic unchanged. |
| `fd6e30f62fb209f2b706b359bd1b91f5ef368081` | `610cb089b` | Applied cleanly | Narrow standards bugfix — read/write `azureADRegistration.allowedToRegister` instead of `azureADJoin.allowedToJoin`; skip remediate when `isAdminConfigurable` is false | `Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1` | Batch regression: 47/47 passed | Device registration standard only. Log message wording updated. Validate intuneRestrictUserDeviceRegistration deploy in test tenant. |

## Proposed Next 10 Low-Risk Candidates

| Priority | SHA | Title | Files | Risk | Why safe | Dependencies |
|----------|-----|-------|-------|------|----------|--------------|
| 1 | `95d48d1f` | Fix desktop activations copilot ready test | 1 test | Low | Tests-only | None — **applied** |
| 2 | `ddc264a7` | Update Invoke-CippTestGenericTest002.ps1 | 1 test | Low | Tests-only | **Deferred — conflict** |
| 3 | `f5f7ae70` | fixes duplicate test calls | 2 (test infra) | Low | Test dedup + module-scoped discovery | None — **applied** |
| 4 | `64836c02` | fix: rerun detection on scheduled tasks | 1 | Low | Scheduled-task rerun fix | Pair with `2ab0e0e2`; **deferred — conflict** |
| 5 | `2ab0e0e2` | fix: rerun issue | 1 | Low | Refines Test-CIPPRerun | After `64836c02` review |
| 6 | `0640f07c` | Fixes ORCA179 | 1 test | Low | ORCA test-only | May overlap v10.5.2 ORCA intake — verify first |
| 7 | `503eac5b` | fix: apps and services test | 2 | Low | CIS test + cache settings | Cache touch — review diff |
| 8 | `fd6e30f6` | fix(standards): azureADRegistration target | 1 standard | Low-Med | Isolated standards bugfix | Standards deploy behavior change |
| 9 | `961462f3` | fix: role assignment checks | 5 tests | Low | Test assertion fixes | 5 files but tests-only |
| 10 | `55ddb18b` | Update Invoke-ExecTestRun.ps1 | 1 | Low-Med | Test runner endpoint | 55-line diff — inspect before apply |

## Next Steps

1. **Batch 7 complete** — adapted test fixes for `ddc264a7`, `503eac5b` (test-only), partial `961462f3` (`CIS_1_1_1`).
2. **Product decisions:** `CippReportingDB` retention (`ee0b8229`/`fdf313e5`), Autopilot language (`785e71c5`), Intune template usage feature (`57b7de1f` chain).
3. **Batch 8 candidates:** `961462f3` remaining files (`CIS_1_1_2` → `ZTNA21782`) one file at a time after CIS_1_1_1 validated in tenant.
4. **Skip permanently:** rerun commits (`64836c02`, `2ab0e0e2`), template rename (`57b7de1f`), AppsAndServices cache hunk (`503eac5b`).
5. **Smoke test:** `intuneRestrictUserDeviceRegistration` (`610cb089b`) — checklist in deferred review doc.
6. **Follow-up:** Mirror or remove stale `CIPPCore/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1` duplicate.
7. CIPP frontend batch remains deferred.
