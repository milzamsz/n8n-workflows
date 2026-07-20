# Repository Guide: n8n-odoo-workflows

This is the `n8n-odoo-workflows/` project folder inside the shared
`milzamsz/n8n-workflows` repository, not an independent repository.

## Mission

Own durable external ingestion, schedules, retries, idempotency, exceptions,
approvals, and notifications for the Odoo agent platform.

## Boundaries

- Call only approved MCP read tools and closed Phase 7 draft mappings.
- Keep all exports inactive until their deployment gate is evidenced.
- Never post accounting entries, confirm reconciliation, file tax returns, or
  invoke generic execute/workflow/delete/cleanup tools.
- Preserve Odoo ACL, record rules, company scope, draft state, provenance, and
  metadata-only audit.
- Store credential references only. Never commit secret values or source
  documents.

## Checks

```bash
python3 tests/verify.py
bash tests/state_machine.sh
npx --yes n8n@2.30.7 import:workflow --separate --input=workflows
```
