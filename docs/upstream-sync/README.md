# Upstream sync (CIPP-API)

Manage365 upstream sync process is documented in the **CIPP** repo:

**[../../CIPP/docs/upstream-sync/PROCESS.md](../../CIPP/docs/upstream-sync/PROCESS.md)** (sibling repo when checked out as `GitHub/CIPP` + `GitHub/CIPP-API`)

Start a backend cycle from this repo root:

```powershell
../CIPP/Tools/Start-UpstreamSyncCycle.ps1 -Repo CIPP-API
```

Cycle-specific API docs for June 2026 live in this folder (`CIPP_API_SYNC_CHECKPOINT_*.md`, etc.).
