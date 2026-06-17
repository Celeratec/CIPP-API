# Upstream Sync Inventory — CIPP-API (Backend)

Generated: 2026-06-17 11:21

## Summary

| Field | Value |
|-------|-------|
| Our branch tip | `de78a343e1b8074afcbb417b344a6325704b94ee` |
| Upstream branch | `upstream/master` |
| Upstream tip | `5a0ddb29c3770525813aefea5e356fc56b088eeb` |
| Merge base | `6871d267ebec580b5097f44e7623c0d71c2c5581` |
| Commits to review | **315** |

### Risk Distribution

- **Low**: 48
- **Medium**: 37
- **High**: 230

### Recommendation Distribution

- **Needs manual review**: 228
- **Cherry-pick**: 48
- **Cherry-pick with adaptation**: 39

### Review Buckets

- **Potentially breaking changes**: 236
- **Dependency/build changes**: 216
- **Tests-only**: 49
- **Other**: 21
- **Bug fixes**: 8
- **Security fixes**: 4
- **Documentation-only**: 4
- **Tenant management changes**: 4
- **Authentication/permissions changes**: 4
- **Exchange/Email changes**: 3
- **Intune changes**: 2

---

## Commit Inventory

### 1. `c8419545` — Merge pull request #85 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `c84195451eeb8c3a5033fe9b13a0cc238f2d657f` |
| Author | Integrated Solutions |
| Date | 2026-03-10 09:02:26 +1000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 2. `b0e1f0c9` — Merge pull request #89 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `b0e1f0c9bf991e7abb6a40b3d3ead2e33be1c97e` |
| Author | Integrated Solutions |
| Date | 2026-03-20 09:47:35 +1000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 3. `2b441244` — feat: Add Levenshtein distance function and tests

| Field | Value |
|-------|-------|
| SHA | `2b4412449f1905c0bd8d5f89e93dcdeaac736d39` |
| Author | Kristian Kjærgård |
| Date | 2026-03-20 14:00:40 +0100 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Private/Get-CIPPLevenshteinDistance.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`

---

### 4. `54b9af07` — feat: add configurable fuzzy Intune policy matching for standards deployments

| Field | Value |
|-------|-------|
| SHA | `54b9af07ddd21f9af745dd9fd6480e71cb13c7d5` |
| Author | Bobby |
| Date | 2026-03-20 20:29:47 +0100 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Private/Find-CIPPFuzzyPolicyMatch.ps1`, `Modules/CIPPCore/Public/Set-CIPPIntunePolicy.ps1`, `Modules/CIPPCore/Public/Standards/Invoke-CIPPStandardIntuneTemplate.ps1`, `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1`

---

### 5. `5ef7bbc0` — Add support for CA template package tags

| Field | Value |
|-------|-------|
| SHA | `5ef7bbc019961bc9019aa239a0c4f89f31780d50` |
| Author | James Tarran |
| Date | 2026-04-03 09:06:35 +0100 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ExecSetPackageTag.ps1`, `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/Tenant/Conditional/Invoke-ListCAtemplates.ps1`, `Modules/CIPPCore/Public/Functions/Get-CIPPTenantAlignment.ps1`, `Modules/CIPPCore/Public/Get-CIPPDrift.ps1`, `Modules/CIPPCore/Public/Standards/Get-CIPPStandards.ps1`, `Modules/CIPPCore/Public/Standards/Invoke-CIPPStandardConditionalAccessTemplate.ps1`

---

### 6. `5d43bea7` — Use template displayName for labels

| Field | Value |
|-------|-------|
| SHA | `5d43bea7d24ba8832650aff443743526d2796357` |
| Author | James Tarran |
| Date | 2026-04-03 16:41:22 +0100 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Standards/Get-CIPPStandards.ps1`

---

### 7. `131a95ac` — Merge pull request #93 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `131a95ac9ce54fc37123dccf8efa810ed5ed09e3` |
| Author | Integrated Solutions |
| Date | 2026-04-15 14:38:50 +1000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 8. `7c524eda` — Merge remote-tracking branch 'upstream/dev' into levenshtein-distance

| Field | Value |
|-------|-------|
| SHA | `7c524edaefaedb5946e23cd2d2d80e2ffc716fa3` |
| Author | Bobby |
| Date | 2026-04-16 12:35:06 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 9. `133f9295` — test: fix helper paths after tools folder move

| Field | Value |
|-------|-------|
| SHA | `133f929555f5d26a17757802d22ceaa8b3f6b926` |
| Author | Bobby |
| Date | 2026-04-16 12:38:41 +0200 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Tests/Private/Find-CIPPFuzzyPolicyMatch.Tests.ps1`, `Tests/Private/Get-CIPPLevenshteinDistance.Tests.ps1`

---

### 10. `631cb269` — Merge pull request #44 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `631cb2690239d9823abc996a5864ad8837facdb7` |
| Author | pull[bot] |
| Date | 2026-04-20 17:36:34 +0000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 11. `6c1da764` — Merge pull request #45 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `6c1da7642d064ea5e6fc6e0bc24c15d59285c246` |
| Author | pull[bot] |
| Date | 2026-04-21 05:36:29 +0000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 12. `1dd59c5c` — Merge pull request #46 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `1dd59c5cc0be2e5a76e5afd638b6102d7f9d674d` |
| Author | pull[bot] |
| Date | 2026-04-21 11:36:33 +0000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 13. `886e9b33` — Merge branch 'dev' into Feat-Conditional-access-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `886e9b331531cf255b7d0ee0f22175121331e9a6` |
| Author | James Tarran |
| Date | 2026-04-22 08:44:29 +0100 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 14. `e210c484` — Merge branch 'dev' into Feat-Conditional-access-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `e210c484d0788780e07a9c5fac00256e382a8a9e` |
| Author | James Tarran |
| Date | 2026-04-22 08:47:13 +0100 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 15. `2a2772b4` — feat: add allTenants support for multiple intune pages

| Field | Value |
|-------|-------|
| SHA | `2a2772b424c958f2fab0d4fd6131c8e5e31f3203` |
| Author | Bobby |
| Date | 2026-04-25 01:32:32 +0200 |
| Files changed | 20 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPAssignmentFilterReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntuneAppProtectionPolicyReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntuneApplicationReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntuneCompliancePolicyReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntuneReusableSettingsReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntuneScriptReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPManagedDevicesReport.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneAppProtectionPolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneApplications.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneAssignmentFilters.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneCompliancePolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneReusableSettings.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneScripts.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-ListApps.ps1` … (+5 more)

---

### 16. `7e9f7192` — feat: Add allTenants support for all the Teams  SharePoint pages

| Field | Value |
|-------|-------|
| SHA | `7e9f7192d35568af060d0152e77458ea58930bcf` |
| Author | Bobby |
| Date | 2026-04-26 19:13:53 +0200 |
| Files changed | 16 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/CIPPDBCache/Push-ExecCIPPDBCache.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-CIPPDBCacheData.ps1`, `Modules/CIPPCore/Public/Get-CIPPSitesReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPTeamsActivityReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPTeamsReport.ps1`, `Modules/CIPPCore/Public/Get-CIPPTeamsVoiceReport.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSites.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheTeams.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheTeamsActivity.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheTeamsVoice.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ListSites.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ListTeams.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ListTeamsActivity.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ListTeamsVoice.ps1` … (+1 more)

---

### 17. `29685d69` — feat(api): add license capability presets

| Field | Value |
|-------|-------|
| SHA | `29685d69b00fcc1cb774ae60600cd7607d2520b1` |
| Author | Bobby |
| Date | 2026-05-04 22:54:54 +0200 |
| Files changed | 138 |
| Risk | **High** |
| Area | Docs |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal, Permissions/Roles/Auth; Buckets: Documentation-only, Potentially breaking changes |

**Files:** `.github/agents/CIPP-Alert-Agent.md`, `.github/agents/CIPP-Standards-Agent.md`, `.github/instructions/alerts.instructions.md`, `.github/instructions/cippdb.instructions.md`, `.github/instructions/standards.instructions.md`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-CIPPDBCacheData.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Standards/Push-CIPPStandardsList.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertIntunePolicyConflicts.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertQuarantineReleaseRequests.ps1`, `Modules/CIPPCore/Public/Functions/Test-CIPPStandardLicense.ps1`, `Modules/CIPPCore/Public/Get-CIPPDrift.ps1`, `Modules/CIPPCore/Public/Test-CIPPAccessTenant.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheConditionalAccessPolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheDlpCompliancePolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntunePolicies.ps1` … (+123 more)

---

### 18. `daa8d242` — Merge pull request #95 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `daa8d2424300e2cacbb4a8ca22fd34dbebe43641` |
| Author | Integrated Solutions |
| Date | 2026-05-05 14:39:04 +1000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 19. `106f7463` — Add AAD Premium license gate to ExternalMFATrusted standard

| Field | Value |
|-------|-------|
| SHA | `106f7463478cab7e254eef55fd686badecdbf40b` |
| Author | Brian Simpson |
| Date | 2026-05-08 12:53:49 -0500 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardExternalMFATrusted.ps1`

---

### 20. `b8b26a27` — Update standards docs URLs to alignment/templates path

| Field | Value |
|-------|-------|
| SHA | `b8b26a2768a4eba69a7e8ccb69664e8292de3c5a` |
| Author | Brian Simpson |
| Date | 2026-05-03 11:34:58 -0500 |
| Files changed | 182 |
| Risk | **High** |
| Area | Docs |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal, Permissions/Roles/Auth; Buckets: Documentation-only, Potentially breaking changes |

**Files:** `.github/instructions/standards.instructions.md`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardActivityBasedTimeout.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAddDKIM.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAddDMARCToMOERA.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAdminSSPR.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAnonReportDisable.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAntiPhishPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAntiSpamSafeList.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAppDeploy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAppManagementPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAssignmentFilterTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAtpPolicyForO365.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAuditLog.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAuthMethodsPolicyMigration.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAuthMethodsSettings.ps1` … (+167 more)

---

### 21. `9683b790` — Fix standards run errors for Retention and MDO standards

| Field | Value |
|-------|-------|
| SHA | `9683b79002ef95d7b070e5729f8edeee6098475b` |
| Author | Brian Simpson |
| Date | 2026-05-03 11:35:26 -0500 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoPresetSecurityPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAtpPolicyForO365.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardRetentionPolicyTag.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeAttachmentPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeLinksPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeLinksTemplatePolicy.ps1`

---

### 22. `07f29839` — purview adding

| Field | Value |
|-------|-------|
| SHA | `07f2983924a0075e46abff211b781593d9b7c6cf` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 01:26:02 +0200 |
| Files changed | 13 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/standards.json`, `Modules/CIPPCore/Public/Set-CIPPDefaultAPDeploymentProfile.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-DLP/Invoke-AddDlpCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-DLP/Invoke-AddDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-Retention/Invoke-AddRetentionCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-Retention/Invoke-AddRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SIT/Invoke-AddSensitiveInfoType.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SIT/Invoke-AddSensitiveInfoTypeTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SensitivityLabel/Invoke-AddSensitivityLabel.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitiveInfoTypeTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitivityLabelTemplate.ps1`

---

### 23. `b7f32e7a` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `b7f32e7ae720b8c4e7ab1be0ff060d6ab7ca86cf` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 01:26:06 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 24. `a187a17a` — set warn to true.

| Field | Value |
|-------|-------|
| SHA | `a187a17a3ac8670df9d4d6ad7b722024834e818e` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 13:50:19 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitiveInfoTypeTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitivityLabelTemplate.ps1`

---

### 25. `96727eb4` — fixes to purview setup

| Field | Value |
|-------|-------|
| SHA | `96727eb4922a5eb3277b44a81b3f8f57a52fbaa3` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 14:49:13 +0200 |
| Files changed | 14 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/standards.json`, `Modules/CIPPCore/Public/Format-CIPPCompliancePolicyParams.ps1`, `Modules/CIPPCore/Public/New-CIPPSitRulePackXml.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-DLP/Invoke-AddDlpCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-DLP/Invoke-AddDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-Retention/Invoke-AddRetentionCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-Retention/Invoke-AddRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SIT/Invoke-AddSensitiveInfoType.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SensitivityLabel/Invoke-AddSensitivityLabel.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SensitivityLabel/Invoke-AddSensitivityLabelTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitiveInfoTypeTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitivityLabelTemplate.ps1`

---

### 26. `ec7f5649` — Single deployment from function now that its all rigged up

| Field | Value |
|-------|-------|
| SHA | `ec7f5649f70b0df55c21da4580b23aa636960719` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 22:12:56 +0200 |
| Files changed | 12 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/ConvertTo-CIPPComplianceSetParams.ps1`, `Modules/CIPPCore/Public/Set-CIPPDlpCompliancePolicy.ps1`, `Modules/CIPPCore/Public/Set-CIPPRetentionCompliancePolicy.ps1`, `Modules/CIPPCore/Public/Set-CIPPSensitiveInfoType.ps1`, `Modules/CIPPCore/Public/Set-CIPPSensitivityLabel.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-DLP/Invoke-AddDlpCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-Retention/Invoke-AddRetentionCompliancePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SIT/Invoke-AddSensitiveInfoType.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Compliance-SensitivityLabel/Invoke-AddSensitivityLabel.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDlpCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardRetentionCompliancePolicyTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitivityLabelTemplate.ps1`

---

### 27. `61c938aa` — standards use function

| Field | Value |
|-------|-------|
| SHA | `61c938aabf2ddf5d6718647f2ddc721d42ecab61` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 22:14:32 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitiveInfoTypeTemplate.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSensitivityLabelTemplate.ps1`

---

### 28. `be25c764` — Squashed commit of the following:

| Field | Value |
|-------|-------|
| SHA | `be25c76405478de24fc6018cb187375d9b1ab873` |
| Author | James Tarran |
| Date | 2026-05-11 14:48:10 +0100 |
| Files changed | 903 |
| Risk | **High** |
| Area | Docs |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal, Tenant Workflows, Permissions/Roles/Auth, Custom API Endpoints, Standards/Alignment Custom; Buckets: Documentation-only, Potentially breaking changes |

**Files:** `.github/instructions/auth-model.instructions.md`, `.github/instructions/cippdb.instructions.md`, `.github/workflows/PR_Branch_Check.yml`, `.github/workflows/publish_release.yml`, `.github/workflows/upload_dev.yml`, `.gitignore`, `Config/CIPPDBCacheTypes.json`, `Config/CIPPTimers.json`, `Config/CommunityRepos.json`, `Config/SAMManifest.json`, `Config/TemplateEmail.html`, `Config/cipp-roles.json`, `Config/intuneCollection.json`, `Config/standards.json`, `Config/version_latest.txt` … (+888 more)

---

### 29. `6aa66c74` — Custom Test - Alert on X statuses

| Field | Value |
|-------|-------|
| SHA | `6aa66c744b8c755f48b75044ca5c876e9e2c90e3` |
| Author | Zacgoose |
| Date | 2026-05-11 21:49:47 +0800 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tools/Custom-Scripts/Invoke-AddCustomScript.ps1`, `Modules/CIPPTests/Public/Tests/Custom/Invoke-CippTestCustomScripts.ps1`

---

### 30. `dc3f0f45` — Merge branch 'dev' into Feat-Conditional-access-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `dc3f0f458131bfc256b3ab938aeeadc8cf4d4e6f` |
| Author | James Tarran |
| Date | 2026-05-11 14:55:06 +0100 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 31. `dad97f7c` — Restore Invoke-AddCustomScript.ps1

| Field | Value |
|-------|-------|
| SHA | `dad97f7c19da50facd311f1a225699621010be64` |
| Author | James Tarran |
| Date | 2026-05-11 14:59:06 +0100 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tools/Custom-Scripts/Invoke-AddCustomScript.ps1`

---

### 32. `6a96bab8` — Update Invoke-ListLicenses.ps1

| Field | Value |
|-------|-------|
| SHA | `6a96bab87febde97fd8abd188f35cc8850bc6ef7` |
| Author | Zacgoose |
| Date | 2026-05-11 23:14:58 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Reports/Invoke-ListLicenses.ps1`

---

### 33. `f87f7da9` — implemenets #5948

| Field | Value |
|-------|-------|
| SHA | `f87f7da97aeb2dc21b45647151fa2d62ca9366de` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 19:58:56 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-AddOfficeApp.ps1`

---

### 34. `61bac43f` — Greatly speed up listing of intune policies for alltenants

| Field | Value |
|-------|-------|
| SHA | `61bac43f6551f1af488b8372dffd04718bc39b86` |
| Author | Zacgoose |
| Date | 2026-05-12 02:03:13 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPDbItem.ps1`, `Modules/CIPPCore/Public/Get-CIPPIntunePolicyReport.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecRemoveMailboxRule.ps1`

---

### 35. `377b83e6` — HVE user management and cache

| Field | Value |
|-------|-------|
| SHA | `377b83e68241023ee4440b0836fdd86600abcf1a` |
| Author | Zacgoose |
| Date | 2026-05-12 02:05:12 +0800 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/CIPPDBCacheTypes.json`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheHVEAccounts.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecHVEUser.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListHVEAccounts.ps1`

---

### 36. `c29746a1` — eclusions everywhere

| Field | Value |
|-------|-------|
| SHA | `c29746a16c2cf84b7908f94039c70317aaaf1988` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:13:43 +0200 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Applications/Push-UploadApplication.ps1`, `Modules/CIPPCore/Public/Set-CIPPAssignedApplication.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-AddOfficeApp.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-ExecAssignApp.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDeployCheckChromeExtension.ps1`

---

### 37. `2753661e` — implements #5986

| Field | Value |
|-------|-------|
| SHA | `2753661e99deccb851c92738a9e54b1d416514fe` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:43:04 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-EditTenantAllowBlockListTemplate.ps1`

---

### 38. `5f3b26e5` — tablecleanup update

| Field | Value |
|-------|-------|
| SHA | `5f3b26e5a5192fb34757d5518f53a0dc1ff8b450` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:02:00 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-TableCleanup.ps1`

---

### 39. `1aa55cff` — fix: intune standard change detection queries

| Field | Value |
|-------|-------|
| SHA | `1aa55cffb7ad70e9a11a4b2e70f8feeb80e775fe` |
| Author | John Duprey |
| Date | 2026-05-11 15:02:46 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Standards/Push-CIPPStandardsList.ps1`

---

### 40. `0c045c72` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `0c045c7272f56be6bb812a38580a521ff8a2696c` |
| Author | John Duprey |
| Date | 2026-05-11 15:02:53 -0400 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 41. `ee0b8229` — fix: change cleanup to 30 days

| Field | Value |
|-------|-------|
| SHA | `ee0b82294a849bf992ec3ff7ce09b517f4e17fba` |
| Author | John Duprey |
| Date | 2026-05-11 15:05:40 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-TableCleanup.ps1`

---

### 42. `b6c2a436` — Feat: Add support for AllTenants in Intune pages (#2021)

| Field | Value |
|-------|-------|
| SHA | `b6c2a4360917ecd1150da3ea9a643749319748ed` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:12:56 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 43. `dd413bfe` — Add AAD Premium license gate to ExternalMFATrusted standard (#2046)

| Field | Value |
|-------|-------|
| SHA | `dd413bfe119e48b011f65ddcc377e250decd93d4` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:14:06 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 44. `d8be4455` — Merge branch 'dev' into levenshtein-distance

| Field | Value |
|-------|-------|
| SHA | `d8be4455b25bb488529e62bceee689ff6ea30a58` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:20:31 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 45. `59da6e6b` — Merge branch 'dev' into testlicense-presets

| Field | Value |
|-------|-------|
| SHA | `59da6e6b312467bce245585d321fd0ce6cc64546` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:21:21 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** (none)

---

### 46. `fdf313e5` — fix: remove partitionkey

| Field | Value |
|-------|-------|
| SHA | `fdf313e5cfb08b2da7bba256201daf2de9ba15ff` |
| Author | John Duprey |
| Date | 2026-05-11 15:23:32 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-TableCleanup.ps1`

---

### 47. `b0232eca` — Feat conditional access policy package tags (#1979)

| Field | Value |
|-------|-------|
| SHA | `b0232eca376e913a1c8705a6a53cccb4b4fa20a4` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:28:49 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 48. `75699ff1` — feat: Add fuzzy matching for Intune policies using Levenshtein distance (#1945)

| Field | Value |
|-------|-------|
| SHA | `75699ff1b967bd314ed0e9c06cf219ebcbb19dcc` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:33:25 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 49. `d996babb` — Merge branch 'dev' of https://github.com/kris6673/CIPP-API into alltenants-SP

| Field | Value |
|-------|-------|
| SHA | `d996babb5590423e7b48116a809df541ee6ec01e` |
| Author | Bobby |
| Date | 2026-05-11 21:26:15 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 50. `ddf0a4c6` — feat: Add allTenants support for Teams SharePoint pages (#2022)

| Field | Value |
|-------|-------|
| SHA | `ddf0a4c628b9172be770066bfe3d0a9d0e5afe76` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:37:30 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 51. `0c633110` — fix: fix my cleanup mistake

| Field | Value |
|-------|-------|
| SHA | `0c6331101751d4d598a6796c58b32743c77fff29` |
| Author | Bobby |
| Date | 2026-05-11 21:46:45 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPSitesReport.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSites.ps1`

---

### 52. `affac9d0` — Fix/standards run errors (#2037)

| Field | Value |
|-------|-------|
| SHA | `affac9d0978c5e30b3da8b6b852fcf1d1f23b5bd` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:47:38 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 53. `12bb4f69` — Fix: Fix cleanup mistake in caching functions (#2048)

| Field | Value |
|-------|-------|
| SHA | `12bb4f69566a2a81aeddafcaffdbf02eec0b5cee` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:48:16 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 54. `5995ad77` — Merge branch 'dev' into testlicense-presets

| Field | Value |
|-------|-------|
| SHA | `5995ad7778c9e0f6a4e9e350302b06f6306aa1b9` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:51:47 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** (none)

---

### 55. `21526416` — fix: add the presets to the rest of the standards

| Field | Value |
|-------|-------|
| SHA | `2152641640709ecfe211f3c38752edad0d3f5f13` |
| Author | Bobby |
| Date | 2026-05-11 22:01:50 +0200 |
| Files changed | 11 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneAppProtectionPolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneApplications.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneAssignmentFilters.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneCompliancePolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneReusableSettings.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheIntuneScripts.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAutoAddProxy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardEmptyFilterIPAllowList.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardEnforcePrivateGroups.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardExternalMFATrusted.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardTeamsZAP.ps1`

---

### 56. `bc4abb53` — feat: add DefenderForOffice365 preset to license tests

| Field | Value |
|-------|-------|
| SHA | `bc4abb53441d530ef84896da8f2a8414b744840c` |
| Author | Bobby |
| Date | 2026-05-11 22:23:28 +0200 |
| Files changed | 6 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Functions/Test-CIPPStandardLicense.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoPresetSecurityPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAtpPolicyForO365.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeAttachmentPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeLinksPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSafeLinksTemplatePolicy.ps1`

---

### 57. `f5702f41` — feat: Enhance Invoke-ListIntuneTemplates to include usage tracking for standards templates

| Field | Value |
|-------|-------|
| SHA | `f5702f41f1fa33ab7cfa8be9989c913d88d7d880` |
| Author | John Duprey |
| Date | 2026-05-11 23:57:27 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntuneTemplates.ps1`

---

### 58. `ecbc9a50` — fix: Add error handling for missing standard functions in Push-CIPPStandard

| Field | Value |
|-------|-------|
| SHA | `ecbc9a50ac0584e0d0ce59259214ebe6d9cf525a` |
| Author | John Duprey |
| Date | 2026-05-11 23:58:56 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Standards/Push-CIPPStandard.ps1`

---

### 59. `57b7de1f` — fix: Rename 'usedInTemplates' property to 'usage' for clarity in Invoke-ListIntuneTemplates

| Field | Value |
|-------|-------|
| SHA | `57b7de1f31bcffa3ebc3ba1f05d5d47fa1b6bffe` |
| Author | John Duprey |
| Date | 2026-05-12 00:07:30 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntuneTemplates.ps1`

---

### 60. `7fd7d097` — fixes sharepoint response stuff

| Field | Value |
|-------|-------|
| SHA | `7fd7d097882ad258695905e15c19addd288d493c` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 14:28:11 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSharePointSiteUsage.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ListSites.ps1`

---

### 61. `23c8994d` — fixes defaultr_hidden vs hidden #5990

| Field | Value |
|-------|-------|
| SHA | `23c8994da9a523a6fbce594181f0c74e5fb1a69e` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 14:33:28 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDeployCheckChromeExtension.ps1`

---

### 62. `ad0d096c` — OneDrive Sharing disable

| Field | Value |
|-------|-------|
| SHA | `ad0d096c727ec2b881f0ea8a4e5ff33a8950f0a8` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 16:03:49 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Invoke-CIPPOffboardingJob.ps1`, `Modules/CIPPCore/Public/Set-CIPPOneDriveSharing.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Users/Invoke-ExecBECRemediate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ExecSetOneDriveSharing.ps1`

---

### 63. `2869564f` — Add AlertUserReportPhising

| Field | Value |
|-------|-------|
| SHA | `2869564fb904deced3eb5c076f19519db12c3769` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 16:32:19 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/SAMManifest.json`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertUserReportedPhishing.ps1`

---

### 64. `ddb498fe` — chore: bump version to 10.4.5

| Field | Value |
|-------|-------|
| SHA | `ddb498fe81df0262aa834db9617ed08dad38aeed` |
| Author | John Duprey |
| Date | 2026-05-12 11:32:15 -0400 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `host.json`, `version_latest.txt`

---

### 65. `35437558` — Update Viva standard

| Field | Value |
|-------|-------|
| SHA | `35437558e4699479e303f4245fe14d3e258cdba2` |
| Author | Zacgoose |
| Date | 2026-05-12 23:39:36 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDisableViva.ps1`

---

### 66. `5f864e3f` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `5f864e3ff517b8e292ce0d7bb7d6080ea297c2cf` |
| Author | Zacgoose |
| Date | 2026-05-12 23:39:38 +0800 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 67. `78193020` — fix name

| Field | Value |
|-------|-------|
| SHA | `781930205c67fc17a5ca887755361987a407012a` |
| Author | John Duprey |
| Date | 2026-05-12 12:20:47 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-OrchestratorBatchItems.ps1`

---

### 68. `785e71c5` — fix user select

| Field | Value |
|-------|-------|
| SHA | `785e71c530a39b46f56cea7c598f7d609d8a8518` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 18:26:46 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Set-CIPPDefaultAPDeploymentProfile.ps1`

---

### 69. `6a81a086` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `6a81a086d4b109ae6d59dc73b6b47308091e5f64` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 18:26:48 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 70. `2c5d0c9a` — feat: Add license capability presets (#2040)

| Field | Value |
|-------|-------|
| SHA | `2c5d0c9a9c3df6447e8ae17f17aa929c7457fb82` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 20:24:52 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 71. `2dbc4803` — auth configs

| Field | Value |
|-------|-------|
| SHA | `2dbc480336773976fb1140194c4c5de348afe170` |
| Author | Zacgoose |
| Date | 2026-05-13 04:19:45 +0800 |
| Files changed | 15 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Config/FeatureFlags.json`, `Modules/CIPPCore/Public/Authentication/Get-CippApiAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Initialize-CIPPAuth.ps1`, `Modules/CIPPCore/Public/Authentication/New-CIPPSSOApp.ps1`, `Modules/CIPPCore/Public/Authentication/Remove-CIPPMigrationAppSetting.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CIPPSSOEasyAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`, `Modules/CIPPCore/Public/Authentication/Update-CIPPSSORedirectUri.ps1`, `Modules/CIPPCore/Public/GraphHelper/Update-AppManagementPolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListFeatureFlags.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecCIPPUsers.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecContainerManagement.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListCIPPUsers.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecSSOSetup.ps1`

---

### 72. `3adade45` — Featureflag configs and timer changes

| Field | Value |
|-------|-------|
| SHA | `3adade45c14529810607f8a251d56a9c2c0ac44b` |
| Author | Zacgoose |
| Date | 2026-05-13 14:21:10 +0800 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/CIPPTimers.json`, `Config/FeatureFlags.json`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-ContainerUpdateCheck.ps1`, `Modules/CIPPCore/Public/Get-CIPPFeatureFlag.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecContainerManagement.ps1`

---

### 73. `93c80812` — skip replacement if not value set for variable

| Field | Value |
|-------|-------|
| SHA | `93c80812f29762f375ed0ea28b03e59f8d956017` |
| Author | Zacgoose |
| Date | 2026-05-13 15:52:56 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPTextReplacement.ps1`

---

### 74. `2d33e020` — strip return characters

| Field | Value |
|-------|-------|
| SHA | `2d33e020ee90330209b90a1538b419c3a71ab4c2` |
| Author | Zacgoose |
| Date | 2026-05-13 16:47:18 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPAlertTemplate.ps1`

---

### 75. `d480cf74` — Add Apps and SP to universal search

| Field | Value |
|-------|-------|
| SHA | `d480cf74f7bea7180136c74d1e351b4b93b7d06a` |
| Author | Zacgoose |
| Date | 2026-05-13 17:06:47 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Search-CIPPDbData.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ExecUniversalSearchV2.ps1`

---

### 76. `9011dd63` — Nice CA policy editor and template creator/editor

| Field | Value |
|-------|-------|
| SHA | `9011dd63e2a4ac6aef393aab54893b791e06caa0` |
| Author | Zacgoose |
| Date | 2026-05-13 18:53:59 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Conditional/Invoke-ExecCreateCATemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Conditional/Invoke-ExecEditCAPolicyFull.ps1`

---

### 77. `897dfaa4` — fixed #5997

| Field | Value |
|-------|-------|
| SHA | `897dfaa4f07443e0f05f8f2aefa5b0a92fc91a9c` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 21:18:48 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSpamFilterPolicy.ps1`

---

### 78. `b1363008` — #5997

| Field | Value |
|-------|-------|
| SHA | `b1363008db683132524711ec2932afe9a12f0342` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 21:19:03 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSpamFilterPolicy.ps1`

---

### 79. `e060fa22` — implements #5981

| Field | Value |
|-------|-------|
| SHA | `e060fa22b10156d59bed43c7b22f965a768379e5` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 21:47:17 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPCAPolicy.ps1`, `Modules/CIPPCore/Public/New-CIPPCATemplate.ps1`

---

### 80. `f5f7ae70` — fixes duplicate test calls in some cases

| Field | Value |
|-------|-------|
| SHA | `f5f7ae7064404c314d6cd5694ee1260d1e543c0f` |
| Author | Zacgoose |
| Date | 2026-05-14 15:09:35 +1000 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Add-CIPPAzDataTableEntity.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPTestCollection.ps1`

---

### 81. `c097631e` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `c097631e9c9a30468a858e222256894c9a95122c` |
| Author | Zacgoose |
| Date | 2026-05-14 15:09:50 +1000 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 82. `b4a52152` — Fix tenant group scope cache

| Field | Value |
|-------|-------|
| SHA | `b4a5215251751201733eb04fda5a464e462b88d8` |
| Author | Zacgoose |
| Date | 2026-05-14 15:37:16 +1000 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/FeatureFlags.json`, `Modules/CIPPCore/Public/TenantGroups/Get-TenantGroups.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListContainerLogs.ps1`

---

### 83. `dbd7fcb3` — logging improvements

| Field | Value |
|-------|-------|
| SHA | `dbd7fcb3486342ae02f5cc914343052a7bdec645` |
| Author | Zacgoose |
| Date | 2026-05-14 18:09:21 +1000 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListContainerLogs.ps1`

---

### 84. `bc7de0c1` — when running a standard manually still process all standards for precedence overrides

| Field | Value |
|-------|-------|
| SHA | `bc7de0c1a41134baa87c8d45ee2f13fb8d96b979` |
| Author | Zacgoose |
| Date | 2026-05-14 18:09:59 +1000 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Standards/Get-CIPPStandards.ps1`

---

### 85. `ee0398db` — feat(endpoint): add Apple ADE and Android enrollment profile listing and deletion endpoints

| Field | Value |
|-------|-------|
| SHA | `ee0398db8fb1dc0f3e068d57044486d90b03c992` |
| Author | Bobby |
| Date | 2026-05-14 11:28:32 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ExecRemoveEnrollmentProfile.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAndroidEnrollmentProfiles.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAppleEnrollmentProfiles.ps1`, `cspell.json`

---

### 86. `5ccf15a9` — fix: missing odata path error in the returned json

| Field | Value |
|-------|-------|
| SHA | `5ccf15a9197c67cb8fdde40606dd7b26a476ae1a` |
| Author | Bobby |
| Date | 2026-05-14 20:23:40 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntunePolicy.ps1`

---

### 87. `5901014f` — Merge pull request #100 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `5901014f4622cc7a47a923716a2974df1f8e0923` |
| Author | Integrated Solutions |
| Date | 2026-05-15 11:39:46 +1000 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 88. `5289a309` — feat: ability to add/remove nested groups in group memberships

| Field | Value |
|-------|-------|
| SHA | `5289a3092d34df70035ab12a2cc70daabeb2e77f` |
| Author | Integrated Solutions |
| Date | 2026-05-15 15:57:00 +1000 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListUsersAndGroups.ps1`

---

### 89. `7ae35c2b` — post exec tweaks for dedupe queue names

| Field | Value |
|-------|-------|
| SHA | `7ae35c2bd5c8f11169722651e69c18224dc8fde8` |
| Author | Zacgoose |
| Date | 2026-05-15 02:28:44 -0500 |
| Files changed | 6 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Config/FeatureFlags.json`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-CIPPDBCacheApplyBatch.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Tests/Push-CIPPTestsApplyBatch.ps1`, `Modules/CIPPCore/Public/Entrypoints/Orchestrator Functions/Start-CIPPDBTestsRun.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListWorkerHealth.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ExecTestRun.ps1`

---

### 90. `fd6e30f6` — fix(standards): target azureADRegistration in intuneRestrictUserDeviceRegistration

| Field | Value |
|-------|-------|
| SHA | `fd6e30f62fb209f2b706b359bd1b91f5ef368081` |
| Author | Bobby |
| Date | 2026-05-15 20:29:45 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceRegistration.ps1`

---

### 91. `c67bc8dd` — feat(standards): add intuneRestrictUserDeviceJoin standard

| Field | Value |
|-------|-------|
| SHA | `c67bc8dd9b892ebfaeaf80a9037941d46d53d745` |
| Author | Bobby |
| Date | 2026-05-15 20:29:46 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardintuneRestrictUserDeviceJoin.ps1`

---

### 92. `90b6457d` — Add AutoExpandingArchiveScope property showing org-level vs mailbox-level enablement

| Field | Value |
|-------|-------|
| SHA | `90b6457d590ea6f6b96c62e8e0315ccd1f56f640` |
| Author | Zacgoose |
| Date | 2026-05-18 07:16:57 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Users/Invoke-ListUserMailboxDetails.ps1`

---

### 93. `ab83a2bb` — Update Update-CIPPSAMRedirectUri.ps1

| Field | Value |
|-------|-------|
| SHA | `ab83a2bb5dbcfba32770827466b17a882398898d` |
| Author | Zacgoose |
| Date | 2026-05-18 07:56:08 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Update-CIPPSAMRedirectUri.ps1`

---

### 94. `d7cda8a3` — Update Initialize-CIPPAuth.ps1

| Field | Value |
|-------|-------|
| SHA | `d7cda8a309a9c133e98de54257482bb4ef399abc` |
| Author | Zacgoose |
| Date | 2026-05-18 07:57:41 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Initialize-CIPPAuth.ps1`

---

### 95. `ab5e5155` — Switch to app auth for authentication changes standard

| Field | Value |
|-------|-------|
| SHA | `ab5e5155681acb8e14994a80fd287a17f1aa3544` |
| Author | Zacgoose |
| Date | 2026-05-18 09:24:48 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Set-CIPPAuthenticationPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardPWdisplayAppInformationRequiredState.ps1`

---

### 96. `1b1ee689` — cache PowerShell enabled status and use cached data for standard

| Field | Value |
|-------|-------|
| SHA | `1b1ee689e9442896d9767f1cba736d6aa8b5d56f` |
| Author | Zacgoose |
| Date | 2026-05-19 07:20:16 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheMailboxes.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDisableExchangeOnlinePowerShell.ps1`

---

### 97. `6b8ebd48` — refactor calls to use new onepass method to store DB data

| Field | Value |
|-------|-------|
| SHA | `6b8ebd4814625fa4902844dca619cb6deb1720eb` |
| Author | Zacgoose |
| Date | 2026-05-19 07:40:37 -0400 |
| Files changed | 86 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal, Tenant Workflows, Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheAdminConsentRequestPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheAppRoleAssignments.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheApps.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheAuthenticationFlowsPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheAuthenticationMethodsPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheAuthorizationPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheB2BManagementPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheBitlockerKeys.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheConditionalAccessPolicies.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCopilotReadinessActivity.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCopilotUsageUserDetail.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCopilotUserCountSummary.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCopilotUserCountTrend.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCredentialUserRegistrationDetails.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheCrossTenantAccessPolicy.ps1` … (+71 more)

---

### 98. `e3e82cd9` — Cache Security Defaults

| Field | Value |
|-------|-------|
| SHA | `e3e82cd95b9597706f1edc3ccde5776695abe820` |
| Author | Zacgoose |
| Date | 2026-05-19 07:51:16 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPCAPolicy.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheConditionalAccessPolicies.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardConditionalAccessTemplate.ps1`

---

### 99. `9ba48711` — correct incorrect default value

| Field | Value |
|-------|-------|
| SHA | `9ba48711c614be8e2452ffff2e539b5b1a11b534` |
| Author | Zacgoose |
| Date | 2026-05-19 10:01:24 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/standards.json`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardIntuneComplianceSettings.ps1`

---

### 100. `73f83719` — add logging to geoip lookip

| Field | Value |
|-------|-------|
| SHA | `73f83719d8d6123db9e450248f55dc97acfdc0ea` |
| Author | Zacgoose |
| Date | 2026-05-19 10:01:41 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPGeoIPLocation.ps1`

---

### 101. `9fce7e77` — feat: add in missing options for Windows Hello standard

| Field | Value |
|-------|-------|
| SHA | `9fce7e77b7d7cf29692fa3aa869a373e076f7658` |
| Author | Bobby |
| Date | 2026-05-20 22:10:20 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardEnrollmentWindowsHelloForBusinessConfiguration.ps1`

---

### 102. `1e02bfcb` — feat(standards): add DLP via DCS standard

| Field | Value |
|-------|-------|
| SHA | `1e02bfcb198406e9caa408acad12d79c7646ce6f` |
| Author | Bobby |
| Date | 2026-05-20 23:42:04 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDlpViaDcsEnabled.ps1`

---

### 103. `cfa144d6` — Update Invoke-ListWorkerHealth.ps1

| Field | Value |
|-------|-------|
| SHA | `cfa144d6b00b6641720c18bde34537227965a7fd` |
| Author | Zacgoose |
| Date | 2026-05-22 12:51:10 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListWorkerHealth.ps1`

---

### 104. `a89c2b93` — Add Group-Based Licensing support

| Field | Value |
|-------|-------|
| SHA | `a89c2b9333ba7a1bca50fda53145894835de8f80` |
| Author | Luis Mengel |
| Date | 2026-05-23 15:20:47 +0200 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPGroup.ps1`, `Modules/CIPPCore/Public/Remove-CIPPGroup.ps1`, `Modules/CIPPCore/Public/Set-CIPPGroupLicense.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Groups/Invoke-AddGroupTemplate.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Groups/Invoke-EditGroup.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Groups/Invoke-ListGroupTemplates.ps1`

---

### 105. `bb2ebc6a` — fix: Add missing options for Windows Hello standard (#2061)

| Field | Value |
|-------|-------|
| SHA | `bb2ebc6a76533e893d88fd024b7f73529cc764a0` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:41:12 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 106. `7fbb8edf` — Feat: Split Intune device join and registration standards (#2057)

| Field | Value |
|-------|-------|
| SHA | `7fbb8edfed242ac6c80d7e684102df20bc6bce02` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:42:43 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** (none)

---

### 107. `77a4be64` — fixes #6027

| Field | Value |
|-------|-------|
| SHA | `77a4be6499e8e93d41a932983f03799275071893` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 18:10:15 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecTenantGroup.ps1`

---

### 108. `4ab85c75` — CIPP Hosted Notices

| Field | Value |
|-------|-------|
| SHA | `4ab85c751fe6aad0c93d41ce43eb1e7755ae12c4` |
| Author | Zacgoose |
| Date | 2026-05-24 09:13:56 +1000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/New-CippCoreRequest.ps1`

---

### 109. `dcf382aa` — Update Build-DevApiModules.ps1

| Field | Value |
|-------|-------|
| SHA | `dcf382aaa03539256b17454a49371ac7fda6485e` |
| Author | Zacgoose |
| Date | 2026-05-24 09:33:25 +1000 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Build-DevApiModules.ps1`

---

### 110. `9bb2f6bc` — Update Build-DevApiModules.ps1

| Field | Value |
|-------|-------|
| SHA | `9bb2f6bc962c1fbb89801b6e50295407672ca829` |
| Author | Zacgoose |
| Date | 2026-05-24 09:38:26 +1000 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Build-DevApiModules.ps1`

---

### 111. `fa5f4de6` — remove sso setup from featureflag

| Field | Value |
|-------|-------|
| SHA | `fa5f4de6f54e7efc2473687e705d5b6caf20b1aa` |
| Author | John Duprey |
| Date | 2026-05-24 14:46:53 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Settings |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `Config/FeatureFlags.json`

---

### 112. `df847779` — implement standards template deployment for intune apps

| Field | Value |
|-------|-------|
| SHA | `df8477792bb4970416689b732c43a95e3537be7b` |
| Author | KelvinTegelaar |
| Date | 2026-05-24 22:41:08 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Applications/Push-UploadApplication.ps1`, `Modules/CIPPCore/Public/New-CIPPIntuneAppDeployment.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardIntuneAppTemplateDeploy.ps1`

---

### 113. `08ab039c` — add filtering

| Field | Value |
|-------|-------|
| SHA | `08ab039ccdaa149d3c0698d1dba627acd668ee58` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 00:22:59 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertAppCertificateExpiry.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertAppSecretExpiry.ps1`

---

### 114. `c81b6a5c` — add filtering

| Field | Value |
|-------|-------|
| SHA | `c81b6a5c57a49d9dfec2728706fb7cc2098d5dfa` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 00:23:02 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertAppCertificateExpiry.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertAppSecretExpiry.ps1`

---

### 115. `33512c39` — FIDO2 profile standards

| Field | Value |
|-------|-------|
| SHA | `33512c39360bd618749adf423d132b764e62db1f` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 01:34:04 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardFIDO2PasskeyProfiles.ps1`

---

### 116. `03abdad4` — add global var showing

| Field | Value |
|-------|-------|
| SHA | `03abdad414c58c3a3502068465c1ff6441fcc140` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 01:58:21 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecCippReplacemap.ps1`

---

### 117. `f09ce56a` — Update New-TeamsRequest.ps1

| Field | Value |
|-------|-------|
| SHA | `f09ce56acc6efba45ee1cb0b9dcbcf43c1224ac5` |
| Author | Zacgoose |
| Date | 2026-05-25 11:58:16 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/GraphHelper/New-TeamsRequest.ps1`

---

### 118. `a0dab59a` — domain fixes

| Field | Value |
|-------|-------|
| SHA | `a0dab59a9091949721e42bd2f4c8cf78acc927cc` |
| Author | Zacgoose |
| Date | 2026-05-25 14:35:20 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Domain Analyser/Push-DomainAnalyserTenant.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Domain Analyser/Push-GetTenantDomains.ps1`

---

### 119. `08b972cc` — timezone changes

| Field | Value |
|-------|-------|
| SHA | `08b972ccac96794551db5c6dca9c2135914144e3` |
| Author | Zacgoose |
| Date | 2026-05-25 15:33:49 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Initialize-CIPPTimezone.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecTimeSettings.ps1`

---

### 120. `d854e22d` — feat: add function to remove users from admin roles

| Field | Value |
|-------|-------|
| SHA | `d854e22d853449c8f45b44ed31c5e385508aba55` |
| Author | Bobby |
| Date | 2026-05-25 11:49:28 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Users/Invoke-ExecRemoveAdminRole.ps1`

---

### 121. `cb31997c` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `cb31997c9c07694c84a072d49b6910db20e80c07` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 12:24:15 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 122. `46015ce7` — Add APv2 profile

| Field | Value |
|-------|-------|
| SHA | `46015ce7394fb954d357f8ebf26ef77a827626ad` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:29:29 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDevicePrepProfile.ps1`

---

### 123. `05ce60f3` — Feat: Add function to remove users from admin roles (#2064)

| Field | Value |
|-------|-------|
| SHA | `05ce60f365de65170d3aa37ca2287b94678361b5` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:31:38 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** (none)

---

### 124. `a7e30d7a` — feat: Add DLP via DCS standard (#2062)

| Field | Value |
|-------|-------|
| SHA | `a7e30d7a7f63662b40e3daad87d6de971fc7fbfc` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:32:45 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 125. `4214bc7d` — Fix: Fix missing OData path error in JSON response (#2054)

| Field | Value |
|-------|-------|
| SHA | `4214bc7de39c563d0979b2717239e9acda4752e7` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:34:33 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 126. `a7b7d4da` — feat: Add Apple ADE and Android enrollment profile endpoints (#2053)

| Field | Value |
|-------|-------|
| SHA | `a7b7d4daeca7b247fa017d722b29e019f0d8f885` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:35:47 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** (none)

---

### 127. `443e16a3` — feat: ability to add/remove nested groups in group memberships (#2056)

| Field | Value |
|-------|-------|
| SHA | `443e16a34e7b0c72cc513000b69b852987b8fe04` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 22:43:43 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 128. `71afcdd2` — ExoTransportConfig cache type - fix for missing data used in test suites

| Field | Value |
|-------|-------|
| SHA | `71afcdd2be483a31473fcadaf239888671548787` |
| Author | Zacgoose |
| Date | 2026-05-26 11:54:49 +0800 |
| Files changed | 6 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Config/CIPPDBCacheTypes.json`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoTransportConfig.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDisableBasicAuthSMTP.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardMessageExpiration.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_6_5_4.ps1`

---

### 129. `1e63ebf0` — Update Invoke-CIPPStandardsharingDomainRestriction.ps1

| Field | Value |
|-------|-------|
| SHA | `1e63ebf0fc6b61a4873d4eb2f4f1b389f034676a` |
| Author | Zacgoose |
| Date | 2026-05-26 15:09:22 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardsharingDomainRestriction.ps1`

---

### 130. `59a0e15d` — update application content type handling

| Field | Value |
|-------|-------|
| SHA | `59a0e15d1c11b1c8c33e0d04f3f6cd9dd96e23b0` |
| Author | Zacgoose |
| Date | 2026-05-26 15:12:33 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Shared/CIPPSharp/CIPPRestClient.cs`, `Shared/CIPPSharp/bin/CIPPSharp.dll`

---

### 131. `e6b800b1` — remove rerun from alert

| Field | Value |
|-------|-------|
| SHA | `e6b800b1c93bd1236bef7c6aacd194f4de8289f7` |
| Author | Zacgoose |
| Date | 2026-05-26 15:34:21 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertQuarantineReleaseRequests.ps1`

---

### 132. `97dc672c` — user sync

| Field | Value |
|-------|-------|
| SHA | `97dc672c748a5152c5a7438588f6ab6847b4ac26` |
| Author | Zacgoose |
| Date | 2026-05-26 23:33:37 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/CIPPTimers.json`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-UserSyncTimer.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecCIPPUsers.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListCIPPUsers.ps1`

---

### 133. `359633a4` — fix: ensure tenant groups skips cache so they dont alternate anymore when refreshed

| Field | Value |
|-------|-------|
| SHA | `359633a42f5c208fd3b7e85f5903833e96e9c1c4` |
| Author | Bobby |
| Date | 2026-05-26 17:58:54 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Tenant/Invoke-ListTenantDetails.ps1`

---

### 134. `49d629e5` — Update Get-CippApiAuth.ps1

| Field | Value |
|-------|-------|
| SHA | `49d629e51778c237f1e5fb4580493e32eb93937c` |
| Author | Zacgoose |
| Date | 2026-05-27 00:31:43 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Get-CippApiAuth.ps1`

---

### 135. `22902b0b` — api fixes

| Field | Value |
|-------|-------|
| SHA | `22902b0b81b33f8785715fd37ad176e60afade3b` |
| Author | Zacgoose |
| Date | 2026-05-27 01:51:03 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/New-CIPPAPIConfig.ps1`, `Modules/CIPPCore/Public/Authentication/Repair-CippApiIdentifierUri.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`

---

### 136. `5561a5b1` — Fix: tenant groups cache issue (#2065)

| Field | Value |
|-------|-------|
| SHA | `5561a5b1363311d67761ec65644a23476d5ceb41` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 01:09:31 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 137. `95d48d1f` — Fix for desktop activations copilot ready test

| Field | Value |
|-------|-------|
| SHA | `95d48d1fe90a2e57c7459afa1330290ef659ff02` |
| Author | Zacgoose |
| Date | 2026-05-27 13:58:17 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/CopilotReadiness/Identity/Invoke-CippTestCopilotReady003.ps1`

---

### 138. `a6fdfe23` — Make all tenants list for SPO sites fast

| Field | Value |
|-------|-------|
| SHA | `a6fdfe23eb387354bb0c1bd461e8d807e06dcee5` |
| Author | Zacgoose |
| Date | 2026-05-27 13:59:27 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPSharePointSiteUsageReport.ps1`

---

### 139. `122aec8f` — fix for template id casing

| Field | Value |
|-------|-------|
| SHA | `122aec8f757ac9e96e515b19cd5965c7d8f3e5d3` |
| Author | Zacgoose |
| Date | 2026-05-27 15:00:16 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Standards/Invoke-ExecStandardsRun.ps1`

---

### 140. `7d3b480e` — Update Invoke-CIPPStandardDefenderCompliancePolicy.ps1

| Field | Value |
|-------|-------|
| SHA | `7d3b480edb21d46cea9ae0d21196eab2c670b358` |
| Author | Zacgoose |
| Date | 2026-05-27 16:29:11 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDefenderCompliancePolicy.ps1`

---

### 141. `49153019` — use top 500 to minimise requests

| Field | Value |
|-------|-------|
| SHA | `491530194c73d6fea5256666d3b46a93ce83a74c` |
| Author | Zacgoose |
| Date | 2026-05-27 16:41:48 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertNewRiskyUsers.ps1`

---

### 142. `c5b0e592` — smart lockout standard

| Field | Value |
|-------|-------|
| SHA | `c5b0e59221366cb68a8233590fbc38ee3e5321c6` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 14:23:59 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSmartLockout.ps1`

---

### 143. `c5a8a207` — smart lockout standard

| Field | Value |
|-------|-------|
| SHA | `c5a8a20739f1cc1265dbb6f0d8cf399e63df51b4` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 14:24:02 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSmartLockout.ps1`

---

### 144. `f85963b7` — Sharepoint management functionality.

| Field | Value |
|-------|-------|
| SHA | `f85963b72168e37d8820de7a7f469240dc968fd0` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 17:03:21 +0200 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPSPOSite.ps1`, `Modules/CIPPCore/Public/Set-CIPPSPOSite.ps1`, `Modules/CIPPCore/Public/Set-CIPPSPOTenant.ps1`, `Modules/CIPPCore/Public/Start-CIPPSiteVersionCleanup.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSPOVersionControl.ps1`

---

### 145. `b7d4f5e2` — Sharepoint management functionality.

| Field | Value |
|-------|-------|
| SHA | `b7d4f5e2ca653947ec0ffb8f6403f1ba7407eb6b` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 17:03:26 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSPOVersionControl.ps1`

---

### 146. `b7c72180` — fix: update terminology from "Temporary Access Password" to "Temporary Access Pass"

| Field | Value |
|-------|-------|
| SHA | `b7c72180ac5963a3c41211bc2a14e1a9a6bce796` |
| Author | Bobby |
| Date | 2026-05-27 17:11:35 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/standards.json`, `Modules/CIPPCore/Public/New-CIPPTAP.ps1`

---

### 147. `8a536fe8` — Fix: Update terminology from "Temporary Access Password" to "Temporary Access Pass" (#2066)

| Field | Value |
|-------|-------|
| SHA | `8a536fe8b906400e6401947c94aeff40c5884dd6` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 18:56:01 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 148. `bdd86024` — Add version cleanup

| Field | Value |
|-------|-------|
| SHA | `bdd86024c2b7de08eacc764076ef13b66b87fcca` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:24:44 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ExecSPOVersionCleanup.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSPOVersionControl.ps1`

---

### 149. `e563aea9` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `e563aea970d41ad282f7ef587f849097086b5c89` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:24:55 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 150. `829ced81` — feat(mailboxes): cache mailbox and archive usage metrics

| Field | Value |
|-------|-------|
| SHA | `829ced812ed7c07f63842f63eb6d91f84e326594` |
| Author | Bobby |
| Date | 2026-05-27 22:43:03 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheMailboxes.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListMailboxes.ps1`

---

### 151. `0ebb1880` — implement autopatch

| Field | Value |
|-------|-------|
| SHA | `0ebb18803a9580b06c7bfedd4b07103e2ab2da41` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 23:50:41 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAutopatchGroup.ps1`

---

### 152. `e41d5322` — Update Add-CIPPDbItem.ps1

| Field | Value |
|-------|-------|
| SHA | `e41d5322c698c331c3740b6d9d8d62ceec818971` |
| Author | Zacgoose |
| Date | 2026-05-28 12:49:03 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPDbItem.ps1`

---

### 153. `5b7c5a96` — Update Invoke-ListWorkerHealth.ps1

| Field | Value |
|-------|-------|
| SHA | `5b7c5a964b81876324525794b66387574d583c2b` |
| Author | Zacgoose |
| Date | 2026-05-28 13:56:30 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListWorkerHealth.ps1`

---

### 154. `aefa69b0` — add compliance admin by default

| Field | Value |
|-------|-------|
| SHA | `aefa69b052ed5d74d0a965f9918ac358f44a668d` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 12:31:02 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/GraphHelper/Get-NormalizedError.ps1`, `Modules/CIPPCore/Public/Set-CIPPSAMAdminRoles.ps1`

---

### 155. `25fcdc1c` — add 404 detection for non-existing roles

| Field | Value |
|-------|-------|
| SHA | `25fcdc1cf1ba33c650e1030ba0b6aa46e4a743eb` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 13:16:55 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Set-CIPPSAMAdminRoles.ps1`

---

### 156. `25e2b0f2` — tweaks

| Field | Value |
|-------|-------|
| SHA | `25e2b0f2cfa9f73ab3e61d630574b0fe91ce9498` |
| Author | Zacgoose |
| Date | 2026-05-28 20:50:50 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertAdminPassword.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListWorkerHealth.ps1`

---

### 157. `99dd88c5` — optimisation

| Field | Value |
|-------|-------|
| SHA | `99dd88c54197a92ba31c5f03b312c7931bac936b` |
| Author | Zacgoose |
| Date | 2026-05-28 21:00:14 +0800 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/BPA/Push-BPACollectData.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertDefenderMalware.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertDefenderStatus.ps1`, `Modules/CIPPCore/Public/Add-CIPPBPAField.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Autopilot/Invoke-AddAPDevice.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardBranding.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardPhishProtection.ps1`, `Modules/CippExtensions/Public/New-CippExtAlert.ps1`

---

### 158. `0cdc2e81` — new auth methods single standard

| Field | Value |
|-------|-------|
| SHA | `0cdc2e813bf8e713b8f0402f4735ff93b695e6ca` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 15:21:15 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Set-CIPPAuthenticationPolicy.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAuthenticationMethods.ps1`

---

### 159. `fc080e4a` — new auth methods single standard

| Field | Value |
|-------|-------|
| SHA | `fc080e4afdecd4076e5a68fe581c75515ce34f26` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 15:21:19 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardAuthenticationMethods.ps1`

---

### 160. `a1179a21` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `a1179a21a4a78cea0e68715ff383095e7e77e1e8` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 15:21:20 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 161. `55fea61a` — Feat: Add online archive report functionality for mailboxes (#2067)

| Field | Value |
|-------|-------|
| SHA | `55fea61a0667b35c9ca1302fb8f609322d9b45e2` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 16:21:11 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** (none)

---

### 162. `1f9fb1fd` — test invocation optimisations

| Field | Value |
|-------|-------|
| SHA | `1f9fb1fd96197138746753ebede0ed11c6df92cc` |
| Author | Zacgoose |
| Date | 2026-05-28 23:44:50 +0800 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Invoke-CIPPTestCollection.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListWorkerHealth.ps1`, `Shared/CIPPSharp/CIPPTestDataCache.cs`, `Shared/CIPPSharp/bin/CIPPSharp.dll`

---

### 163. `1ac506d7` — fix: update endpoint roles to use Autopilot.Read

| Field | Value |
|-------|-------|
| SHA | `1ac506d73e26a4f6f12653ff5cc3b797064b582d` |
| Author | Bobby |
| Date | 2026-05-28 21:23:47 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAndroidEnrollmentProfiles.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAppleEnrollmentProfiles.ps1`

---

### 164. `3f03634f` — Update Initialize-CIPPAuth.ps1

| Field | Value |
|-------|-------|
| SHA | `3f03634f66cfaf0abd9fce128e5f6e0167d68c8f` |
| Author | Zacgoose |
| Date | 2026-05-29 08:11:21 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Initialize-CIPPAuth.ps1`

---

### 165. `e0f45f20` — Backup excluded tenants config

| Field | Value |
|-------|-------|
| SHA | `e0f45f2035c77c7b8916a605a8d2e13ccd1c80d9` |
| Author | Zacgoose |
| Date | 2026-05-29 14:41:44 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPBackup.ps1`

---

### 166. `e3d57cf0` — Update Invoke-CIPPStandardDeployCheckChromeExtension.ps1

| Field | Value |
|-------|-------|
| SHA | `e3d57cf0ae0ef981173205cf0eaa6d5b26e3f371` |
| Author | Zacgoose |
| Date | 2026-05-29 17:43:32 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDeployCheckChromeExtension.ps1`

---

### 167. `a17137cb` — chore: remove cipp processor queue

| Field | Value |
|-------|-------|
| SHA | `a17137cbe0abe8418d43791ed751300b0ed84723` |
| Author | John Duprey |
| Date | 2026-05-29 14:19:45 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/CIPPTimers.json`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-CIPPProcessorQueue.ps1`

---

### 168. `0fd3315b` — chore: disable cippcommand action

| Field | Value |
|-------|-------|
| SHA | `0fd3315b9d405ed4d459ac3c8f740a640fb74099` |
| Author | John Duprey |
| Date | 2026-05-29 14:31:14 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Webhooks/Invoke-CIPPWebhookProcessing.ps1`

---

### 169. `e98445f2` — chore: sanitize cippid in public webhooks

| Field | Value |
|-------|-------|
| SHA | `e98445f25614437873439fe27a2b0f0e95d5dc69` |
| Author | John Duprey |
| Date | 2026-05-29 15:07:33 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Alerts/Invoke-PublicWebhooks.ps1`

---

### 170. `38e3ae9e` — chore: block arbitrary cmdlets not in CIPP modules

| Field | Value |
|-------|-------|
| SHA | `38e3ae9e070ba05968a07647d137efc0ae2491b3` |
| Author | John Duprey |
| Date | 2026-05-29 15:27:21 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ExecScheduledCommand.ps1`, `Modules/CIPPCore/Public/Add-CIPPScheduledTask.ps1`, `Modules/CIPPCore/Public/Tools/Get-CIPPSchedulerBlockedCommands.ps1`

---

### 171. `c18bda87` — fix: optimize checks

| Field | Value |
|-------|-------|
| SHA | `c18bda8795693324d834f54fe9235959e0e3372f` |
| Author | John Duprey |
| Date | 2026-05-29 15:31:19 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ExecScheduledCommand.ps1`

---

### 172. `c69e2ce1` — fix: allow for command without .value

| Field | Value |
|-------|-------|
| SHA | `c69e2ce19d7c8c0df0cd2c4f2de9db936da5c736` |
| Author | John Duprey |
| Date | 2026-05-29 15:33:15 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPScheduledTask.ps1`

---

### 173. `da7bd8c4` — chore: add devsecrets to restricted tables

| Field | Value |
|-------|-------|
| SHA | `da7bd8c459ab0e75abbcc9a0be96224848a11284` |
| Author | John Duprey |
| Date | 2026-05-29 15:43:15 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecRestoreBackup.ps1`

---

### 174. `2ed3f94c` — chore: remove write host

| Field | Value |
|-------|-------|
| SHA | `2ed3f94c91dcfabbc1dbd773c25120bc712801d7` |
| Author | John Duprey |
| Date | 2026-05-29 15:44:24 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecTokenExchange.ps1`

---

### 175. `f5f37368` — Optimize CIPP DB orchestration

| Field | Value |
|-------|-------|
| SHA | `f5f373681cd6e48c3b27b7140d46115c18f828a7` |
| Author | Zacgoose |
| Date | 2026-05-30 12:18:36 +0800 |
| Files changed | 207 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/CIPPDBCache/Push-ExecCIPPDBCache.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Tests/Push-CIPPTest.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Tests/Push-CIPPTestsList.ps1`, `Modules/CIPPCore/Public/Add-CIPPDbItem.ps1`, `Modules/CIPPCore/Public/Entrypoints/Orchestrator Functions/Start-CIPPDBTestsRun.ps1`, `Modules/CIPPCore/Public/Get-CIPPDbItem.ps1`, `Modules/CIPPCore/Public/Get-CIPPDomainAnalyser.ps1`, `Modules/CIPPCore/Public/Get-CippDbRole.ps1`, `Modules/CIPPCore/Public/Get-CippDbRoleMembers.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPTestCollection.ps1`, `Modules/CIPPCore/Public/New-CIPPDbRequest.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDbCacheTestData.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_1.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_2.ps1` … (+192 more)

---

### 176. `7caadb22` — fixes

| Field | Value |
|-------|-------|
| SHA | `7caadb22cd4a5525adf2959f158301836e8ba0ce` |
| Author | Zacgoose |
| Date | 2026-05-30 14:42:49 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Shared/CIPPSharp/CIPPSharp.csproj`, `Shared/CIPPSharp/bin/CIPPSharp.dll`

---

### 177. `11e613aa` — cleanup

| Field | Value |
|-------|-------|
| SHA | `11e613aab2d6886caa68e5ceb80f39e0a25293f0` |
| Author | Zacgoose |
| Date | 2026-05-30 15:55:25 +0800 |
| Files changed | 3 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/CIPPDBCache/Push-ExecCIPPDBCache.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Tests/Push-CIPPTest.ps1`, `Modules/CIPPCore/Public/Invoke-CIPPTestCollection.ps1`

---

### 178. `dd8952e4` — reduce memory

| Field | Value |
|-------|-------|
| SHA | `dd8952e4e9b458a33ba232d09d5103df9267016f` |
| Author | Zacgoose |
| Date | 2026-05-30 18:57:49 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-SchedulerCIPPNotifications.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListLogs.ps1`

---

### 179. `518855cc` — test optimisation

| Field | Value |
|-------|-------|
| SHA | `518855cc2af7527eea203002c643ef0a687caeb0` |
| Author | Zacgoose |
| Date | 2026-05-30 23:27:13 +0800 |
| Files changed | 33 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_2_2.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_2_1_5.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_2_1_9.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_4_2.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_5_2_3_4.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_8_1_1.ps1`, `Modules/CIPPTests/Public/Tests/CISA/Identity/Invoke-CippTestCISAMSEXO111.ps1`, `Modules/CIPPTests/Public/Tests/CopilotReadiness/Identity/Invoke-CippTestCopilotReady015.ps1`, `Modules/CIPPTests/Public/Tests/EIDSCA/Identity/Invoke-CippTestEIDSCAAS04.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest004.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest005.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest006.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest007.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest008.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest011.ps1` … (+18 more)

---

### 180. `999f0283` — Fix TenantAllowBlockListTemplate always reporting non-compliant

| Field | Value |
|-------|-------|
| SHA | `999f0283f8a7e273cd34c48978b6ff8cefef7ddb` |
| Author | Chris Dewey |
| Date | 2026-05-31 12:20:16 +0100 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardTenantAllowBlockListTemplate.ps1`

---

### 181. `7b341600` — update openapi spec with generated one

| Field | Value |
|-------|-------|
| SHA | `7b341600ea66916a6393af4882ed9e2e55a58a51` |
| Author | KelvinTegelaar |
| Date | 2026-05-31 22:52:53 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `openapi.json`

---

### 182. `44780652` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `44780652e874f77b413ecbf15053873d1ab66036` |
| Author | KelvinTegelaar |
| Date | 2026-05-31 22:53:22 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 183. `8341f49d` — Test

| Field | Value |
|-------|-------|
| SHA | `8341f49d863900a36070225eb9c39b0813c91c94` |
| Author | KelvinTegelaar |
| Date | 2026-05-31 23:15:16 +0200 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Get-CippMcpSpec.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Get-CippMcpToolList.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Get-CippMcpToolResult.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Invoke-ExecMcp.ps1`

---

### 184. `26a87b27` — add-member force

| Field | Value |
|-------|-------|
| SHA | `26a87b279488aa2375d055e1aefbf5c20f33004a` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 00:49:42 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`

---

### 185. `2a2851b5` — sso auth

| Field | Value |
|-------|-------|
| SHA | `2a2851b57a7a19f2105f2d892cab3c1b94df953d` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 00:58:30 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CIPPSSOEasyAuth.ps1`

---

### 186. `acf4bf33` — Add or update the Azure App Service build and deployment workflow config

| Field | Value |
|-------|-------|
| SHA | `acf4bf337f4545c5fc5fce2b93c540023c100c91` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 01:05:53 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `.github/workflows/dev_cippjta72.yml`

---

### 187. `72f7882f` — fixes another add member

| Field | Value |
|-------|-------|
| SHA | `72f7882fe5c042f4e05353e8fe27a10c6d4a5456` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 01:16:02 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`

---

### 188. `fad627f8` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `fad627f85ab6b1b3541c3d0c5de18649c358a7bf` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 01:16:04 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 189. `54a3a082` — api auth save and get changes

| Field | Value |
|-------|-------|
| SHA | `54a3a0821de35a718357f26c98be908f3bbf1a7b` |
| Author | Zacgoose |
| Date | 2026-06-01 12:39:14 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Get-CippApiAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`

---

### 190. `c16557ff` — Guarding for cache collection items

| Field | Value |
|-------|-------|
| SHA | `c16557ff6587406decf70f6d47d7fe3014da473b` |
| Author | Zacgoose |
| Date | 2026-06-01 22:26:01 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheOneDriveUsage.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSharePointSiteUsage.ps1`

---

### 191. `4b4a2d1d` — Update Set-CIPPDBCacheSharePointSiteUsage.ps1

| Field | Value |
|-------|-------|
| SHA | `4b4a2d1d7e97aa30525e84a11ef3fc8c89d9dae9` |
| Author | Zacgoose |
| Date | 2026-06-01 23:01:23 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSharePointSiteUsage.ps1`

---

### 192. `f3393cb9` — Update Invoke-ExecUniversalSearchV2.ps1

| Field | Value |
|-------|-------|
| SHA | `f3393cb9b163ff916b8882dbaaaaf981d3ae80c8` |
| Author | Zacgoose |
| Date | 2026-06-02 00:09:02 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ExecUniversalSearchV2.ps1`

---

### 193. `9d8f1a0d` — correct incorrect pathing

| Field | Value |
|-------|-------|
| SHA | `9d8f1a0dafc1dff686e1501e0bdf9e493b3dea3b` |
| Author | Zacgoose |
| Date | 2026-06-02 00:12:25 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPW32ScriptApplication.ps1`

---

### 194. `a40683c5` — fix: access issues related to undefined roles

| Field | Value |
|-------|-------|
| SHA | `a40683c560c66ebcd4164515fda9bcf68715bc37` |
| Author | John Duprey |
| Date | 2026-06-01 13:51:15 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`

---

### 195. `3c19e629` — fix: ip restriction logic

| Field | Value |
|-------|-------|
| SHA | `3c19e6299a87afa75b05726e2609e9b6da2734d8` |
| Author | John Duprey |
| Date | 2026-06-01 13:59:15 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`

---

### 196. `648127f7` — fix: role for EditIntunePolicy

| Field | Value |
|-------|-------|
| SHA | `648127f731f598547988e5dd3c581ae1eef225e1` |
| Author | John Duprey |
| Date | 2026-06-01 14:01:03 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-EditIntunePolicy.ps1`

---

### 197. `679c3905` — fix: validate token exchange url is microsoft

| Field | Value |
|-------|-------|
| SHA | `679c390558470782a3b6badc7942484049840817` |
| Author | John Duprey |
| Date | 2026-06-01 14:13:52 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecTokenExchange.ps1`

---

### 198. `139b0c60` — fix: sanitize more odata paths for tables

| Field | Value |
|-------|-------|
| SHA | `139b0c606ac3d6ed23af64001ab25bd4d70c0806` |
| Author | John Duprey |
| Date | 2026-06-01 14:30:43 -0400 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Scheduler/Invoke-ListScheduledItemDetails.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecWebhookSubscriptions.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListMailboxRules.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListKnownIPDb.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/GDAP/Invoke-ListGDAPInvite.ps1`

---

### 199. `a9797cd9` — chore: cleanup redundant tenant check in listexorequest

| Field | Value |
|-------|-------|
| SHA | `a9797cd95bb25a536e1172b3e2595c6fc8c592ea` |
| Author | John Duprey |
| Date | 2026-06-01 14:41:56 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ListExoRequest.ps1`

---

### 200. `ac338417` — add featureflag for mcp

| Field | Value |
|-------|-------|
| SHA | `ac3384171d30463c06baff35679b63d33959585a` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 21:05:23 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Settings |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `Config/FeatureFlags.json`

---

### 201. `468fb307` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `468fb30702f3e6ae2fdd39a751319a4de2648c9f` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 21:05:25 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 202. `235bd855` — fix: validate and sanitize msp/choco app params

| Field | Value |
|-------|-------|
| SHA | `235bd855f2eb1e041198a767926bd70b5f279849` |
| Author | John Duprey |
| Date | 2026-06-01 15:07:38 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/ConvertTo-CIPPSafePwshArg.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-AddChocoApp.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-AddMSPApp.ps1`

---

### 203. `256e9fc4` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `256e9fc4762663bd50f4eaa886a069ca0c7810c0` |
| Author | John Duprey |
| Date | 2026-06-01 15:16:54 -0400 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 204. `0c5d2bb8` — Fix TenantAllowBlockListTemplate always reporting non-compliant (#2069)

| Field | Value |
|-------|-------|
| SHA | `0c5d2bb8f9b105c933ce717edd2a768c32309749` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 22:51:46 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 205. `55a97db2` — added logging

| Field | Value |
|-------|-------|
| SHA | `55a97db2c4165b456b2c210d9bf0eff3c5f364bd` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 23:31:28 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Invoke-ExecOffboardTenant.ps1`

---

### 206. `0c54cd16` — fix: move New-CIPPCoreRequest back to CIPPCore

| Field | Value |
|-------|-------|
| SHA | `0c54cd16abf70bbebcd5711acf308e66bdfc8847` |
| Author | John Duprey |
| Date | 2026-06-01 18:21:07 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/New-CippCoreRequest.ps1`

---

### 207. `5a3b4259` — fix: Update endpoint roles to use Autopilot.Read (#2068)

| Field | Value |
|-------|-------|
| SHA | `5a3b42599f2005ffe20ea5629b7ae7eb35cdbbd1` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 00:24:06 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** (none)

---

### 208. `2492ad4f` — customsubject fix

| Field | Value |
|-------|-------|
| SHA | `2492ad4ffa3c17c8d79a8e8e7b0e09e6e969a0ba` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 00:44:44 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Webhooks/Invoke-CIPPWebhookProcessing.ps1`

---

### 209. `28752144` — unique

| Field | Value |
|-------|-------|
| SHA | `287521447902e5611303f14e46045279b0abeca7` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 00:47:14 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CippExtensions/Public/NinjaOne/Invoke-NinjaOneTenantSync.ps1`

---

### 210. `3f9dbd9f` — new licence report endpoint and revert old endpoint

| Field | Value |
|-------|-------|
| SHA | `3f9dbd9fcbc26fb671950ba00162f89ebade7472` |
| Author | Zacgoose |
| Date | 2026-06-02 07:30:18 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListLicenses.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Reports/Invoke-ListLicensesReport.ps1`

---

### 211. `3f842abc` — fix: explicitly remove tenant from the table instead of using -cleanold

| Field | Value |
|-------|-------|
| SHA | `3f842abc805d82fcd12f3d526b1dd66fa5cb9764` |
| Author | John Duprey |
| Date | 2026-06-02 10:13:12 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Invoke-ExecOffboardTenant.ps1`

---

### 212. `55ddb18b` — Update Invoke-ExecTestRun.ps1

| Field | Value |
|-------|-------|
| SHA | `55ddb18b23e73d0ed21f12c7ceadb40d87822c7a` |
| Author | Zacgoose |
| Date | 2026-06-03 07:12:50 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ExecTestRun.ps1`

---

### 213. `1167ff5b` — caching bump

| Field | Value |
|-------|-------|
| SHA | `1167ff5bd293fccad0a5c51919c85449982636fc` |
| Author | Zacgoose |
| Date | 2026-06-03 08:09:45 +0800 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Shared/CIPPSharp/CIPPTestDataCache.cs`, `Shared/CIPPSharp/bin/CIPPSharp.dll`

---

### 214. `6eeb31b4` — Pluralize standard name and continue on error

| Field | Value |
|-------|-------|
| SHA | `6eeb31b4661478bf527d3ef1fa3543f99d18f60a` |
| Author | Zacgoose |
| Date | 2026-06-03 12:12:23 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDeployContactTemplates.ps1`

---

### 215. `058da5e0` — rework mail contact standard and lazy load modules when needed

| Field | Value |
|-------|-------|
| SHA | `058da5e0d615c944b4cc6a11878a1d4602c3397d` |
| Author | Zacgoose |
| Date | 2026-06-03 12:51:53 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPScheduledTask.ps1`, `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDeployContactTemplates.ps1`

---

### 216. `2edc7592` — Handle PendingAcceptance guests and update reporting

| Field | Value |
|-------|-------|
| SHA | `2edc759287485c1e4cec76e345a04323457a63c3` |
| Author | Zacgoose |
| Date | 2026-06-03 14:11:33 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardDisableGuests.ps1`

---

### 217. `64efbd97` — Apply multiple fixes to the add member to exo groups flow including adding new users with auto retry

| Field | Value |
|-------|-------|
| SHA | `64efbd97477f8fe0ce907f7534c253d6b7239d01` |
| Author | Zacgoose |
| Date | 2026-06-03 14:38:32 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPGroupMember.ps1`, `Modules/CIPPCore/Public/New-CIPPUserTask.ps1`

---

### 218. `a9be2729` — Update Invoke-CIPPStandardEnableExchangeCloudManagement.ps1

| Field | Value |
|-------|-------|
| SHA | `a9be2729d883ffeceb8c6eaf06998fc4e6175c40` |
| Author | Zacgoose |
| Date | 2026-06-03 14:39:44 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardEnableExchangeCloudManagement.ps1`

---

### 219. `3e99e667` — add mcp allowed

| Field | Value |
|-------|-------|
| SHA | `3e99e667d8fe5e6326cc465fa45264df817e5938` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 13:37:04 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Get-CippApiClient.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Invoke-ExecMcp.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`

---

### 220. `a2c2524c` — oauth prm

| Field | Value |
|-------|-------|
| SHA | `a2c2524c02ad0a6e66440beef1091f7a05714808` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 16:16:02 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`

---

### 221. `1fc42631` — feat: add Email as alternate login ID standard

| Field | Value |
|-------|-------|
| SHA | `1fc4263123219960af1ec87558f8cd73b7a62a7f` |
| Author | Bobby |
| Date | 2026-06-03 16:54:13 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardEmailAsAlternateLoginId.ps1`

---

### 222. `5c81043c` — change resource usage to craft well known

| Field | Value |
|-------|-------|
| SHA | `5c81043c08757d3b340414b9fe2d865c1a1ca612` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 17:41:01 +0200 |
| Files changed | 7 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `CIPPHttpTrigger/function.json`, `CIPPWellKnown/function.json`, `Modules/CIPPCore/Public/Authentication/Set-CIPPSSOEasyAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`, `Modules/CippEntrypoints/CippEntrypoints.psm1`, `host.json`

---

### 223. `6fc7d357` — Revert custom well known

| Field | Value |
|-------|-------|
| SHA | `6fc7d357ee34ea694b96028815d2f9eacfc715e5` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 18:18:49 +0200 |
| Files changed | 7 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `CIPPHttpTrigger/function.json`, `CIPPWellKnown/function.json`, `Modules/CIPPCore/Public/Authentication/Set-CIPPSSOEasyAuth.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`, `Modules/CippEntrypoints/CippEntrypoints.psm1`, `host.json`

---

### 224. `0cd6f9d2` — MCP client updates to support client auth

| Field | Value |
|-------|-------|
| SHA | `0cd6f9d2d630e1c9561103fa4f3c1fefa95d33a5` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 19:25:55 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CIPPMCPClientApp.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`

---

### 225. `ec2eb836` — add logging to mcp reation.

| Field | Value |
|-------|-------|
| SHA | `ec2eb836f775584f85f06de10d8ad53d59e07334` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 20:05:50 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecApiClient.ps1`

---

### 226. `49e8af8b` — feat: add Invoke-ExecSetCASMailbox function for CAS settings management

| Field | Value |
|-------|-------|
| SHA | `49e8af8b9d9b867c9a44f12bfc536c02890e4af7` |
| Author | Bobby |
| Date | 2026-06-03 19:24:52 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecSetCASMailbox.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Reports/Invoke-ListMailboxCAS.ps1`

---

### 227. `23506364` — add tot non-ng

| Field | Value |
|-------|-------|
| SHA | `235063643757177c83cc380d14af2464f921f897` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 20:38:08 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Set-CippApiAuth.ps1`

---

### 228. `72c277d7` — Allow MCP client

| Field | Value |
|-------|-------|
| SHA | `72c277d77f26595a99f65af7726029e6ea87e362` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 20:56:18 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Invoke-ExecMcp.ps1`

---

### 229. `7800b3cb` — Fix

| Field | Value |
|-------|-------|
| SHA | `7800b3cb14db994b1867a4f6f5bb1116e818e336` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 21:22:27 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`

---

### 230. `77073ba3` — role change

| Field | Value |
|-------|-------|
| SHA | `77073ba369222e427671f8c75ba07facfbb08a2e` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 23:49:53 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/New-CippCoreRequest.ps1`

---

### 231. `bc6aee43` — fix: quarantine deny action

| Field | Value |
|-------|-------|
| SHA | `bc6aee43b74cd0672d858b9d31effbda6283847a` |
| Author | John Duprey |
| Date | 2026-06-03 21:33:32 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecQuarantineManagement.ps1`

---

### 232. `4288bd80` — exclude partner tenant

| Field | Value |
|-------|-------|
| SHA | `4288bd80f1d901e73c9054c887f8b9d3d2068da3` |
| Author | Zacgoose |
| Date | 2026-06-04 16:04:01 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/TenantGroups/Get-TenantGroups.ps1`, `Modules/CIPPCore/Public/TenantGroups/Update-CIPPDynamicTenantGroups.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecCreateDefaultGroups.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecTenantGroup.ps1`

---

### 233. `adba8fa7` — add excludeFromAlert to licenses.

| Field | Value |
|-------|-------|
| SHA | `adba8fa7febc74db4fe15f8e06941a9ce3d58540` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:21:33 +0200 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertExpiringLicenses.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertOverusedLicenses.ps1`, `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertUnusedLicenses.ps1`, `Modules/CIPPCore/Public/Get-CIPPLicenseOverview.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecExcludeLicenses.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListExcludedLicenses.ps1`, `Modules/CippExtensions/Public/Extension Functions/Sync-CippExtensionData.ps1`, `Modules/CippExtensions/Public/Gradient/New-GradientServiceSyncRun.ps1`

---

### 234. `9a176cc7` — feat: Add Group-Based Licensing support (#2063)

| Field | Value |
|-------|-------|
| SHA | `9a176cc7b6a3177b1ff04d8261273b6a863ff9ca` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:26:32 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 235. `593911e1` — Feat: Add Invoke-ExecSetCASMailbox function for CAS settings management (#2076)

| Field | Value |
|-------|-------|
| SHA | `593911e1ca62e68f21ee7ed971b39d63b1818406` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:36:51 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** (none)

---

### 236. `a8e7aa5e` — Feat: Add Email as alternate login ID standard (#2075)

| Field | Value |
|-------|-------|
| SHA | `a8e7aa5eac2e442cb7354faa214420d9bede3379` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:37:04 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** (none)

---

### 237. `2b3a7bb5` — resolves #6096

| Field | Value |
|-------|-------|
| SHA | `2b3a7bb50bc8c42c79dd9147baa46ef9e2e2ae1f` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:40:42 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Users/Invoke-EditUser.ps1`

---

### 238. `ae921278` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `ae921278dbba126ac8aad7c25bb5cc2b00dbd5a6` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:40:44 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 239. `53db433c` — better descriptions

| Field | Value |
|-------|-------|
| SHA | `53db433cdee8008bd93188053151e692abdba4e0` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 13:49:57 +0200 |
| Files changed | 21 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows, Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListCalendarPermissions.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListHVEAccounts.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListMailboxRules.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListMailboxes.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListmailboxPermissions.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Reports/Invoke-ListMailboxForwarding.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-ListApps.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAppProtectionPolicies.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListAssignmentFilters.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListCompliancePolicies.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntunePolicy.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntuneReusableSettings.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/MEM/Invoke-ListIntuneScript.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Groups/Invoke-ListGroups.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Reports/Invoke-ListMFAUsers.ps1` … (+6 more)

---

### 240. `c7cebfeb` — better descriptions

| Field | Value |
|-------|-------|
| SHA | `c7cebfeb4ff1cb4565926cf653b62c92a96cd505` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 13:50:07 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListCalendarPermissions.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ListHVEAccounts.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Reports/Invoke-ListOAuthApps.ps1`

---

### 241. `6a1c3733` — fixes issue with all tenants retrieval

| Field | Value |
|-------|-------|
| SHA | `6a1c373363007e65c6cd2cac5ee6bd568d608c3e` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 15:08:35 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListDBCache.ps1`

---

### 242. `4909e9c2` — dbcache desc

| Field | Value |
|-------|-------|
| SHA | `4909e9c2094e9ad497d2c5decfe3f3d1070f6a26` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 15:09:37 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Invoke-ListDBCache.ps1`

---

### 243. `3ca58875` — updated descriptions.

| Field | Value |
|-------|-------|
| SHA | `3ca58875ac346e65937655ced8cf044603df75ca` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 15:17:52 +0200 |
| Files changed | 160 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal, Tenant Workflows, Permissions/Roles/Auth, Standards/Alignment Custom; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListAdminPortalLicenses.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListApiTest.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListCustomDataMappings.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListDiagnosticsPresets.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListDirectoryObjects.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListFeatureFlags.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListGraphBulkRequest.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListGraphRequest.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListSnoozedAlerts.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/invoke-ListEmptyResults.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Extensions/Invoke-ListExtensionSync.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Scheduler/Invoke-ListScheduledItemDetails.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Scheduler/Invoke-ListScheduledItems.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListCIPPUsers.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ListContainerLogs.ps1` … (+145 more)

---

### 244. `7902097a` — add missing return

| Field | Value |
|-------|-------|
| SHA | `7902097acf76faf4ee0b6a80f2dff8cf2b0c3abd` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 22:07:50 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecUpdateRefreshToken.ps1`

---

### 245. `65659c21` — fix: remove headers parameter from scheduler details/list

| Field | Value |
|-------|-------|
| SHA | `65659c21ffad84702b6a6f62e83a39a6e59a42d9` |
| Author | John Duprey |
| Date | 2026-06-04 16:23:35 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Scheduler/Invoke-ListScheduledItemDetails.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Scheduler/Invoke-ListScheduledItems.ps1`

---

### 246. `c5d15588` — fix: version check

| Field | Value |
|-------|-------|
| SHA | `c5d15588e31b2591514b2682d6301e9a60559c0a` |
| Author | John Duprey |
| Date | 2026-06-04 19:59:00 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Assert-CippVersion.ps1`

---

### 247. `c5849381` — fix: fallback to app version if one is not specified

| Field | Value |
|-------|-------|
| SHA | `c5849381984688f46eeb6c71e0f6ffc59acde285` |
| Author | John Duprey |
| Date | 2026-06-04 20:20:08 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Assert-CippVersion.ps1`

---

### 248. `d4ddd3d6` — fix: additional protections for choco app deployment

| Field | Value |
|-------|-------|
| SHA | `d4ddd3d6ff34f7a214bc58eae32eb7477b7b076e` |
| Author | John Duprey |
| Date | 2026-06-04 23:12:34 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/New-CIPPIntuneAppDeployment.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Endpoint/Applications/Invoke-AddChocoApp.ps1`

---

### 249. `2bbcfcc8` — This endpoint is silly, we are going to manually try paging

| Field | Value |
|-------|-------|
| SHA | `2bbcfcc825d0081fe7add434e41ee02ab3dbb468` |
| Author | Zacgoose |
| Date | 2026-06-05 16:50:55 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ListMailQuarantineAllTenants.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ListMailQuarantine.ps1`

---

### 250. `90e45ead` — pass timing to stop queue rerun protection drift

| Field | Value |
|-------|-------|
| SHA | `90e45eadaac33b4991b18038c78a3a44e161a05e` |
| Author | Zacgoose |
| Date | 2026-06-05 17:51:43 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Standards/Push-CIPPStandard.ps1`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Standards/Push-CIPPStandardsList.ps1`

---

### 251. `3fa0ee6c` — Pipe character escaping in names

| Field | Value |
|-------|-------|
| SHA | `3fa0ee6c412cec4e9a6a3dade4befa21dcffc885` |
| Author | Zacgoose |
| Date | 2026-06-05 18:20:42 +0800 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Tools/Push-ExecGenerateReportBuilderReport.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest004.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest005.ps1`, `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest006.ps1`

---

### 252. `2b3a1c81` — Fix for manually run standards being excluded from applied standards report page

| Field | Value |
|-------|-------|
| SHA | `2b3a1c818be171adbd6526f1069447a43f1801b0` |
| Author | Zacgoose |
| Date | 2026-06-05 18:27:17 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Standards/Invoke-ListStandardsCompare.ps1`

---

### 253. `4435ea38` — CA expansion for tags

| Field | Value |
|-------|-------|
| SHA | `4435ea380685a4bad5a9e7506aba54f0cfc861ae` |
| Author | KelvinTegelaar |
| Date | 2026-06-05 13:17:04 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Functions/Get-CIPPTenantAlignment.ps1`, `Modules/CIPPCore/Public/Get-CIPPDrift.ps1`, `Modules/CIPPCore/Public/Standards/Get-CIPPStandards.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Standards/Invoke-listStandardTemplates.ps1`

---

### 254. `9cab0663` — CA expansion for tags

| Field | Value |
|-------|-------|
| SHA | `9cab066385d0b71f0879a0a438e0e6ed4949a698` |
| Author | KelvinTegelaar |
| Date | 2026-06-05 13:17:13 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Functions/Get-CIPPTenantAlignment.ps1`, `Modules/CIPPCore/Public/Get-CIPPDrift.ps1`

---

### 255. `2b093c37` — fixes issue with CA compare and a weird blank line

| Field | Value |
|-------|-------|
| SHA | `2b093c37ad3444f546efec5ad157270e7b540ba9` |
| Author | KelvinTegelaar |
| Date | 2026-06-05 13:36:39 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardConditionalAccessTemplate.ps1`

---

### 256. `f7f51cc1` — remove duplicate non gated cache collection items

| Field | Value |
|-------|-------|
| SHA | `f7f51cc192a3e11238deef55a38ed6e43dfaa076` |
| Author | Zacgoose |
| Date | 2026-06-05 21:00:58 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-CIPPDBCacheData.ps1`

---

### 257. `ed47810f` — Update Test-CIPPAccess.ps1

| Field | Value |
|-------|-------|
| SHA | `ed47810fdf281fc4366eb76fea9fb843c8cdd108` |
| Author | Zacgoose |
| Date | 2026-06-05 21:47:33 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1`

---

### 258. `c040658a` — Update FeatureFlags.json

| Field | Value |
|-------|-------|
| SHA | `c040658ade0890d26514364d2d1f7ff5a4b528fe` |
| Author | Zacgoose |
| Date | 2026-06-05 21:59:25 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Settings |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `Config/FeatureFlags.json`

---

### 259. `612ba54c` — Update Get-CIPPTenantAlignment.ps1

| Field | Value |
|-------|-------|
| SHA | `612ba54ca20e033be1dd5977efd3720f57b97f18` |
| Author | Zacgoose |
| Date | 2026-06-05 22:44:44 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Functions/Get-CIPPTenantAlignment.ps1`

---

### 260. `f0f361d4` — restart helper

| Field | Value |
|-------|-------|
| SHA | `f0f361d4b40b9bbab1116eb4aeb8c781afca57f1` |
| Author | Zacgoose |
| Date | 2026-06-05 23:28:22 +0800 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Initialize-CIPPAuth.ps1`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-ContainerUpdateCheck.ps1`, `Modules/CIPPCore/Public/Functions/Request-CIPPRestart.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Settings/Invoke-ExecContainerManagement.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecSSOSetup.ps1`

---

### 261. `961462f3` — fix: role assignment checks

| Field | Value |
|-------|-------|
| SHA | `961462f346d5b8fe357dc322e550dee95a644232` |
| Author | John Duprey |
| Date | 2026-06-05 12:05:46 -0400 |
| Files changed | 5 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_1.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_2.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_3.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_4.ps1`, `Modules/CIPPTests/Public/Tests/ZTNA/Identity/Invoke-CippTestZTNA21782.ps1`

---

### 262. `503eac5b` — fix: apps and services test

| Field | Value |
|-------|-------|
| SHA | `503eac5bdb6322f1e42b8e90cc48ab9f3b4c4c5b` |
| Author | John Duprey |
| Date | 2026-06-05 12:18:30 -0400 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSettings.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_3_4.ps1`

---

### 263. `ee1884f7` — add permissions for new settings endpoint

| Field | Value |
|-------|-------|
| SHA | `ee1884f7cc5e32fe77ae90d35028f5dfc0761e23` |
| Author | John Duprey |
| Date | 2026-06-05 12:22:09 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `Config/SAMManifest.json`

---

### 264. `d817b6d2` — fix: cis test 1_3_5

| Field | Value |
|-------|-------|
| SHA | `d817b6d2815abb63cd81c4ffcc31d5deb15b35a2` |
| Author | John Duprey |
| Date | 2026-06-05 12:45:31 -0400 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheSettings.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_3_5.ps1`

---

### 265. `da10bf92` — renumber for cis7

| Field | Value |
|-------|-------|
| SHA | `da10bf92a82e9c791d2c32f6dd0b7b057baac067` |
| Author | KelvinTegelaar |
| Date | 2026-06-06 00:46:28 +0200 |
| Files changed | 299 |
| Risk | **Low** |
| Area | Docs |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Medium |
| Notes | Buckets: Documentation-only |

**Files:** `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_1.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_1.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_2.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_2.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_3.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_3.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_4.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_1_4.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_2_1.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_2_1.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_2_2.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_2_2.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_3_1.md`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_3_1.ps1`, `Modules/CIPPTests/Public/Tests/CIS/Identity/Invoke-CippTestCIS_1_3_2.md` … (+284 more)

---

### 266. `5df315b6` — improved open api spec for ai

| Field | Value |
|-------|-------|
| SHA | `5df315b6c86356251eb341fbdb6aac773daf9e7d` |
| Author | KelvinTegelaar |
| Date | 2026-06-06 21:00:02 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `openapi.json`

---

### 267. `65ba7a78` — embed module into pipeline actions

| Field | Value |
|-------|-------|
| SHA | `65ba7a7880657dd81d745ba677a7c57f27f7ee50` |
| Author | Zacgoose |
| Date | 2026-06-07 13:24:52 +0800 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Build-DevApiModules.ps1`, `Tools/ModuleBuilder/3.1.8/ModuleBuilder.psd1`, `Tools/ModuleBuilder/3.1.8/ModuleBuilder.psm1`, `Tools/ModuleBuilder/3.1.8/PSGetModuleInfo.xml`, `Tools/ModuleBuilder/3.1.8/en-US/about_ModuleBuilder.help.txt`

---

### 268. `431d2929` — extra module dep

| Field | Value |
|-------|-------|
| SHA | `431d29296def585602ede34296810881bc4d1d94` |
| Author | Zacgoose |
| Date | 2026-06-07 13:30:34 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Build-DevApiModules.ps1`, `Tools/Configuration/1.6.0/Configuration.psd1`, `Tools/Configuration/1.6.0/Configuration.psm1`, `Tools/Configuration/1.6.0/PSGetModuleInfo.xml`

---

### 269. `336909e8` — extra module dep

| Field | Value |
|-------|-------|
| SHA | `336909e8837a835b113a92d6db94b4b23d83e678` |
| Author | Zacgoose |
| Date | 2026-06-07 13:32:43 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Build-DevApiModules.ps1`, `Tools/Metadata/1.5.7/Metadata.psd1`, `Tools/Metadata/1.5.7/Metadata.psm1`, `Tools/Metadata/1.5.7/PSGetModuleInfo.xml`

---

### 270. `d3d98923` — cache middleware changes

| Field | Value |
|-------|-------|
| SHA | `d3d989239922033360844a522ef1c930b4949c9e` |
| Author | Zacgoose |
| Date | 2026-06-07 14:56:27 +0800 |
| Files changed | 6 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Entrypoints/HTTP Functions/New-CippCoreRequest.ps1`, `Modules/CIPPCore/Public/Entrypoints/Orchestrator Functions/Start-CIPPDBTestsRun.ps1`, `Modules/CIPPCore/Public/Entrypoints/Orchestrator Functions/Start-UserTasksOrchestrator.ps1`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-DurableCleanup.ps1`, `Shared/CIPPSharp/CIPPTestDataCache.cs`, `Shared/CIPPSharp/bin/CIPPSharp.dll`

---

### 271. `ddc264a7` — Update Invoke-CippTestGenericTest002.ps1

| Field | Value |
|-------|-------|
| SHA | `ddc264a771b27807a35d12fd3645d4693b4a21f8` |
| Author | Zacgoose |
| Date | 2026-06-08 12:49:44 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/GenericTests/Identity/Invoke-CippTestGenericTest002.ps1`

---

### 272. `2a63cfc7` — Update Get-CIPPAlertQuotaUsed.ps1

| Field | Value |
|-------|-------|
| SHA | `2a63cfc7eb0e457762a8fa3c50b9121821becb12` |
| Author | Zacgoose |
| Date | 2026-06-08 13:27:58 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPAlerts/Public/Alerts/Get-CIPPAlertQuotaUsed.ps1`

---

### 273. `64f30df6` — Update Start-DurableCleanup.ps1

| Field | Value |
|-------|-------|
| SHA | `64f30df6a54328ba3e886cd83d5b7417fb153ff2` |
| Author | Zacgoose |
| Date | 2026-06-08 14:51:46 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-DurableCleanup.ps1`

---

### 274. `34112ffd` — temporary 1 day to clear old ips

| Field | Value |
|-------|-------|
| SHA | `34112ffd912693d51f62e1f98e12a5009fc556fd` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 11:30:26 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Get-CIPPGeoIPLocation.ps1`

---

### 275. `bfb0c17a` — tools update

| Field | Value |
|-------|-------|
| SHA | `bfb0c17a9ccd997e71218c4e5e71c68868fbd941` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 11:31:26 +0200 |
| Files changed | 10 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Tools/Configuration/1.6.0/Configuration.psd1`, `Tools/Configuration/1.6.0/Configuration.psm1`, `Tools/Configuration/1.6.0/PSGetModuleInfo.xml`, `Tools/Metadata/1.5.7/Metadata.psd1`, `Tools/Metadata/1.5.7/Metadata.psm1`, `Tools/Metadata/1.5.7/PSGetModuleInfo.xml`, `Tools/ModuleBuilder/3.1.8/ModuleBuilder.psd1`, `Tools/ModuleBuilder/3.1.8/ModuleBuilder.psm1`, `Tools/ModuleBuilder/3.1.8/PSGetModuleInfo.xml`, `Tools/ModuleBuilder/3.1.8/en-US/about_ModuleBuilder.help.txt`

---

### 276. `e4455d3f` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `e4455d3f176fdab57e3d0ff12f421894cf20246c` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 11:31:28 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 277. `a52f002d` — 10.5.0 version up

| Field | Value |
|-------|-------|
| SHA | `a52f002d5601c521998d84ca65544d561154e48e` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 11:32:50 +0200 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `version_latest.txt`

---

### 278. `4f8bc79c` — Dev to release (#2081)

| Field | Value |
|-------|-------|
| SHA | `4f8bc79cec338f08dfc3374f95e014b42fbfe157` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 14:25:19 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 279. `b36a32b0` — shuffle file locations

| Field | Value |
|-------|-------|
| SHA | `b36a32b0a89397e211cd681ac62669efb79c79c5` |
| Author | Zacgoose |
| Date | 2026-06-09 00:04:52 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/MCP/Get-CippMcpSpec.ps1`, `Modules/CIPPCore/Public/MCP/Get-CippMcpToolList.ps1`, `Modules/CIPPCore/Public/MCP/Get-CippMcpToolResult.ps1`, `Modules/CIPPHTTP/Public/Invoke-ListObjectHistory.ps1`

---

### 280. `fc76e111` — sso app repair and fix migration failures

| Field | Value |
|-------|-------|
| SHA | `fc76e111b828b514e5abdd5fbe43a2fa90740468` |
| Author | Zacgoose |
| Date | 2026-06-09 01:03:56 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Authentication/Add-CIPPSSOAppSecret.ps1`, `Modules/CIPPCore/Public/Authentication/New-CIPPSSOApp.ps1`, `Modules/CIPPCore/Public/Authentication/Set-CIPPSSOStoredCredentials.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Setup/Invoke-ExecSSOSetup.ps1`

---

### 281. `c0f663ca` — fix: update role and fix variable casing in message trace function

| Field | Value |
|-------|-------|
| SHA | `c0f663ca436572f4a88571553d03a13b5ad9fc01` |
| Author | Bobby |
| Date | 2026-06-08 22:49:25 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ListMessageTrace.ps1`

---

### 282. `3e33fdb1` — fix: more robust conversion for EnableAutoTrim setting

| Field | Value |
|-------|-------|
| SHA | `3e33fdb15b67daa52c8bb0651b737193787d5371` |
| Author | Bobby |
| Date | 2026-06-08 23:59:05 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSPOVersionControl.ps1`

---

### 283. `3f9aab05` — api version file fixes

| Field | Value |
|-------|-------|
| SHA | `3f9aab05b0c73759016aef39ba6cd62416b92d0b` |
| Author | Zacgoose |
| Date | 2026-06-09 13:40:29 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Config/version_latest.txt`, `Modules/CIPPCore/Public/Authentication/Get-CippAllowedPermissions.ps1`, `Modules/CIPPCore/Public/Entrypoints/Timer Functions/Start-CIPPStatsTimer.ps1`

---

### 284. `2138ec6d` — Fix: Improve conversion for EnableAutoTrim setting (#2084)

| Field | Value |
|-------|-------|
| SHA | `2138ec6d13f531bce2f61b1dc3f110dd75935ce9` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 10:26:37 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 285. `c215631c` — Fix: Message trace role and variable casing in message trace function (#2083)

| Field | Value |
|-------|-------|
| SHA | `c215631c31f850630553c44f7e3aa5a78f4e1b7b` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 10:26:54 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** (none)

---

### 286. `2925643d` — push endpoint over to export job endpoint

| Field | Value |
|-------|-------|
| SHA | `2925643d2f15f3a6d551a85a60255fbaae4d5e9c` |
| Author | Zacgoose |
| Date | 2026-06-09 17:09:03 +0800 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Config/CIPPTimers.json`, `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-IntuneReportExportSubmit.ps1`, `Modules/CIPPCore/Public/Entrypoints/Orchestrator Functions/Start-IntuneReportExportOrchestrator.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheDetectedApps.ps1`

---

### 287. `b79c296f` — sherweb migration fixes

| Field | Value |
|-------|-------|
| SHA | `b79c296f0344bdd0783568896ced47bbce8380d4` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 13:57:18 +0200 |
| Files changed | 5 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ExecScheduledCommand.ps1`, `Modules/CIPPCore/Public/Add-CIPPScheduledTask.ps1`, `Modules/CippExtensions/Public/Extension Functions/Register-CippExtensionScheduledTasks.ps1`, `Modules/CippExtensions/Public/Sherweb/Invoke-SherwebMigration.ps1`, `Modules/CippExtensions/Public/Sherweb/Test-SherwebMigrationAccounts.ps1`

---

### 288. `280b3b9d` — fix: add CippExtensions to allowlist

| Field | Value |
|-------|-------|
| SHA | `280b3b9d08578311a60d3baf501984b205356fb6` |
| Author | John Duprey |
| Date | 2026-06-09 07:57:29 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPActivityTriggers/Public/Entrypoints/Activity Triggers/Push-ExecScheduledCommand.ps1`, `Modules/CIPPCore/Public/Add-CIPPScheduledTask.ps1`, `profile.ps1`

---

### 289. `8f1069cf` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `8f1069cf56b4647c42b6e0538682b338d89824af` |
| Author | John Duprey |
| Date | 2026-06-09 07:57:31 -0400 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 290. `2511c6e5` — add limits for tools copilot studio

| Field | Value |
|-------|-------|
| SHA | `2511c6e56640e03ed49000f7133cc027fcea1717` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:50:17 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/MCP/Get-CippMcpToolList.ps1`, `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Invoke-ExecMcp.ps1`

---

### 291. `6c897f52` — fixes group addition in user page and vacation mode

| Field | Value |
|-------|-------|
| SHA | `6c897f52f26b6a3a75c5a042b18e140f8e44d13c` |
| Author | Zacgoose |
| Date | 2026-06-09 21:17:48 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Add-CIPPGroupMember.ps1`, `Modules/CIPPCore/Public/New-CIPPUserTask.ps1`

---

### 292. `39e1a34e` — chore: bump version to 10.5.1

| Field | Value |
|-------|-------|
| SHA | `39e1a34e3d33a7657f10c1d21eda71190596cdee` |
| Author | John Duprey |
| Date | 2026-06-09 10:35:41 -0400 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `host.json`, `version_latest.txt`

---

### 293. `14346161` — Dev to hotfix (#2085)

| Field | Value |
|-------|-------|
| SHA | `143461619d6f95588c7725c5110b915a2e676797` |
| Author | John Duprey |
| Date | 2026-06-09 10:39:33 -0400 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 294. `64836c02` — fix: rerun detection on scheduled tasks

| Field | Value |
|-------|-------|
| SHA | `64836c02a801a3718c2bd2e598bcf206c973541d` |
| Author | John Duprey |
| Date | 2026-06-09 12:15:57 -0400 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Test-CIPPRerun.ps1`

---

### 295. `9dd0e567` — Update Invoke-ListTenantAlignment.ps1

| Field | Value |
|-------|-------|
| SHA | `9dd0e56750810b7a85ef4fb079dbf6725b2b6ce0` |
| Author | Zacgoose |
| Date | 2026-06-10 14:27:26 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Standards/Invoke-ListTenantAlignment.ps1`

---

### 296. `a0a79852` — Update Invoke-ListTenantAlignment.ps1

| Field | Value |
|-------|-------|
| SHA | `a0a79852f89fb82c0f5bab15822b46870198956e` |
| Author | Zacgoose |
| Date | 2026-06-10 14:45:31 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Standards/Invoke-ListTenantAlignment.ps1`

---

### 297. `e8d13427` — audit log detailed logging for debugging

| Field | Value |
|-------|-------|
| SHA | `e8d1342774427bee3572ebcb9f2aad8c0d30c800` |
| Author | Zacgoose |
| Date | 2026-06-10 15:03:18 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/AuditLogs/New-CippAuditLogSearch.ps1`, `Modules/CIPPCore/Public/GraphHelper/New-GraphPOSTRequest.ps1`

---

### 298. `b8fefcfd` — Update Invoke-ExecMcp.ps1

| Field | Value |
|-------|-------|
| SHA | `b8fefcfdd085b5f25782f7f3da70324252f3c630` |
| Author | Zacgoose |
| Date | 2026-06-10 15:20:53 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/MCP/Invoke-ExecMcp.ps1`

---

### 299. `83b13034` — bulk request next link following

| Field | Value |
|-------|-------|
| SHA | `83b130347aa81fb373cb77de32583dab9628e2e8` |
| Author | Zacgoose |
| Date | 2026-06-10 22:33:53 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/GraphHelper/New-ExoBulkRequest.ps1`

---

### 300. `9f0bacd6` — manual pagination support for Invoke-ListMailQuarantine

| Field | Value |
|-------|-------|
| SHA | `9f0bacd62c74d6e65ee0f51623884569de2eb8c1` |
| Author | Zacgoose |
| Date | 2026-06-10 22:49:50 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ListMailQuarantine.ps1`

---

### 301. `cc84a49d` — Fix ORCA104

| Field | Value |
|-------|-------|
| SHA | `cc84a49df1633a1b5de2dfdeda991f9d8b7b660c` |
| Author | Zacgoose |
| Date | 2026-06-10 23:22:58 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA104.ps1`

---

### 302. `8cd8d1d9` — Fix for ORCA107 and add Exchange Global Quarantine policy to cache

| Field | Value |
|-------|-------|
| SHA | `8cd8d1d94e51ce793d79567822483073715392ad` |
| Author | Zacgoose |
| Date | 2026-06-10 23:51:56 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Tests |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Tests-only, Potentially breaking changes |

**Files:** `Config/CIPPDBCacheTypes.json`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoQuarantinePolicy.ps1`, `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA107.ps1`

---

### 303. `2ab0e0e2` — fix: rerun issue

| Field | Value |
|-------|-------|
| SHA | `2ab0e0e27c77d146301b427365e0d305e813137d` |
| Author | John Duprey |
| Date | 2026-06-10 12:06:17 -0400 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPCore/Public/Test-CIPPRerun.ps1`

---

### 304. `238001c1` — Update policy based on MS and Orca guidance

| Field | Value |
|-------|-------|
| SHA | `238001c13e0d62a7f13b00d46c99c7be82c11cad` |
| Author | Zacgoose |
| Date | 2026-06-11 00:13:53 +0800 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPStandards/Public/Standards/Invoke-CIPPStandardSpamFilterPolicy.ps1`, `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA102.ps1`

---

### 305. `0640f07c` — Fixes ORCA179

| Field | Value |
|-------|-------|
| SHA | `0640f07ccdf22a8294a91502def41b987be84ab5` |
| Author | Zacgoose |
| Date | 2026-06-11 00:25:11 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA179.ps1`

---

### 306. `db3de75a` — Fixes ORCA244

| Field | Value |
|-------|-------|
| SHA | `db3de75a6c6fc7cbf6e1c775ffb485e9ca2a215d` |
| Author | Zacgoose |
| Date | 2026-06-11 00:26:36 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA244.ps1`

---

### 307. `a556b98b` — Fixes ORCA113

| Field | Value |
|-------|-------|
| SHA | `a556b98bdbd08fb9d97df79ae8c79f4d47011e39` |
| Author | Zacgoose |
| Date | 2026-06-11 00:34:47 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA113.ps1`

---

### 308. `cbcc61b5` — Fixes ORCA103

| Field | Value |
|-------|-------|
| SHA | `cbcc61b5afd8c7ea9bb9bef1da7878465afc5610` |
| Author | Zacgoose |
| Date | 2026-06-11 00:48:34 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA103.ps1`

---

### 309. `2851db0f` — Fixes ORCA233_1

| Field | Value |
|-------|-------|
| SHA | `2851db0f52d88c4a7b5ee0d1a739a7d9d95ea27b` |
| Author | Zacgoose |
| Date | 2026-06-11 01:17:20 +0800 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Config/CIPPDBCacheTypes.json`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoInboundConnector.ps1`, `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA233_1.ps1`

---

### 310. `28ba94b4` — Fixes ORCA242

| Field | Value |
|-------|-------|
| SHA | `28ba94b43709b89dee2a349742f68c1df5ac1bf8` |
| Author | Zacgoose |
| Date | 2026-06-11 01:17:33 +0800 |
| Files changed | 4 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Config/CIPPDBCacheTypes.json`, `Modules/CIPPCore/Public/Invoke-CIPPDBCacheCollection.ps1`, `Modules/CIPPDB/Public/DBCache/Set-CIPPDBCacheExoProtectionAlert.ps1`, `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA242.ps1`

---

### 311. `f37d68ad` — Fixes ORCA235

| Field | Value |
|-------|-------|
| SHA | `f37d68adfa17516f05cb9422fe01da589252ada9` |
| Author | Zacgoose |
| Date | 2026-06-11 01:26:09 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Modules/CIPPTests/Public/Tests/ORCA/Identity/Invoke-CippTestORCA235.ps1`

---

### 312. `abcbb60a` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP-API into dev

| Field | Value |
|-------|-------|
| SHA | `abcbb60a5890f91b1d9c92be83ff5d4f2a72bdd2` |
| Author | John Duprey |
| Date | 2026-06-10 14:51:00 -0400 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 313. `e9bc5ad5` — fix: add early template filter when supplied

| Field | Value |
|-------|-------|
| SHA | `e9bc5ad50bce44db439e9d271c37a0ec5b47a5ac` |
| Author | John Duprey |
| Date | 2026-06-10 16:51:47 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `Modules/CIPPCore/Public/Standards/Get-CIPPStandards.ps1`

---

### 314. `8f2198e7` — chore: bump version to 10.5.2

| Field | Value |
|-------|-------|
| SHA | `8f2198e7cf303ec2726066c95a4ebacb55e75f27` |
| Author | John Duprey |
| Date | 2026-06-10 17:02:38 -0400 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `host.json`, `version_latest.txt`

---

### 315. `5a0ddb29` — Dev to hotfix (#2088)

| Field | Value |
|-------|-------|
| SHA | `5a0ddb29c3770525813aefea5e356fc56b088eeb` |
| Author | John Duprey |
| Date | 2026-06-10 17:25:40 -0400 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---
