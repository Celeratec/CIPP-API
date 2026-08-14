# Upstream Delta — CIPP-API — 2026-08-14

Cycle: **Major** — upstream **10.7.5 → 10.8.5**.

| | SHA / version |
|--|--|
| Last sync base | `245d9d35b` |
| Upstream tip | `e02ac3724` (`upstream/master`, **10.8.5**) |
| Fork production at cycle start | `b5f73e2c9` |
| Sync branch | `manage365/upstream-sync-cipp-api-20260814` |
| Backup tag | `backup/pre-upstream-sync-cipp-api-20260814` |

`Config/SAMManifest.json`: **no new permission IDs** required for planned Apply/Baselines batches (existing Roles/UserAuth/BitLocker scopes suffice).

## New HTTP entrypoints (selected)

| Endpoint | Outcome |
|----------|---------|
| `ListIntuneApprovalRequests` | Apply |
| `ListSecureScoreReport` | Apply |
| `ListTenantAllowBlockList` (Spamfilter path) | Adapt/Apply over fork flat |
| `ListRoles` (nested rewrite) | Adapt |
| `ExecSetDefaultMFAMethod` | Apply |
| `ListBrandingSettings` / `ListBrandingPresets` | Adapt with branding intake |
| Baseline List/Add/Run/Stage/Override/Alignment/Remove + ListBaselineStandards | Feature intake |
| `ListCommunityRepoTemplates` | Adapt |
| `PublicMcpRegister` | Defer/skip unless needed (MCP already intaken) |
| SSO / AppService / Container / WorkerHealth | Skip |

## Baselines backend bundle

- `Modules/CIPPCore/Public/Baselines/*.ps1` (29) + `Set-CippBaselineRunContext.ps1`
- Orchestrator `Start-CIPPBaselineOrchestrator` + activities `Push-CIPPBaselineStandard`, `Push-CIPPBaselineCacheRefresh`
- `Config/BaselineStandards/**` (~81 JSON)
- Feature flag `Baselines` (Enabled: false) + timer `9f2c7b1e-…`
- Helpers if missing: `Get-CIPPIntuneCompareExclusions`, `Get-CIPPIntunePolicyGraphPath`

SWA-safe: Durable + Azure Tables only (no Craft).
