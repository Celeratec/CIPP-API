# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 8 |
| Applied with adaptation | 1 |
| Skipped | 0 |
| Deferred | 4 |
| Already implemented | 1 |

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
| `ecbc9a50ac0584e0d0ce59259214ebe6d9cf525a` | `6698dded1` | Applied cleanly | Graceful skip + Warning log when standard function missing from CIPPStandards module | `CIPPActivityTriggers/.../Push-CIPPStandard.ps1` | Batch regression: 47/47 passed | Changes failure mode from invoke error to early return with Warning. **Dual-copy note:** `CIPPCore/.../Push-CIPPStandard.ps1` not updated by upstream commit — may need mirrored fix if that copy is active. |
| `781930205c67fc17a5ca887755361987a407012a` | `b6ced9be6` | Applied cleanly | Fixes `$Item` variable shadowing in orchestrator batch retrieval loop | `CIPPActivityTriggers/.../Push-OrchestratorBatchItems.ps1` | Batch regression: 47/47 passed | Renames inner loop variable to `$BatchItem`. **Dual-copy note:** `CIPPCore/.../Push-OrchestratorBatchItems.ps1` still has shadowing bug. |
| `785e71c530a39b46f56cea7c598f7d609d8a8518` | — | Deferred | **Conflict:** fork has custom language handling `if ($Language -in @('user-select', 'os-default')) { $Language = "$null" }` vs upstream Graph API locale/language body fix | `Set-CIPPDefaultAPDeploymentProfile.ps1` | Not run | Cherry-pick aborted. Requires product review — fork may intentionally differ for Autopilot OOBE language selection. |

## Next Steps

1. Leave `ee0b8229` / `fdf313e5` deferred until explicit `CippReportingDB` cleanup review.
2. For `57b7de1f`: compare full `Invoke-ListIntuneTemplates.ps1` upstream vs fork.
3. For `785e71c5`: review Autopilot language behavior with product — decide adapted apply vs keep fork logic.
4. Consider mirroring `ecbc9a50` and `78193020` fixes into `CIPPCore` activity trigger copies if those are used at runtime.
5. Continue with other isolated bugfixes (e.g. `897dfaa4`-adjacent, `23c8994d`-adjacent, `5ccf15a9`-adjacent OData fixes in other endpoints).
6. CIPP frontend batch remains deferred.
