# Manage365 v1 API — end of life

This repository is the backend half of Manage365 v1, the two-repo install. The last release here tracks CIPP **10.8.5** (Manage365 **v5.33.0**).

Production has moved to the monorepo [Celeratec/Manage365](https://github.com/Celeratec/Manage365), release **6.1.3**, CIPP baseline **11.0.2**. Frontend and backend deploy as one Linux container. Do not deploy this repository. New work belongs in Manage365.

The production cutover has already been run. The storage account, tables, blobs, queues, and Key Vault stayed. The Function Apps and the Static Web App were removed.

- Migration notes: [Monorepo migration](https://github.com/Celeratec/Manage365/blob/main/docs/upstream-sync/MONOREPO_MIGRATION_20260815.md)
- Cutover record: [cutover runbook](https://github.com/Celeratec/Manage365/blob/main/docs/upstream-sync/CUTOVER_RUNBOOK_20260815.md)
- Frontend half of v1: [Celeratec/CIPP](https://github.com/Celeratec/CIPP), also end of life
