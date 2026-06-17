# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 3 |
| Applied with adaptation | 1 |
| Skipped | 0 |
| Deferred | 2 |
| Already implemented | 0 |

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` | `365937de821318968bda27b9b44180160afef4b1` | Applied cleanly | Low-risk test/helper addition; no custom overlap | `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`) | Cherry-pick `-x` succeeded with no conflicts |
| `133f929555f5d26a17757802d22ceaa8b3f6b926` | `05f48e4fb` | Applied with adaptation | Partial apply only — Levenshtein test path fallback; skipped fuzzy-match test file | `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (Levenshtein), 13 passed (`Tests/Tools`) | Full cherry-pick conflicted on modify/delete of `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1` (not in fork). Skipped fuzzy-match test path change and did not add upstream fuzzy-match helper. Added `Public/Tools/` → `Private/` path fallback per upstream intent. |
| `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` | `1784ccb993fdb316e37bf768168941deeea587f2` | Applied cleanly | Custom test alert-on-status feature; no protected-area overlap | `Invoke-AddCustomScript.ps1`, `Invoke-CippTestCustomScripts.ps1` | Pester: 47 passed (Levenshtein + `Tests/Tools` regression) | Adds configurable `AlertStatuses` for custom script test failures. No dedicated Pester suite for custom scripts. |
| `ee0b82294a849bf992ec3ff7ce09b517f4e17fba` | — | Deferred | **Conflict:** upstream modifies `CippReportingDB` cleanup rule (`AddHours(-30)` → `AddDays(-30)`); that table cleanup block does not exist in the Manage365 fork | `Start-TableCleanup.ps1` | Not run | Cherry-pick aborted. Fork uses `AuditLogSearches` at `-12 hours` instead; no `CippReportingDB` entry. |
| `fdf313e5cfb08b2da7bba256201daf2de9ba15ff` | — | Deferred | **Conflict:** same file/block — removes `PartitionKey eq 'Search'` filter on `CippReportingDB` cleanup; block absent in fork | `Start-TableCleanup.ps1` | Not run | Cherry-pick aborted. Depends on `ee0b8229` context or manual addition of `CippReportingDB` cleanup rule. |
| `5ccf15a9197c67cb8fdde40606dd7b26a476ae1a` | `5d08be470412057bc8cba5fee192e374eacbe8fb` | Applied cleanly | Intune policy definition fallback when bulk Graph returns non-200; no protected-area overlap | `Invoke-ListIntunePolicy.ps1` | Pester: 47/47 passed (Levenshtein + `Tests/Tools` regression) | Adds template-based fallback for missing `settingDefinitions` on configuration policies. No Intune-specific Pester suite. |

## Next Steps

1. Decide whether to add `CippReportingDB` cleanup rule to `Start-TableCleanup.ps1` (with Manage365-appropriate retention) and then apply `ee0b8229` + `fdf313e5` with adaptation, or skip both permanently.
2. Continue with other isolated bugfixes from `FIRST_PASS_REPORT_20260617.md` (e.g. `9ba48711`, `4214bc7d`, `897dfaa4`, `23c8994d`).
3. Keep deferring quarantine, auth, tenant, standards, and dependency commits until explicit review.
4. CIPP frontend batch remains deferred.
