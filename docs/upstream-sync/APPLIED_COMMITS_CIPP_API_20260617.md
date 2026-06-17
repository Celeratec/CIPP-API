# Applied Commits Tracking — CIPP-API (Backend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-api-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-api-20260617`

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 1 |
| Applied with adaptation | 0 |
| Skipped | 0 |
| Deferred | 2 |
| Already implemented | 0 |

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` | `365937de821318968bda27b9b44180160afef4b1` | Applied cleanly | Low-risk test/helper addition; no custom overlap | `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Pester: 34 passed, 0 failed (`Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`) | Cherry-pick `-x` succeeded with no conflicts |
| `133f929555f5d26a17757802d22ceaa8b3f6b926` | — | Deferred | **Conflict (modify/delete):** `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1` deleted in our fork; upstream modifies it. Cherry-pick aborted per conflict-stop policy. | `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1` | Not run | Partial clean change to Levenshtein test paths was staged before abort. Manual review: apply Levenshtein path fix only, or skip until fuzzy-match feature is brought in. |
| `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` | — | Deferred | Not attempted — stopped after conflict on prior commit | `Invoke-AddCustomScript.ps1`, `Invoke-CippTestCustomScripts.ps1` | Not run | Resume after resolving `133f9295` decision |

## Next Steps

1. Decide whether to adopt `Find-CIPPFuzzyPolicyMatch` tests (requires upstream fuzzy-match helper) or cherry-pick only the Levenshtein test path fix from `133f9295` with adaptation.
2. After batch 1 is unblocked, apply `6aa66c74` (Custom Test - Alert on X statuses).
3. Continue with remaining low-risk bugfix commits from FIRST_PASS_REPORT_20260617.md.
