# n8n Odoo Workflows

This project is maintained in the shared
[`milzamsz/n8n-workflows`](https://github.com/milzamsz/n8n-workflows)
repository under
[`n8n-odoo-workflows/`](https://github.com/milzamsz/n8n-workflows/tree/main/n8n-odoo-workflows).

Phase 8 workflow exports for the Odoo agent platform. All exports are pinned to
n8n `2.30.7`, inactive, and scoped to `ocloud-staging` / company `1` until the
production gate in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) is fully evidenced.

## Workflows

| Export | Owner | Side effect ceiling |
|---|---|---|
| `linkedin-to-crm.v1.json` | CRM Operations | reviewed CRM lead draft |
| `gmail-vendor-invoice.v1.json` | Accounts Payable Operations | reviewed vendor bill draft; never post |
| `bank-statement-intake.v1.json` | Treasury Operations | reviewed suspense import; never reconcile |
| `scheduled-business-briefs.v1.json` | Business Intelligence Operations | allowlisted delivery only |
| `indonesian-tax-working-papers.v1.json` | Tax Operations | reviewed working paper; never submit |

The exports use native n8n Webhook/Schedule, Code, PostgreSQL, HTTP Request,
and standalone MCP Client nodes. PostgreSQL owns durable idempotency, review,
exception, and metadata audit state; external artifacts remain in approved
quarantine/object storage and are referenced by opaque IDs.

## Validate

```bash
python3 tests/verify.py
bash tests/state_machine.sh
N8N_BIN=/path/to/n8n-2.30.7 bash tests/n8n_control_paths.sh
```

With the staging Odoo and authenticated HTTP MCP service running, execute the
five-workflow reconciliation gate with:

```bash
PHASE8_LIVE_ACCEPTANCE=true \
ODOO_MCP_STAGING_URL=http://127.0.0.1:18787/mcp \
N8N_BIN=/path/to/n8n-2.30.7 \
bash tests/n8n_control_paths.sh
```

Import validation against the pinned runtime uses an isolated n8n data folder:

```bash
N8N_USER_FOLDER="$(mktemp -d)" npx --yes n8n@2.30.7 \
  import:workflow --separate --input=workflows
```

After import, bind the credential names from
[`config/credentials.json`](config/credentials.json), run the staging replay
matrix, and only then activate an individually approved workflow.
