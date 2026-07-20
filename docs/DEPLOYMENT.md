# Deployment, Monitoring, and Rollback

## Staging deployment

1. Deploy pinned n8n `2.30.7` with PostgreSQL and encrypted volumes.
2. Set `NODE_FUNCTION_ALLOW_BUILTIN=crypto` and
   `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`; the pinned exports resolve their
   allowlisted endpoint URLs from environment variables. Do not allow external
   Code-node modules or non-endpoint environment values in expressions.
3. Apply `db/001_phase8.sql` with a migration owner, then grant the n8n role
   only `USAGE` and required DML on schema `phase8`.
4. Create the credential references in `config/credentials.json`; never copy
   secret values into exports or Git.
5. Import all exports inactive and bind credentials by name.
6. Set execution retention to metadata-only: do not save successful or failed
   execution payloads, disable manual execution persistence, and prune binary
   data after quarantine transfer.
7. Run duplicate, retry, permanent-error, approval, expiry/mutation, uncertain
   result, and Odoo reconciliation cases in staging.
8. Record evidence and reviewer sign-off per workflow before activation.

## Production gate

Production activation is denied while any `production_approved` flag is false.
Each workflow needs a named human on-call owner, tested credentials, security
review, accounting review where relevant, successful staging replay, and exact
Odoo reconciliation evidence. Production also requires an approved policy
change because the current platform production posture is read-only.

## Monitoring

Alert on:

- exception or uncertain result immediately;
- retry exhaustion immediately;
- approval older than 15 minutes or queue SLA breach;
- duplicate rate above 10% in 15 minutes;
- extraction low-confidence rate above 20% in one hour;
- brief delivery failure or data freshness past cutoff;
- Odoo ACL/company denial;
- workflow inactive, credential diagnostic failure, PostgreSQL unavailable, or
  MCP manifest/schema drift.

Metrics are counts and durations labeled by workflow, result class, and owner;
they never contain document text, email addresses, bank descriptions, tax
values, arguments, or MCP results.

## Replay and rollback

Replay only by event ID from the controlled artifact reference. Automatic
replay stops after three pre-write attempts. Never replay `uncertain` until the
owner reconciles Odoo and records `created`, `not_created`, or `manual_fix`.

Rollback the release by deactivating the affected export, exporting execution
metadata, restoring the previous Git-pinned export, and leaving already-created
Odoo records for the operational owner to correct through standard Odoo states.
Do not delete or reverse accounting records from n8n.
