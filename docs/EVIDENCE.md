# Phase 8 Evidence

Date: 2026-07-20
Status: **Phase 8 staging gate passed; production activation remains denied**

## Reproducible checks

| Check | Result | Evidence covered |
|---|---|---|
| `node scripts/build_workflows.mjs --check` | PASS | deterministic five-export generation |
| `python3 tests/verify.py` | PASS | JSON/schema loading; Code-node syntax; authenticated triggers; inactive/production-denied flags; exact allowed MCP tools; 2/10/30-second backoff graph with permanent-error bypass; permanent/retryable/uncertain routing; stable replay keys for all five workflows; invalid input rejection; single-use/expired approval fail-closed response path; exact Phase 7 capability keys and fixed Odoo mappings; mutated-key denial; bank unreconciled postcondition |
| `bash tests/state_machine.sh` | PASS | PostgreSQL migration; atomic duplicate claim; payload mutation denial; single-use approval; approval expiry; replay denial; uncertain terminal state; metadata audit trigger |
| n8n `2.30.7 import:workflow --separate --input=workflows` with isolated user folder | PASS, 5/5 imported | pinned native node/export compatibility |
| `N8N_BIN=... bash tests/n8n_control_paths.sh` | PASS | real n8n `2.30.7` + PostgreSQL authenticated webhook execution; permanent rejection; duplicate replay; expired approval denial; 2/10/30-second retry exhaustion; persisted status/error-class assertions |
| `PHASE8_LIVE_ACCEPTANCE=true ODOO_MCP_STAGING_URL=http://127.0.0.1:18787/mcp N8N_BIN=... bash tests/n8n_control_paths.sh` | PASS | authenticated n8n + PostgreSQL + HTTP MCP + Odoo 19 execution; five completed events; zero live-event exceptions; duplicate replay after completion; exact Odoo readback or metric reconciliation |

The transient n8n runtime used only an isolated temporary SQLite user folder;
it did not create repository dependencies or credentials.

## Per-workflow replay matrix

| Workflow | Deterministic duplicate/replay | Permanent validation | Approval | Odoo ceiling/postcondition | Live Odoo reconciliation |
|---|---|---|---|---|---|
| LinkedIn to CRM | PASS | PASS: source URL/mechanism/hash | payload-bound CRM role; consumed once | fixed `crm.lead`, company 1, `type=lead` | PASS: record 58 read back |
| Gmail vendor invoice | PASS | PASS: attachment MIME/size/malware/hash | payload-bound AP role; consumed once | fixed `account.move`, `in_invoice`, `draft`; no post | PASS: record 69 read back |
| Bank statement | PASS | PASS: source MIME/size/journal/period/hash | payload-bound accounting role; consumed once | fixed bank line; posted suspense and `is_reconciled=false` | PASS: record 27 read back |
| Scheduled briefs | PASS by schedule/day/definition | fixed actor/company/profile/timezone/destination | consumed versioned schedule approval ref | reads only; allowlisted delivery | PASS: one delivery, one completed event |
| Indonesian tax papers | PASS | PASS: period/rule/source/hash | payload-bound tax sign-off; consumed once | reads only; submission flag false | PASS: one tax calculation, totals equal |

The live run used deterministic authenticated extractor, matcher, alert,
delivery, and tax-rule test services. It exercised native n8n credential
bindings and the real staging MCP/Odoo boundary without using live customer
documents. Service evidence was `alerts=2`, `briefs=1`, `extracts=3`,
`matches=3`, `tax=1`, and `errors=0`. The three writes were independently read
back through MCP; the brief and tax workflows reconciled their non-Odoo side
effects and stored completed events.

## Review and ownership

`milzamsz` performed the staging approvals and Phase 8 security/accounting
sign-off on 2026-07-20. Operational routing remains explicit per workflow:
CRM Operations, Accounts Payable Operations, Treasury Operations, Business
Intelligence Operations, and Tax Operations.

## Production activation blockers

Phase 8 completion does not authorize production activation. All exports remain
`active: false` and `productionApproved: false`. Production still requires:

- real source/filter/account/destination allowlist and credential diagnostics;
- malware/quarantine and extractor retention/security tests where applicable;
- named primary and backup on-call assignments for each operational role;
- production retention/security and accounting approval;
- approved production write-policy change for the three draft workflows.
