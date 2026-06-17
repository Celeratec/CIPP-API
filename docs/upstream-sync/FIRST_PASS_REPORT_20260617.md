# Upstream Sync — First Pass Inspection Report

Generated: 2026-06-17  
Phase: **Setup complete — CIPP-API cherry-picks in progress**

---

## 1. Git State Summary

### CIPP (Frontend)

| Item | Value |
|------|-------|
| Current branch | `main` |
| Working tree | Clean |
| vs origin | Ahead by 1 commit (unpushed) |
| Current tip | `f2d87612e` — chore: update dependencies and remove pnpm lock file |
| Upstream remote | `upstream` → `KelvinTegelaar/CIPP.git` ✓ |
| Upstream tracking branch | `upstream/main` |
| Upstream tip | `0d8ca9d2f` — Merge pull request #6153 from KelvinTegelaar/dev |
| Merge base | `0710355e2` |
| **Commits behind upstream** | **241** |

### CIPP-API (Backend)

| Item | Value |
|------|-------|
| Current branch | `master` |
| Working tree | Clean |
| vs origin | Up to date |
| Current tip | `de78a343e` — refactor: enhance quarantine message retrieval and filtering |
| Upstream remote | `upstream` → `KelvinTegelaar/CIPP-API.git` ✓ |
| Upstream tracking branch | `upstream/master` |
| Upstream tip | `5a0ddb29c` — Dev to hotfix (#2088) |
| Merge base | `6871d267e` |
| **Commits behind upstream** | **315** |

### Remotes (both repos)

| Remote | CIPP | CIPP-API |
|--------|------|----------|
| `origin` | `Celeratec/CIPP.git` | `Celeratec/CIPP-API.git` |
| `upstream` | `KelvinTegelaar/CIPP.git` | `KelvinTegelaar/CIPP-API.git` |

Upstream fetch completed successfully during this inspection.

---

## 2. Protective Setup

## 2. Protective Setup

Sync branches and backup tags created on 2026-06-17:

| Repo | Production branch | Backup tag | Sync branch |
|------|-------------------|------------|-------------|
| CIPP | `main` @ pushed tip | `backup/pre-upstream-sync-cipp-20260617` | `manage365/upstream-sync-cipp-20260617` |
| CIPP-API | `master` | `backup/pre-upstream-sync-cipp-api-20260617` | `manage365/upstream-sync-cipp-api-20260617` |

Tags and sync branches are local only (not pushed to origin unless approved).

---

---

## 3. Documents Generated

| Document | Location |
|----------|----------|
| CIPP upstream inventory (241 commits) | `docs/upstream-sync/UPSTREAM_SYNC_CIPP_20260617.md` |
| CIPP-API upstream inventory (315 commits) | `docs/upstream-sync/UPSTREAM_SYNC_CIPP_API_20260617.md` |
| Custom feature map | `docs/upstream-sync/CUSTOM_FEATURE_MAP_20260617.md` (both repos) |
| Applied commits tracker (empty) | `docs/upstream-sync/APPLIED_COMMITS_CIPP_20260617.md` |
| Applied commits tracker (empty) | `docs/upstream-sync/APPLIED_COMMITS_CIPP_API_20260617.md` |

---

## 4. Inventory Statistics

### CIPP — 241 upstream commits

| Risk | Count |
|------|-------|
| Low | 11 |
| Medium | 80 |
| High | 150 |

| Recommendation | Count |
|----------------|-------|
| Needs manual review | 200 |
| Cherry-pick with adaptation | 30 |
| Cherry-pick (clean) | 11 |

**Notable buckets:** 136 dependency/build, 157 potentially breaking, 15 touch protected custom areas.

### CIPP-API — 315 upstream commits

| Risk | Count |
|------|-------|
| Low | 48 |
| Medium | 37 |
| High | 230 |

| Recommendation | Count |
|----------------|-------|
| Needs manual review | 228 |
| Cherry-pick with adaptation | 39 |
| Cherry-pick (clean) | 48 |

**Notable buckets:** 49 tests-only, 216 dependency/build tagged, 11 touch protected custom areas.

---

## 5. Custom Features at Risk

See `CUSTOM_FEATURE_MAP_20260617.md` for full detail. Highest-risk protected areas:

1. **Quarantine Portal 5.13.0** — Very high upstream overlap; 20+ custom API files + shared frontend module
2. **Manage365 Branding/Versioning** — `manage365-version.json`, dual version tooling, drift alerts
3. **Email Troubleshooter** — Shares quarantine components; `Invoke-ExecEmailTroubleshoot.ps1`
4. **Navigation/Search UX** — Hybrid top-nav search, dashboard v2 routing (upstream changes nav frequently)
5. **Tenant Workflows** — GDAP, tenant mode, alignment with custom license/CA template logic
6. **OAuth Auth Flow** — BroadcastChannel popup completion (custom, not upstream)

**Recent post-intake commits (especially protected):**

CIPP (`main` since `pre-upstream-merge-v1052-20260617`):
- Quarantine management features + version bump
- v10.5.2 intake (quarantine pagination)
- manual pagination for ListMailQuarantine
- Dependency update (unpushed on main)

CIPP-API (`master` since `pre-upstream-merge-v1052-20260617`):
- Quarantine message retrieval refactor
- v10.5.2 intake (ORCA fixes, standards, quarantine)
- ORCA standards fixes (ORCA103–244)
- Tenant alignment updates

---

## 6. First Pass Results

| Metric | CIPP | CIPP-API | Total |
|--------|------|----------|-------|
| Upstream commits reviewed | 241 | 315 | **556** |
| Applied | 0 | 0 | 0 |
| Adapted | 0 | 0 | 0 |
| Skipped | 0 | 0 | 0 |
| Deferred | 0 | 0 | 0 |
| Conflicts encountered | 0 | 0 | 0 |
| Tests run | 0 | 0 | 0 |

---

## 7. Recommended First Batch (Low-Risk)

Apply **only after** creating sync branches and backup tags. Review each commit against `CUSTOM_FEATURE_MAP` before cherry-picking.

### CIPP-API — Start here (more clean test/bugfix commits)

Priority order — tests and isolated bugfixes with ≤2 files, no protected-path overlap:

| # | SHA | Title | Category |
|---|-----|-------|----------|
| 1 | `2b441244` | feat: Add Levenshtein distance function and tests | Tests |
| 2 | `133f9295` | test: fix helper paths after tools folder move | Tests |
| 3 | `6aa66c74` | Custom Test - Alert on X statuses | Tests |
| 4 | `ee0b8229` | fix: change cleanup to 30 days | Bugfix |
| 5 | `fdf313e5` | fix: remove partitionkey | Bugfix |
| 6 | `ecbc9a50` | fix: Add error handling for missing standard functions | Bugfix |
| 7 | `57b7de1f` | fix: Rename 'usedInTemplates' to 'usage' | Bugfix |
| 8 | `23c8994d` | fixes defaultr_hidden vs hidden #5990 | Bugfix |
| 9 | `897dfaa4` | fixed #5997 | Bugfix |
| 10 | `5ccf15a9` | fix: missing odata path error in returned json | Bugfix |
| 11 | `9ba48711` | correct incorrect default value | Bugfix |
| 12 | `4214bc7d` | Fix: Fix missing OData path error in JSON response (#2054) | Bugfix |
| 13 | `71afcdd2` | ExoTransportConfig cache type - fix for missing data | Tests |

**Checkpoint before:** `1aa55cff` (Intune standard change detection), `affac9d0` (standards run errors), `12bb4f69` (caching cleanup) — these touch standards/cache and need review.

### CIPP — Smaller first batch (many upstream commits are dependency/build)

| # | SHA | Title | Category | Notes |
|---|-----|-------|----------|-------|
| 1 | `98d5d94a` | Custom Test - Alert on X statuses | Tests | Low overlap |
| 2 | `1e59d2d4` | Update ListTests.json | Tests | Verify shape compatibility |
| 3 | `e3ed1818` | fix alert mode | Bugfix | 1 file |
| 4 | `60a50738` | fixes tenantfilter property | Bugfix | Review tenant context |
| 5 | `0a8252e3` | fix: version encoding | Bugfix | **Checkpoint** — touches version |
| 6 | `707873e3` | fix: Fix tab title showing as undefined | Bugfix | UI, low risk |
| 7 | `89abbf50` | fix: improve stale issue and close messages | Bugfix | GitHub workflow |
| 8 | `5709f856` | fix: update terminology Temporary Access Password | Bugfix | i18n only |

**Skip/defer in CIPP first batch:**
- `983b48a1` / `bde8ad3c` — worktrees cleanup (may already exist on `fix/remove-claude-worktrees` branch; verify)
- `c8d61c07` — JIT admin fix (**Already implemented differently** at `7e1bab525`)
- `1ea0324e` — search-on-load fix (verify against our table search fix at `18c21fc6b`)
- `f768330c` — CIS standards tag move (**conflicts with our CIS 7.0 renumbering**)
- `fe4bd7f9` — alltenants sync (review tenant context)
- All Dependabot / package.json commits — **explicit approval required**

---

## 8. Commits Requiring Approval Before Any Apply

Any upstream commit touching these areas must pause for review (see inventory Notes column for full list):

- Quarantine / spamfilter / `Build-CIPPQuarantineQueryParams`
- Email Troubleshooter / `ExecEmailTroubleshoot`
- Exchange Online / mailbox / transport
- Authentication / OAuth / SAM / roles / `SAMManifest.json`
- Tenant switching / tenantFilter / GDAP / alignment
- Branding / version.json / manage365-version
- Navigation / config.js / top-nav
- Shared API helpers (`New-GraphPostRequest`, etc.)
- Dependency upgrades / build tooling
- Large refactors (>5 files or "refactor" in title)

---

## 9. Known Risks

1. **Prior partial intake** — v10.5 / v10.5.2 selective intake already applied many upstream commits with adaptation. Some inventory commits may be **already implemented differently** (e.g., JIT admin, table search, quarantine pagination).
2. **High dependency churn in CIPP** — 136 of 241 commits touch package.json/CI; batching these blindly risks breaking the SWA build.
3. **Standards divergence** — CIS 7.0 renumbering and ORCA fixes on our side may conflict with upstream standards.json changes.
4. **Quarantine active development** — Both forks and upstream are changing quarantine simultaneously; highest conflict risk.
5. **Unpushed CIPP commit** — `main` is 1 commit ahead of origin (`f2d87612e` dependency update); push or include in sync branch baseline.

---

## 10. Recommended Next Steps

1. **Approve** creation of sync branches + backup tags (commands in §2)
2. **Review** this report and the first-batch table
3. **Begin CIPP-API** with test-only commits (`2b441244`, `133f9295`, `6aa66c74`)
4. **Run Pester** after each API batch: `Invoke-Pester -Path Tests/Tools,Tests/Endpoint -Output Detailed`
5. **CIPP second** — start with test commits, defer all dependency bumps
6. **Schedule checkpoint reviews** for quarantine, auth, tenant, and standards batches

---

## 11. Remaining Manual Decisions

- [ ] Confirm date stamp for sync branches (`20260617` vs `20260617` — branch history uses 20260617)
- [ ] Push unpushed CIPP commit before sync branch creation?
- [ ] Whether to skip upstream commits already implemented differently (JIT admin, search fixes)
- [ ] Dependency upgrade strategy — individual bumps vs grouped batch with build verification
- [ ] Standards/ORCA commits — merge vs skip given recent v10.5.2 intake
- [ ] Quarantine upstream delta — full diff review before any quarantine cherry-picks
