# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 10 |
| Applied with adaptation | 1 |
| Skipped | 0 |
| Deferred | 6 |
| Already implemented | 2 |

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` | `365937de821318968bda27b9b44180160afef4b1` | Applied cleanly | Low-risk test/helper addition; no custom overlap | `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`) | Cherry-pick `-x` succeeded with no conflicts |
| `133f929555f5d26a17757802d22ceaa8b3f6b926` | `05f48e4fb` | Applied with adaptation | Partial apply only — Levenshtein test path fallback; skipped fuzzy-match test file | `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (Levenshtein), 13 passed (`Tests/Tools`) | Full cherry-pick conflicted on modify/delete of `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1` (not in fork). Skipped fuzzy-match test path change and did not add upstream fuzzy-match helper. Added `Public/Tools/` → `Private/` path fallback per upstream intent. |
| `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` | `1784ccb993fdb316e37bf768168941deeea587f2` | Applied cleanly | Custom test alert-on-status feature; no protected-area overlap | `Invoke-AddCustomScript.ps1`, `Invoke-CippTestCustomScripts.ps1` | Pester: 47 passed (Levenshtein + `Tests/Tools` regression) | Adds configurable `AlertStatuses` for custom script test failures. No dedicated Pester suite for custom scripts. |
| `ee0b82294a849bf992ec3ff7ce09b517f4e17fba` | — | Deferred | **Conflict:** upstream modifies `CippReportingDB` cleanup rule (`AddHours(-30)` → `AddDays(-30)`); that table cleanup block does not exist in the Manage365 fork | `Start-TableCleanup.ps1` | Not run | Cherry-pick aborted. Fork uses `AuditLogSearches` at `-12 hours` instead; no `CippReportingDB` entry. |
| `fdf313e5cfb08b2da7bba256201daf2de9ba15ff` | — | Deferred | **Conflict:** same file/block — removes `PartitionKey eq 'Search'` filter on `CippReportingDB` cleanup; block absent in fork | `Start-TableCleanup.ps1` | Not run | Cherry-pick aborted. Depends on `ee0b8229` context or manual addition of `CippReportingDB` cleanup rule. |
| `5ccf15a9197c67cb8fdde40606dd7b26a476ae1a` | `5d08be470412057bc8cba5fee192e374eacbe8fb` | Applied cleanly | Intune policy definition fallback when bulk Graph returns non-200; no protected-area overlap | `Invoke-ListIntunePolicy.ps1` | Pester: 47/47 passed (Levenshtein + `Tests/Tools` regression) | Adds template-based fallback for missing `settingDefinitions` on configuration policies. No Intune-specific Pester suite. |
| `9ba48711c614be8e2452ffff2e539b5b1a11b534` | `a091f6f42` | Applied cleanly | Fixes Intune compliance check-in default (130→120) to match max validator | `Config/standards.json`, `Invoke-CIPPStandardIntuneComplianceSettings.ps1` | Batch regression: 47/47 passed | Default was invalid (130 > max 120). Standards config change only. |
| `897dfaa4f07443e0f05f8f2aefa5b0a92fc91a9c` | `69e5f37d9` | Applied cleanly | Standards bugfix #5997 — verify spam filter rule is Enabled; re-enable if Disabled | `Invoke-CIPPStandardSpamFilterPolicy.ps1` | Batch regression: 47/47 passed | Uses `New-ExoRequest` in standards deploy path (not quarantine/message trace HTTP endpoints). |
| `23c8994da9a523a6fbce594181f0c74e5fb1a69e` | `d1a696258` | Applied cleanly | Typo fix #5990 — Edge toolbar unpinned state `hidden` → `default_hidden` | `Invoke-CIPPStandardDeployCheckChromeExtension.ps1` | Batch regression: 47/47 passed | Single-line standards constant fix. |
| `4214bc7de39c563d0979b2717239e9acda4752e7` | — | Already implemented | Merge commit (#2054) whose substantive change is upstream `5ccf15a9`, already applied as `5d08be470` | `Invoke-ListIntunePolicy.ps1` (same 34-line fix) | Not run | Did not cherry-pick merge commit. Superseded by prior batch 2 apply of `5ccf15a9`. |
| `57b7de1f31bcffa3ebc3ba1f05d5d47fa1b6bffe` | — | Deferred | **Conflict:** upstream rename `usedInTemplates` → `usage` sits inside larger usage-tracking block absent/diverged in fork | `Invoke-ListIntuneTemplates.ps1` | Not run | Cherry-pick aborted. Fork file structure differs from upstream; simple rename cannot apply in isolation without reviewing full template usage feature. |
| `ecbc9a50ac0584e0d0ce59259214ebe6d9cf525a` | `6698dded1` | Applied cleanly | Graceful skip + Warning log when standard function missing from CIPPStandards module | `CIPPActivityTriggers/.../Push-CIPPStandard.ps1`, `CIPPCore/.../Push-CIPPStandard.ps1` (mirror) | Batch regression: 47/47 passed | Upstream cherry-pick to ActivityTriggers; **Adapted mirror fix to CIPPCore** in follow-up commit. Changes failure mode from invoke error to early return with Warning. |
| `781930205c67fc17a5ca887755361987a407012a` | `b6ced9be6` | Applied cleanly | Fixes `$Item` variable shadowing in orchestrator batch retrieval loop | `CIPPActivityTriggers/.../Push-OrchestratorBatchItems.ps1`, `CIPPCore/.../Push-OrchestratorBatchItems.ps1` (mirror) | Batch regression: 47/47 passed | Upstream cherry-pick to ActivityTriggers; **Adapted mirror fix to CIPPCore** in follow-up commit. Renames inner loop variable to `$BatchItem`. |
| `785e71c530a39b46f56cea7c598f7d609d8a8518` | — | Deferred | **Conflict:** fork has custom language handling `if ($Language -in @('user-select', 'os-default')) { $Language = "$null" }` vs upstream Graph API locale/language body fix | `Set-CIPPDefaultAPDeploymentProfile.ps1` | Not run | Cherry-pick aborted. Requires product review — fork may intentionally differ for Autopilot OOBE language selection. |
| `95d48d1fe90a2e57c7459afa1330290ef659ff02` | `7bccfcdb5` | Applied cleanly | Copilot Readiness test uses correct desktop activations cache field | `Invoke-CippTestCopilotReady003.ps1` | Batch regression: 47/47 passed | Tests-only; 1 file. |
| `f5f7ae7064404c314d6cd5694ee1260d1e543c0f` | `55e95d467` | Applied cleanly | Dedup batch table writes by PartitionKey+RowKey; scope test discovery to CIPPTests module | `Add-CIPPAzDataTableEntity.ps1`, `Invoke-CIPPTestCollection.ps1` | Batch regression: 47/47 passed | Prevents duplicate test result rows. Table dedup affects all small-entity batch writes — monitor for side effects. |
| `ddc264a771b27807a35d12fd3645d4693b4a21f8` | — | Deferred | **Conflict** in `Invoke-CippTestGenericTest002.ps1` — fork diverged from upstream generic test logic | `Invoke-CippTestGenericTest002.ps1` | Not run | Cherry-pick aborted. Candidate #2 from proposed list. |
| `64836c02a801a3718c2bd2e598bcf206c973541d` | — | Deferred | **Conflict** in `Test-CIPPRerun.ps1` — fork has divergent rerun/scheduled-task logic (likely from v10.5.2 intake) | `Test-CIPPRerun.ps1` | Not run | Cherry-pick aborted. Pair with `2ab0e0e2` for adapted review. |
| `cbcc61b5afd8c7ea9bb9bef1da7878465afc5610` | — | Already implemented | ORCA103 test fix already present from v10.5.2 intake (`2699da195 Fixes ORCA103`) | `Invoke-CippTestORCA103.ps1` | Not run | Cherry-pick produced empty patch; skipped. |

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

1. Leave `ee0b8229` / `fdf313e5` deferred until explicit `CippReportingDB` cleanup review.
2. Review `Test-CIPPRerun.ps1` fork vs upstream for adapted apply of `64836c02` + `2ab0e0e2`.
3. Review `Invoke-CippTestGenericTest002.ps1` conflict for adapted apply of `ddc264a7`.
4. Verify ORCA test commits (`0640f07c`, etc.) against v10.5.2 intake before cherry-picking.
5. CIPP frontend batch remains deferred.
