# Phase 8 Security and Accounting Review

Date: 2026-07-20
Decision: **approved for Phase 8 staging acceptance by `milzamsz`; production denied**

## Security

- Authenticated inbound triggers and dedicated credential references.
- Fixed staging instance/company/profile; Odoo ACL and record rules remain authoritative.
- Atomic PostgreSQL idempotency and payload-bound, expiring, single-use approvals.
- MIME/size/source/malware gates before document extraction.
- Bounded retries; possible-write timeouts become non-retryable `uncertain`.
- Execution payload persistence disabled; audit metadata allowlist only.
- No execute, workflow action, update, delete, cleanup, post, reconcile, or file tools.
- All workflow exports remain inactive and production flags false.

Residual staging risk: structured review payloads contain business data and
require encrypted PostgreSQL storage, strict role grants, retention approval,
and backup controls. External extraction requires a no-retention contract and
prompt-injection testing before live documents are used.

## Accounting

| Workflow | Operational document | Posting/debit-credit effect | Reconciliation | Correction |
|---|---|---|---|---|
| LinkedIn | CRM lead draft | none | source ref/company/type | edit/archive in Odoo |
| Vendor invoice | vendor bill draft | none until a separate human posts in Odoo | vendor ref/partner/company/state | edit/cancel draft in Odoo |
| Bank | Odoo 19 bank line | posted suspense entry; accounts depend on configured journal | must remain `is_reconciled=false` | accountant reversal/correction in Odoo |
| Brief | delivered report | none | business-definition query and cutoff | retract and issue corrected brief |
| Tax paper | analysis artifact | none | Odoo total vs paper total/difference | superseding revision |

No autonomous posting, reconciliation confirmation, or statutory submission is
present. The live Odoo 19 test confirmed the configured journal produces a
posted suspense entry that remains `is_reconciled=false`; this staging behavior
is accepted by `milzamsz` for Phase 8.

## Staging evidence reviewed

- pinned n8n 2.30.7 import and native-node execution;
- authenticated staging triggers, credential bindings, and HTTP MCP transport;
- duplicate, retry exhaustion, permanent exception, expired approval, mutation,
  single-use approval, and replay controls;
- exact Odoo readback for CRM record 58, vendor bill 69, and bank line 27;
- one brief delivery and one tax calculation with reconciled totals;
- operational role routing, with staging reviewer/approver `milzamsz`.

Production requires separate named on-call assignments, real external-source
credential/retention diagnostics, and the explicit production write-policy
change. The inactive and production-denied flags enforce that boundary.
