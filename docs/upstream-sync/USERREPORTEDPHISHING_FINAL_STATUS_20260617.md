# UserReportedPhishing — Final Paired Workstream Status

Generated: 2026-06-17  
Repos: Celeratec/CIPP-API + Celeratec/CIPP

## Workstream Summary

Paired upstream import of UserReportedPhishing alert support is **code-complete** on both repos. Operational rollout to production tenants is **partially complete** — backend validated; frontend exposed; first-tenant scheduler enablement pending.

| Phase | Status |
|-------|--------|
| CIPP-API backend (PR #2) | **Merged** |
| SAM manifest + permission | **Merged** |
| CPV/consent validation | **Clean** (pre-frontend) |
| Backend smoke test | **Clean** (pre-frontend) |
| CIPP frontend (PR #9) | **Merged** |
| First-tenant SchedulerConfig enablement | **Not performed** |
| Global/bulk enablement | **Blocked** until one clean run documented |

---

## CIPP-API

| Field | Value |
|-------|--------|
| **PR** | https://github.com/Celeratec/CIPP-API/pull/2 |
| **Merge commit** | `4b00ffeb6` |
| **Feature commit** | `7fed45fd7` |
| **Master tip (docs)** | `61278a254` (rollout runbook) + post-merge docs |
| **Backup tag** | `backup/pre-userreportedphishing-api-20260617` → `15df6c850` |

**Delivered:**

- `Get-CIPPAlertUserReportedPhishing` alert handler
- `ThreatSubmission.ReadWrite.All` in `Config/SAMManifest.json` and `Modules/CIPPCore/lib/data/SAMManifest.json`
- Pester regression: 47/47 passed
- Rollout runbook: `USERREPORTEDPHISHING_ROLLOUT_RUNBOOK_20260617.md`

**Validation completed before frontend exposure:**

- SAM table merge and CPV path exercised
- Admin consent confirmed in test context
- Handler smoke test: `Get-CIPPAlertUserReportedPhishing -InputValue @{ HoursBack = 24 }` — clean

---

## CIPP (Frontend)

| Field | Value |
|-------|--------|
| **PR** | https://github.com/Celeratec/CIPP/pull/9 |
| **Merge commit** | `7050757b2` |
| **Feature commit** | `5b3ef362c` |
| **Backup tag** | `backup/pre-userreportedphishing-frontend-20260617` |

**Delivered:**

- `UserReportedPhishing` entry in `src/data/alerts.json`
- `HoursBack` input, `recommendedRunInterval: 4h`
- Maps to backend via `Get-CIPPAlertUserReportedPhishing`

Upstream commit: `7054bfc4` (previously deferred in Cycle 1 sync until API rollout validated).

---

## Remaining Operational Step

**One-tenant SchedulerConfig enablement and production scheduler run validation.**

Operator checklist:

1. Confirm CIPP-API `master` and CIPP `main` (PR #9) deployed to target environment.
2. Enable `UserReportedPhishing` for **one test tenant** only (`HoursBack: 24`).
3. Wait for or trigger scheduler run (`recommendedRunInterval: 4h`).
4. Confirm alert trace output or clean no-op; no permission errors.
5. Document result (date, tenant, outcome).
6. **Do not bulk-enable globally** until step 5 is complete.

---

## Documentation Index

| Doc | Repo | Purpose |
|-----|------|---------|
| `USERREPORTEDPHISHING_API_20260617.md` | CIPP-API | Upstream import tracking |
| `USERREPORTEDPHISHING_POST_MERGE_20260617.md` | CIPP-API | Post-merge API validation record |
| `USERREPORTEDPHISHING_ROLLOUT_RUNBOOK_20260617.md` | CIPP-API | Operator SAM/CPV/smoke runbook |
| `USERREPORTEDPHISHING_FINAL_STATUS_20260617.md` | CIPP-API | This paired completion status |
| `USERREPORTEDPHISHING_FRONTEND_20260617.md` | CIPP | Frontend import tracking |
| `USERREPORTEDPHISHING_FRONTEND_POST_MERGE_20260617.md` | CIPP | Frontend post-merge status |

---

## Safety Notes

- Handler can remain dormant until SchedulerConfig enables the alert per tenant.
- Requires `ThreatSubmission.ReadWrite.All` on CIPP service principal in each tenant where enabled.
- Backup tags retained on both repos for rollback reference.
