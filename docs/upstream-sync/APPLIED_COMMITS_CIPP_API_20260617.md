# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 2 |
| Applied with adaptation | 1 |
| Skipped | 0 |
| Deferred | 0 |
| Already implemented | 0 |

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` | `365937de821318968bda27b9b44180160afef4b1` | Applied cleanly | Low-risk test/helper addition; no custom overlap | `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`) | Cherry-pick `-x` succeeded with no conflicts |
| `133f929555f5d26a17757802d22ceaa8b3f6b926` | `05f48e4fb` | Applied with adaptation | Partial apply only — Levenshtein test path fallback; skipped fuzzy-match test file | `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed (Levenshtein), 13 passed (`Tests/Tools`) | Full cherry-pick conflicted on modify/delete of `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1` (not in fork). Skipped fuzzy-match test path change and did not add upstream fuzzy-match helper. Added `Public/Tools/` → `Private/` path fallback per upstream intent. |
| `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` | `1784ccb993fdb316e37bf768168941deeea587f2` | Applied cleanly | Custom test alert-on-status feature; no protected-area overlap | `Invoke-AddCustomScript.ps1`, `Invoke-CippTestCustomScripts.ps1` | Pester: 47 passed (Levenshtein + `Tests/Tools` regression) | Adds configurable `AlertStatuses` for custom script test failures. No dedicated Pester suite for custom scripts. |

## Next Steps

1. Continue with remaining low-risk CIPP-API bugfix commits from `FIRST_PASS_REPORT_20260617.md` (e.g. `ee0b8229`, `fdf313e5`, `5ccf15a9`).
2. Keep deferring quarantine, auth, tenant, standards, and dependency commits until explicit review.
3. CIPP frontend batch remains deferred.
