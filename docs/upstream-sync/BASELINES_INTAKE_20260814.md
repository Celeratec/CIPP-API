# Baselines Feature Intake — 2026-08-14

Cycle type: **Feature intake** within major 10.8.x sync. Per [PROCESS.md](PROCESS.md).

## Feature: Baselines (drift-first engine)

- Upstream refs: `Modules/CIPPCore/Public/Baselines/*` (29), `Set-CippBaselineRunContext.ps1`, `Start-CIPPBaselineOrchestrator`, HTTP Baseline* entrypoints, `Config/BaselineStandards/**`, FE `src/pages/tenant/baselines/**` + `CippBaselines/*`, FeatureFlags `Baselines`, timer `9f2c7b1e-4a6d-4c3f-8b9a-5e1d2f7c0a44`
- Fork gap: no baselines pages/APIs/modules
- Protected conflicts: Applied Standards / drift UI — baselines are **parallel**, not a replacement; Adapt any shared Intune compare helpers
- Scope: **capability** on existing SWA + Function App Durable — no Craft, no EasyAuth migration
- Hosting: Azure Tables (`Baselines`, `BaselineRollouts`, `BaselineAlignment`, history/trend/locks) + existing `Start-CIPPOrchestrator` / standards processor slot
- Flag behavior: `Enabled: false` by default; flag gates **scheduled timer only**; pages/on-demand work when flag off (upstream design). Manage365 keeps flag off until smoke; optionally hide nav until enabled
- Phases: design → API modules/config/HTTP/orch → FE pages/components → verify → PR → deploy → enable flag after smoke
- Approval: [x] design (approved via major-cycle plan execute) [x] implement [ ] deploy (enable)

## Branding (sibling Adapt)

- Upstream: `ListBrandingSettings`, `ListBrandingPresets`, `Get-CIPPBranding*`, PDF cover helpers
- Fork: keep Manage365 `CippBrandingSettings` / `customBranding`; surgical merge only — do not wipe branding UX

## Explicit non-goals

- Replacing Applied Standards with Baselines
- Enabling Baselines timer in production by default
- Porting SSO/container nav that co-landed in 10.8
