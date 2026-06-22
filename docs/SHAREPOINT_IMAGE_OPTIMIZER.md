# SharePoint Image Optimizer

Tenant-scoped tool that helps MSP admins reduce SharePoint Online storage consumed by
oversized JPG/JPEG images. It can audit large images, compress them server-side, replace the
original file, and (optionally) remove old file versions so the space is actually reclaimed.

> **Frontend:** Teams & SharePoint → SharePoint → **Image Optimizer**
> (`/teams-share/sharepoint/image-optimizer`)
> **Backend:** PowerShell Azure Functions in `Modules/CIPPHTTP/.../Teams-Sharepoint/` and helpers
> in `Modules/CIPPCore/Public/SharePoint/Image Optimizer/`.

---

## 1. Purpose

Large, un-optimized JPGs (camera originals, marketing assets, scanned documents) frequently
dominate SharePoint storage. This feature lets an admin find those files in a specific document
library and shrink them with a conservative, auditable, opt-in workflow.

## 2. What it does

- **Audit** — recursively scans a document library (drive) for `.jpg` / `.jpeg` files at or above
  a size threshold and reports each candidate.
- **Compress** — downloads each eligible JPG, re-encodes it server-side at a configurable quality,
  compares sizes, and (when not a dry run) uploads the smaller copy over the original.
- **Version cleanup** (optional, destructive) — after a successful compression, removes old file
  versions so version history stops holding the original large bytes.
- **Reports** per-file and summary results, exportable to CSV/JSON.

## 3. What it does **not** do

- It does not process non-JPG files. Only `.jpg` / `.jpeg` (case-insensitive).
- It does not upload a result that is larger than the original, or that fails the minimum savings
  threshold.
- It does not modify any file or delete any version while **Dry run (WhatIf)** is enabled.
- It does not delete the current/latest version of a file — only previous versions.
- It does not empty the site recycle bin. Recycled versions still occupy storage until the recycle
  bin is purged or its retention expires.
- It does not preserve EXIF/metadata. Re-encoding removes it (see limitations).
- It is **not** intended for source/archival photography libraries without client approval.

## 4. Storage warning about version history

**Replacing a JPG does not immediately reclaim SharePoint storage.** When versioning is enabled
(the default for most libraries), uploading a compressed copy creates a new version while the
previous, larger version is retained. Real storage savings require either:

1. Deleting old versions (this tool's version cleanup), **and/or**
2. Waiting for the recycle bin / version retention to expire.

Use **Compress and delete old versions** with the **permanent** cleanup mode to reclaim space
immediately, understanding it is not recoverable.

## 5. Recommended settings

| Setting | Recommended | Notes |
|---|---|---|
| Mode | `Audit only` first | Always preview before changing data. |
| Dry run (WhatIf) | `On` for the first compress run | Confirms savings before writing. |
| File size threshold | `5 MB` | Raise for libraries with many medium images. |
| JPEG quality | `82` | Range 60–95. 80–85 is visually near-lossless for most photos. |
| Minimum savings % | `15%` | Skips files that barely shrink. |
| Strip EXIF metadata | `On` | Smaller files; removes camera/GPS metadata. |
| Version cleanup | `Recycle` | Recoverable. Use `Permanent` only when space must be reclaimed now. |
| Max files | set a cap on first live run | Limits blast radius / throttling. |

Equivalent ImageMagick intent (for reference): `magick input.jpg -strip -interlace Plane -sampling-factor 4:2:0 -quality 82 output.jpg`.

## 6. Permissions

The feature reuses CIPP's existing SAM permissions — **no new SAMManifest entries are required**.
Capabilities used (least privilege that satisfies the operations):

| Operation | API | Permission (already in `SAMManifest.json`) |
|---|---|---|
| List sites / drives, read items, read versions | Microsoft Graph (app-only) | `Sites.Read.All` (Role) |
| Download & overwrite file content | Microsoft Graph (app-only) | `Files.ReadWrite.All` / `Sites.ReadWrite.All` (Role) |
| Delete/recycle old file versions | **SharePoint REST** `_api/web/GetFileById(...)/versions/...` (**delegated**) | `AllSites.FullControl` (Scope) on SharePoint Online (`00000003-0000-0ff1-ce00-000000000000`) |

### Why version cleanup uses SharePoint REST (delegated), not Graph

Microsoft Graph officially supports **list / get / download / restore** of `driveItemVersion`,
but **does not officially support deleting a specific version** (the unofficial
`DELETE /drives/{id}/items/{id}/versions/{id}` is not supported and is unreliable). The supported,
reliable mechanism is the SharePoint REST file-versions API:

```
POST {siteUrl}/_api/web/GetFileById('{uniqueId}')/versions/recycleAll()   # recycle (recoverable)
POST {siteUrl}/_api/web/GetFileById('{uniqueId}')/versions/deleteAll()     # permanent (reclaims now)
```

Per the CIPP `sharepoint-api-auth` convention, site-level `_api/web/*` is **delegated-only**
(no `-AsApp`); the SAM refresh token is used with scope `{SharePointUrl}/.default`.

If the app/account lacks the delegated permission, **compression can still succeed while version
cleanup fails** — the UI surfaces this with a per-file status of
`Compressed, version cleanup failed` and a permission warning banner.

## 7. Known limitations

- Version cleanup may be blocked by **retention policies, retention labels, legal hold, or
  insufficient permissions**. Those files report an error and are skipped, without aborting the run.
- **Recycle-bin deletion does not immediately reclaim storage** until the recycle bin retention
  clears or the recycle bin is emptied. Only `permanent` (`deleteAll`) reclaims immediately.
- **Compression strips EXIF metadata** when enabled, removing camera, GPS, and creation metadata.
  "Preserve modified metadata" is intentionally disabled — re-encoding cannot preserve it safely.
- **Some already-optimized JPGs will not shrink** and are skipped by the minimum-savings rule.
- This feature should not be run against **source/archival photography libraries** without client
  approval.
- The image engine requires **SkiaSharp** (preferred) or **System.Drawing.Common** (Windows-only
  fallback) to be available in the Function runtime. See *Image engine deployment* below.

### Image engine deployment

`Compress-CIPPImage` tries, in order:

1. **SkiaSharp** — cross-platform. If the `SkiaSharp.dll` (plus its native runtime asset) is
   bundled with the Function app it is loaded automatically; this is the recommended engine for
   Linux/container hosting.
2. **System.Drawing.Common** — built into the runtime but **only supported on Windows**. Acts as a
   zero-dependency fallback on the standard Windows Functions plan.

If neither is available the affected files return `Failed` with a clear engine-unavailable error;
no data is modified.

## 8. Throttling guidance

- Graph reads/writes use `New-GraphGetRequest` / `New-GraphPOSTRequest`, which already retry on
  HTTP 429/503 with backoff and honor `Retry-After`.
- File download/upload (`Invoke-RestMethod`) is wrapped in an exponential-backoff retry for
  429/503.
- Audit lists pages of 200 items and follows `@odata.nextLink` automatically.
- Use **Max files** and the per-run hard cap (500) to keep batches small. For very large
  libraries, run in batches rather than all at once.

## 9. Retention / records management warning

Deleting old versions changes recovery expectations. If a library is subject to retention policies,
retention labels, or legal hold, version deletion may be **blocked** (reported per file) or may
**conflict with compliance requirements**. Confirm with the client's records-management policy
before using `permanent` cleanup. The current version is always preserved.

## 10. Test plan

### Automated (Pester)

`Tests/Endpoint/Invoke-SharePointImageOptimizer.Tests.ps1` covers:

1. Audit returns only `.jpg` / `.jpeg`.
2. Files below the threshold are skipped.
3. WhatIf does not upload or delete versions.
4. A compressed result larger than the original is skipped.
5. Minimum savings percent is respected.
6. Version cleanup never deletes the current version.
7. Throttling retry behavior (`Invoke-CIPPImageHttpWithRetry`).
8. Permission failure returns a clear per-file error.
9. Empty library returns a successful empty result.

Run: `Invoke-Pester -Path Tests/Endpoint/Invoke-SharePointImageOptimizer.Tests.ps1 -Output Detailed`

### Manual smoke test

1. Create a test SharePoint site and document library.
2. Upload several large JPGs (> threshold).
3. Enable versioning on the library.
4. Upload multiple versions of at least one JPG.
5. Run **Audit only** — confirm only large JPGs are listed.
6. Run **Compress only** with **Dry run = on** — confirm projected savings, no changes.
7. Run **Compress only** with **Dry run = off** — confirm file is smaller and opens correctly.
8. Confirm old versions still exist (cleanup not selected).
9. Run **Compress and delete old versions** on the test file(s).
10. Confirm old versions are removed per the selected cleanup mode (recycle vs permanent).
11. Confirm storage behavior; document any recycle-bin delay for `recycle` mode.

## Result shape

```json
{
  "Tenant": "contoso.onmicrosoft.com",
  "SiteUrl": "https://contoso.sharepoint.com/sites/Marketing",
  "Library": "Documents",
  "Mode": "CompressAndCleanup",
  "WhatIf": false,
  "Summary": {
    "FilesScanned": 1200,
    "EligibleFiles": 83,
    "FilesCompressed": 80,
    "FilesSkipped": 3,
    "OriginalBytes": 987654321,
    "CompressedBytes": 296296296,
    "EstimatedSavingsBytes": 691358025,
    "VersionsDeleted": 240,
    "Errors": 0
  },
  "Results": [
    {
      "FileName": "example.jpg",
      "WebUrl": "https://contoso.sharepoint.com/sites/Marketing/Documents/example.jpg",
      "DriveItemId": "01ABC...",
      "DriveId": "b!xyz...",
      "OriginalBytes": 10485760,
      "CompressedBytes": 3145728,
      "SavingsBytes": 7340032,
      "SavingsPercent": 70.0,
      "VersionCountBefore": 12,
      "VersionsDeleted": 11,
      "Status": "Compressed and versions cleaned",
      "Error": null
    }
  ],
  "Warnings": []
}
```

### Per-file statuses

`Found`, `Skipped: below threshold`, `Skipped: compression savings too small`,
`Skipped: locked`, `Compressed`, `Compressed, version cleanup failed`,
`Compressed and versions cleaned`, `Failed`.

## Endpoints

| Endpoint | Method | Role | Purpose |
|---|---|---|---|
| `/api/ListSites` (existing) | GET | `Sharepoint.Site.Read` | Site picker |
| `/api/ListSharePointDocumentLibraries` | GET | `Sharepoint.Site.Read` | Library picker |
| `/api/ListSharePointImageCandidates` | GET/POST | `Sharepoint.Site.Read` | Standalone audit (read-only) |
| `/api/ExecSharePointImageOptimize` | POST | `Sharepoint.Site.ReadWrite` | Combined job: Audit / Compress / CompressAndCleanup |
| `/api/ExecSharePointImageVersionCleanup` | POST | `Sharepoint.Site.ReadWrite` | Standalone version cleanup for selected files |
