# Custom Feature Map — Manage365/CIPP

Generated: 2026-06-17 11:21

Purpose: Protected areas that must not be overwritten during upstream sync.

## Git State at Generation Time

| Repo | Branch | Tip | Upstream behind |
|------|--------|-----|-----------------|
| CIPP | `main` | `f2d87612e` | 241 commits (`upstream/main`) |
| CIPP-API | `master` | `de78a343e` | 315 commits (`upstream/master`) |

## Protected Custom Areas

### Manage365 Branding & Versioning

**Purpose:** Fork identity, version display, OAuth branding, release tooling separate from upstream version.json

**Risk if overwritten:** Critical — overwriting removes product identity and version tracking

**Upstream overlap likelihood:** High — upstream touches version.json, settings pages, logo, README regularly

**Notes for conflict resolution:** Preserve manage365-version.json as primary display version. Update-Version.ps1 writes both upstream and Manage365 versions. Get-CippAlerts includes Manage365-specific upstream drift alerts.

**CIPP files:**
- `public/manage365-version.json`
- `public/version.json`
- `Tools/Update-Version.ps1`
- `src/components/CippSettings/CippVersionProperties.jsx`
- `src/components/logo.js`
- `src/layouts/top-nav.js`
- `src/layouts/config.js`
- `src/components/CippComponents/CIPPM365OAuthButton.jsx`
- `src/components/ReleaseNotesDialog.js`
- `README.md`

**CIPP-API files:**
- `version_latest.txt`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-GetCippAlerts.ps1`

---

### Quarantine Portal 5.13.0

**Purpose:** Advanced quarantine management UI, shared components, server-side filtering, export, bulk actions, lazy detail loading

**Risk if overwritten:** Critical — major custom feature set beyond upstream

**Upstream overlap likelihood:** Very High — upstream actively changes quarantine endpoints and UI

**Notes for conflict resolution:** Uses EXO PowerShell not Graph. manualPagination, post-filters, 7d default window, export cap 5k. Never auto-resolve conflicts toward upstream.

**CIPP files:**
- `src/components/CippComponents/quarantine/`
- `src/pages/email/administration/quarantine/index.js`
- `Tests/Shapes/GetMailQuarantineMessage.json`
- `Tests/Shapes/ListQuarantinePolicy.json`

**CIPP-API files:**
- `Modules/CIPPCore/Public/Tools/Build-CIPPQuarantineQueryParams.ps1`
- `Modules/CIPPCore/Public/Tools/Get-CippQuarantineInputValue.ps1`
- `Modules/CIPPCore/Public/Tools/ConvertTo-CippQuarantineStringArray.ps1`
- `Modules/CIPPCore/Public/Tools/ConvertTo-CippQuarantineReleaseStatusApiValue.ps1`
- `Modules/CIPPCore/Public/Tools/ConvertTo-CippQuarantineDisplayObject.ps1`
- `Modules/CIPPCore/Public/Tools/Invoke-CippQuarantineExoRequest.ps1`
- `Modules/CIPPCore/Public/Tools/Get-CippQuarantinePagedResults.ps1`
- `Modules/CIPPCore/Public/Tools/Apply-CippQuarantinePostFilters.ps1`
  (helpers split one-function-per-file 2026-07-01: CIPPCore exports by file basename,
  so co-located functions were invisible to CIPPHTTP/CIPPActivityTriggers callers)
- `Tests/Tools/Build-CIPPQuarantineQueryParams.Tests.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ListMailQuarantine.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-GetMailQuarantineMessage.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExportMailQuarantine.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecQuarantineManagement.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecMailboxSafeSender.ps1`
- `Modules/CIPPCore/Public/Entrypoints/Activity Triggers/Push-ListMailQuarantineAllTenants.ps1`
- `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ListMailQuarantineAllTenants.ps1`
- `docs/QUARANTINE_FEATURES.md`
- `Tests/Endpoint/Invoke-GetMailQuarantineMessage.Tests.ps1`
- `Tests/Endpoint/Invoke-ExportMailQuarantine.Tests.ps1`

---

### Email Troubleshooter Enhancements

**Purpose:** Integrated quarantine tab, trace presets, bulk refresh fixes, shared quarantine UI in troubleshooter context

**Risk if overwritten:** High — tightly coupled to quarantine shared module

**Upstream overlap likelihood:** High — upstream changes email tools and troubleshooting pages

**Notes for conflict resolution:** ExecEmailTroubleshoot reuses Build-CIPPQuarantineQueryParams. Preserve trace/EML preset behavior.

**CIPP files:**
- `src/pages/email/troubleshooting/email-troubleshooter/index.js`
- `src/pages/email/troubleshooting/message-viewer/index.js`
- `docs/superpowers/plans/2026-03-21-email-troubleshooter.md`
- `docs/superpowers/specs/2026-03-21-email-troubleshooter-design.md`

**CIPP-API files:**
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ExecEmailTroubleshoot.ps1`

---

### Custom Tenant Workflows

**Purpose:** Tenant management, GDAP onboarding, tenant mode deployment, configuration backup/restore

**Risk if overwritten:** High — core MSP workflow customizations

**Upstream overlap likelihood:** Medium-High — upstream frequently updates tenant admin pages

**Notes for conflict resolution:** Includes license capability presets, CA template package tags, group-based licensing, excludeFromAlert.

**CIPP files:**
- `src/components/CippWizard/`
- `src/pages/tenant/manage/`
- `src/pages/tenant/gdap-management/`
- `src/pages/cipp/advanced/super-admin/tenant-mode.js`
- `src/pages/cipp/settings/tenants.js`
- `src/pages/onboarding.js`
- `src/pages/onboardingv2.js`

**CIPP-API files:**
- `Modules/CIPPCore/Public/Tenant/Get-CIPPTenantAlignment.ps1` *(may not exist)*
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Invoke-ListTenantAlignment.ps1` *(may not exist)*

---

### Navigation & Search UX

**Purpose:** Hybrid universal search in top nav, frosted glass styling, dashboard v2 routing, custom breadcrumbs

**Risk if overwritten:** High — visible UX differentiators

**Upstream overlap likelihood:** High — upstream changes nav, search, dashboard frequently

**Notes for conflict resolution:** Removed legacy dashboard v1. Redirect /dashboardv1 → dashboardv2. Hybrid search preserved over upstream CippCentralSearch removal.

**CIPP files:**
- `src/layouts/top-nav.js`
- `src/layouts/config.js`
- `src/components/CippComponents/CippBreadcrumbNav.jsx`
- `src/pages/_app.js`

---

### Custom Permissions & Roles

**Purpose:** CIPP role management, SAM deployment, super-admin settings

**Risk if overwritten:** Critical — auth/authorization changes can lock out admins

**Upstream overlap likelihood:** Medium — upstream changes role checks and SAM manifest

**Notes for conflict resolution:** Any SAMManifest.json changes require CPV refresh to client tenants.

**CIPP files:**
- `src/pages/cipp/advanced/super-admin/cipp-roles/`
- `src/components/CippSettings/CippRoleAddEdit.jsx`
- `src/components/CippWizard/CippSAMDeploy.jsx`

**CIPP-API files:**
- `lib/data/SAMManifest.json` *(may not exist)*

---

### Manage365-Specific API Behavior

**Purpose:** Custom transport rules, alert messaging, mailbox restrictions

**Risk if overwritten:** High — tenant-specific automation

**Upstream overlap likelihood:** Low-Medium

**Notes for conflict resolution:** Manage365 - Block External Outbound transport rule auto-creation.

**CIPP-API files:**
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecSetMailboxRestriction.ps1`
- `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Users/Invoke-ListUserMailboxDetails.ps1`

---

### Standards & Compliance Customizations

**Purpose:** CIS 7.0 renumbering, ORCA fixes intake, applied standards license warnings, template handling

**Risk if overwritten:** Medium-High — affects compliance reporting

**Upstream overlap likelihood:** High — upstream actively updates standards

**Notes for conflict resolution:** Recent v10.5.2 intake included ORCA fixes — verify not duplicated when cherry-picking.

**CIPP files:**
- `src/data/standards.json`
- `src/components/CippStandards/`

**CIPP-API files:**
- `Modules/CIPPCore/Public/Standards/`
- `Modules/CIPPStandards/Public/Standards/`

---

### Data Table & UI Performance

**Purpose:** CippDataTable optimizations with card view preserved, table search fixes

**Risk if overwritten:** Medium — shared component used everywhere

**Upstream overlap likelihood:** High

**Notes for conflict resolution:** cf721215c ported upstream table optimizations without losing card view.

**CIPP files:**
- `src/components/CippTable/`

---

### OAuth & Auth Flow

**Purpose:** BroadcastChannel for popup auth completion, OAuth grace period

**Risk if overwritten:** High — login failures if broken

**Upstream overlap likelihood:** Medium

**Notes for conflict resolution:** c81921ce7 OAuth broadcast channel — preserve over upstream auth changes.

**CIPP files:**
- `src/components/CippComponents/CIPPM365OAuthButton.jsx`
- `src/pages/_app.js`

---

## Recent Custom Commits (post v10.5.2 intake baseline)

These commits on production branches represent work done AFTER the last upstream intake and are especially protected:

### CIPP (`main` since `pre-upstream-merge-v1052-20260617`)

- `f2d87612e chore: update dependencies and remove pnpm lock file`
- `fba60b9f5 chore: update quarantine management features and version bump`
- `349eb5e9f chore: upstream v10.5.2 intake — quarantine pagination and version bump`
- `34dc2cff6 manual pagination support for Invoke-ListMailQuarantine`

### CIPP-API (`master` since `pre-upstream-merge-v1052-20260617`)

- `de78a343e refactor: enhance quarantine message retrieval and filtering`
- `bff606d1d chore: upstream v10.5.2 intake — ORCA fixes, standards, quarantine, version bump`
- `5c748cd80 fix: add early template filter when supplied`
- `ab0b292c5 manual pagination support for Invoke-ListMailQuarantine`
- `684a78c3e bulk request next link following`
- `76b390f1a fix: rerun issue`
- `103815550 Fixes ORCA244`
- `3626847a1 Fixes ORCA235`
- `171f8a341 Fixes ORCA242`
- `8bb7b1c3e Fixes ORCA233_1`
- `2699da195 Fixes ORCA103`
- `47c28390b Fixes ORCA113`
- `8d3fbc49d Update policy based on MS and Orca guidance`
- `2f083afbb Fixes ORCA179`
- `794a13ed2 Fix for ORCA107 and add Exchange Global Quarantine policy to cache`
- `95d8f78ed Fix ORCA104`
- `982621d14 Update Invoke-ListTenantAlignment.ps1`
- `a0418fdfc Update Invoke-ListTenantAlignment.ps1`
- `d9a8c33b5 fix: rerun detection on scheduled tasks`

## Conflict Resolution Rules

1. **Never** auto-resolve toward upstream for files in this map
2. **Preserve** Manage365 branding, quarantine portal, and email troubleshooter behavior
3. **Integrate** upstream bug fixes only when they don't regress custom behavior
4. **Pause** for approval on any commit touching High-risk areas above
5. **Document** every adaptation in APPLIED_COMMITS tracking files
