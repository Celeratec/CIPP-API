# Upstream Delta — CIPP (frontend) — 2026-08-14

Cycle: **Major** — upstream **10.7.5 → 10.8.5** (plan drafted as 10.8.4; tip advanced).

| | SHA / version |
|--|--|
| Last sync base | `274880fd0` (upstream tip at 10.7.5) |
| Upstream tip | `a1b620403` (`upstream/main`, **10.8.5**) |
| Fork production at cycle start | `68dda9809` (`origin/main`) |
| Sync branch | `manage365/upstream-sync-cipp-20260814` |
| Backup tag | `backup/pre-upstream-sync-cipp-20260814` |

Noise excluded from triage: `public/intune-definitions/**` churn, bulk Vitest scaffolding (port only if a batch needs it).

## Triage themes

| Theme | Outcome | Notes |
|-------|---------|-------|
| Baselines pages (`src/pages/tenant/baselines/**`, `CippBaselines/*`) | **Feature intake** | Pair with API; flag off; nav commented upstream — wire carefully |
| Branding settings/PDF presets | **Adapt** | Preserve Manage365 `CippBrandingSettings` / `customBranding` |
| Intune approval requests | **Apply** | New page + API |
| BitLocker search page | **Apply** | New route; search helper already in fork |
| Secure Score report / AllTenants | **Adapt** | Pair with `ListSecureScoreReport` |
| Default MFA method on user page | **Adapt** | Surgical into fork user detail |
| Community repos catalog | **Adapt** | Large FE rework — surgical |
| BEC / user detail | **Adapt** | Protected-rich fork UI |
| Auth nav → authentication/container-management, SSO dialogs | **Skip** | SWA/Craft |
| Node/jsdom engine bumps, wholesale yarn.lock | **Defer** | After feature ports |
| CippDataTable / top-nav / standards accordion | **Adapt only** | Protected |

## Protected map refresh note

Still authoritative: [CUSTOM_FEATURE_MAP_20260617.md](./CUSTOM_FEATURE_MAP_20260617.md). This cycle adds: Baselines parallel to Applied Standards (do not replace drift UI); branding Adapt-not-replace; skip auth nav split.
