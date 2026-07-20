# Phase 8 Production Activation Gate

Status: **UNSIGNED — activation denied**

This document records the remaining production evidence and approvals. It does
not activate a workflow or approve production use. All exports must remain
`active: false` and `productionApproved: false` until this gate is signed and a
separate reviewed activation change is made.

Never place secret values, source documents, extracted payloads, bank details,
tax values, or MCP results in this file. Use credential names and evidence
references only.

## Shared release gate

- [ ] Pinned n8n version, PostgreSQL migration, encrypted storage, least-
  privilege grants, backups, restoration, and monitoring pass in production.
- [ ] Authenticated triggers, atomic idempotency, payload-bound expiring
  single-use approvals, retry classes, uncertain-write handling, and
  metadata-only audit pass with production configuration.
- [ ] MCP manifest/schema compatibility, Odoo ACL, record rules, company scope,
  exact tool ceilings, and postconditions pass.
- [ ] Production security and retention review is approved.
- [ ] Named primary and backup on-call assignments are complete.
- [ ] All applicable accounting and production write-policy approvals below are
  signed.
- [ ] Every imported export is still `active: false` and
  `productionApproved: false`. Evidence: ___ Reviewer: ___

## Production allowlists

Complete only the rows needed by each workflow. Attach the controlled
configuration or secret-manager reference; do not record credentials here.

### Source and filter allowlist

| Workflow | Source identifier | Allowed mechanism | Filter/rule ID | Allowed content/MIME | Company | Config evidence | Approver |
|---|---|---|---|---|---|---|---|
| LinkedIn to CRM | ___ | operator URL / approved export: ___ | ___ | ___ | ___ | ___ | ___ |
| Gmail vendor invoice | mailbox/account ref: ___ | Gmail trigger: ___ | query/label/sender policy: ___ | PDF/JPEG/PNG, 20 MB or stricter: ___ | ___ | ___ | ___ |
| Bank statement intake | bank/channel ref: ___ | approved upload/feed: ___ | account/period/file rule: ___ | approved statement MIME: ___ | ___ | ___ | ___ |
| Scheduled business briefs | schedule/service actor: ___ | pinned schedule: ___ | profile/definition/timezone: ___ | n/a | ___ | ___ | ___ |
| Indonesian tax papers | authenticated request source: ___ | approved request path: ___ | period/rule-source version: ___ | approved evidence types: ___ | ___ | ___ | ___ |

### Account, journal, and destination allowlist

| Workflow | Source account/mailbox | Odoo instance/company | Odoo journal/profile | Destination | Destination scope | Config evidence | Approver |
|---|---|---|---|---|---|---|---|
| LinkedIn to CRM | ___ | ___ | CRM profile: ___ | Odoo CRM only | `crm.lead`, `type=lead` | ___ | ___ |
| Gmail vendor invoice | ___ | ___ | AP profile: ___ | Odoo AP only | draft `account.move`, `in_invoice` | ___ | ___ |
| Bank statement intake | bank account ref: ___ | ___ | bank journal ID/ref: ___ | Odoo bank journal only | fixed journal; unreconciled | ___ | ___ |
| Scheduled business briefs | service actor: ___ | ___ | reporting profile: ___ | channel/address ref: ___ | exact recipient/workspace: ___ | ___ | ___ |
| Indonesian tax papers | source ref: ___ | ___ | tax profile/rule version: ___ | repository/reviewer ref: ___ | working paper only; no filing | ___ | ___ |

Allowlist verification:

- [ ] Trigger input cannot override instance, company, account, journal,
  reporting profile, rule source, or destination.
- [ ] Unknown sources, filters, accounts, journals, and destinations fail closed.
- [ ] Destination changes require a new approval and invalidate prior approval.
- [ ] Test events prove an allowed value succeeds and a mutated value is denied
  for every configured allowlist.

## Credential diagnostics

Record diagnostic result and timestamp, never the secret.

| Credential/reference | Workflow(s) | Least-privilege identity/role | Connectivity/auth test | Expiry/rotation alert | Last diagnostic (UTC) | Evidence |
|---|---|---|---|---|---|---|
| Inbound trigger auth | all applicable | ___ | ___ | ___ | ___ | ___ |
| PostgreSQL | all | ___ | ___ | ___ | ___ | ___ |
| Odoo MCP HTTP auth | all | ___ | ___ | ___ | ___ | ___ |
| LinkedIn extractor/source | LinkedIn | ___ | ___ | ___ | ___ | ___ |
| Gmail | vendor invoice | ___ | ___ | ___ | ___ | ___ |
| Malware scanner/quarantine | vendor invoice, bank | ___ | ___ | ___ | ___ | ___ |
| OCR/extractor | vendor invoice, bank | ___ | ___ | ___ | ___ | ___ |
| Bank source/storage | bank | ___ | ___ | ___ | ___ | ___ |
| Brief destination | scheduled briefs | ___ | ___ | ___ | ___ | ___ |
| Tax rule/evidence service | tax papers | ___ | ___ | ___ | ___ | ___ |
| Alert/notification service | all | ___ | ___ | ___ | ___ | ___ |

- [ ] Credential references match `config/credentials.json`; no secret is
  embedded in an export, environment expression, log, or evidence document.
- [ ] Diagnostics cover DNS/TLS, authentication, authorization, scope, expiry,
  rotation, revocation, rate limit, timeout, and alert delivery.
- [ ] Failure tests prove credentials cannot cross workflows or companies.
- [ ] Backup credentials, if any, have the same or narrower scope and a tested
  controlled failover procedure.

## Named on-call assignments

Use named people or approved paging identities, not team names alone.

| Operational role | Primary on-call | Primary contact/rotation | Backup on-call | Backup contact/rotation | Escalation owner | Acknowledged (UTC) |
|---|---|---|---|---|---|---|
| CRM Operations | ___ | ___ | ___ | ___ | ___ | ___ |
| Accounts Payable Operations | ___ | ___ | ___ | ___ | ___ | ___ |
| Treasury Operations | ___ | ___ | ___ | ___ | ___ | ___ |
| Business Intelligence Operations | ___ | ___ | ___ | ___ | ___ | ___ |
| Tax Operations | ___ | ___ | ___ | ___ | ___ | ___ |
| Platform/Security | ___ | ___ | ___ | ___ | ___ | ___ |

- [ ] Primary and backup can access dashboards, alerts, runbooks, quarantine,
  approval queues, and Odoo records within least privilege.
- [ ] Exception, retry exhaustion, uncertain result, ACL/company denial,
  credential failure, database failure, and manifest drift paging is tested.
- [ ] Handover, absence coverage, severity targets, and escalation timing are
  documented and rehearsed.

## Malware, quarantine, and retention

### Malware and quarantine

- [ ] Gmail and bank artifacts enter quarantine before parsing or extraction.
- [ ] MIME is detected from content, not trusted from filename or headers.
- [ ] File type, size, archive depth, decompression size, encryption, malformed
  document, macro/active-content, and malware policies are approved.
- [ ] Clean scan status is hash-bound to the exact artifact and expires or is
  rescanned when scanner policy/signatures change.
- [ ] Infected, suspicious, unsupported, and scanner-unavailable results fail
  closed; no extractor, Odoo write, or downstream delivery occurs.
- [ ] Quarantine access uses least privilege and produces metadata-only audit.
- [ ] Safe deletion, legal hold, release-from-quarantine, false-positive review,
  and incident escalation procedures are tested.
- [ ] External extractors have an approved no-training/no-retention contract,
  regional/data-processing terms, prompt-injection tests, and deletion evidence.

### Retention schedule

| Data class | Store | Retention | Legal-hold owner | Encryption/access | Deletion verification | Approval |
|---|---|---|---|---|---|---|
| Quarantined source artifacts | ___ | ___ | ___ | ___ | ___ | ___ |
| Clean source artifacts | ___ | ___ | ___ | ___ | ___ | ___ |
| Structured approval payloads | PostgreSQL: ___ | ___ | ___ | ___ | ___ | ___ |
| Idempotency/event metadata | PostgreSQL: ___ | ___ | ___ | ___ | ___ | ___ |
| Metadata-only audit | ___ | ___ | ___ | ___ | ___ | ___ |
| Extractor transient data | external service: ___ | zero/approved: ___ | ___ | ___ | ___ | ___ |
| Briefs and tax working papers | ___ | ___ | ___ | ___ | ___ | ___ |
| Backups | ___ | ___ | ___ | ___ | ___ | ___ |

- [ ] Successful, failed, and manual n8n execution payload persistence is
  disabled; binary data is pruned after controlled quarantine transfer.
- [ ] Retention applies to replicas, backups, caches, logs, exports, and vendor
  systems, with tested deletion and restoration behavior.
- [ ] Audit labels and alerts contain no document text, email addresses, bank
  descriptions, tax values, tool arguments, credentials, or MCP results.

## Accounting and production write-policy approvals

Only three workflows perform bounded Odoo writes. Approval is required
individually; approval of one does not authorize another or any generic tool.
Execute, workflow actions, update, delete, cleanup, post, reconcile, statutory
filing, and unrestricted create remain denied.

### LinkedIn to CRM — `create_crm_lead_draft.v1`

- [ ] Product/CRM approval confirms source policy, evidence quality, duplicate
  handling, reviewer role, correction/archive path, and customer-contact rules.
- [ ] Security approval confirms exact `crm.lead`/`type=lead` mapping, trusted
  company, payload-bound approval, replay denial, and metadata-only audit.
- [ ] Odoo approval confirms ACL/record rules, allowed fields, company/type
  postcondition, and supported version/edition behavior.
- [ ] Accounting approval confirms no journal entry, posting, payment, tax, or
  reconciliation effect.
- [ ] Production write-policy exception authorizes only
  `create_crm_lead_draft.v1`. Evidence: ___ Approver: ___ Date: ___

### Gmail vendor invoice — `prepare_vendor_bill_draft.v1`

- [ ] Product/AP approval confirms mailbox/filter/sender allowlists, evidence
  and discrepancy review, duplicate handling, SLA, and draft correction.
- [ ] Security approval confirms malware/quarantine controls, exact
  `account.move`/`in_invoice` mapping, trusted company, payload-bound approval,
  replay denial, and metadata-only audit.
- [ ] Odoo approval confirms vendor, procurement, tax, fiscal-position, account,
  line mapping, and `draft`/`in_invoice` postconditions.
- [ ] Accounting approval documents the vendor bill, confirms no debit/credit
  effect until a separate human posts in Odoo, and accepts tax, posting,
  cancellation, and correction ownership.
- [ ] Production write-policy exception authorizes only
  `prepare_vendor_bill_draft.v1`. Evidence: ___ Approver: ___ Date: ___

### Bank statement intake — `import_bank_transaction_draft.v1`

- [ ] Product/Treasury approval confirms source/account/journal allowlists,
  duplicate handling, uncertain-result reconciliation, exception SLA, and
  correction/reversal ownership.
- [ ] Security approval confirms malware/quarantine controls, exact bank-line
  mapping, trusted company/journal, payload-bound approval, replay denial, and
  metadata-only audit.
- [ ] Odoo approval confirms supported version/edition behavior, amount and
  currency mapping, external ID, journal/company checks, and postconditions.
- [ ] Accounting approval explicitly accepts Odoo 19 posted-suspense semantics,
  records the debit/credit accounts and period/tax impact, requires
  `is_reconciled=false`, and assigns accountant-controlled reversal/correction.
- [ ] Production write-policy exception authorizes only
  `import_bank_transaction_draft.v1`; match proposals are not reconciliation
  and reconciliation confirmation remains denied. Evidence: ___ Approver: ___
  Date: ___

## Read-only workflow approvals

- [ ] Scheduled business briefs: destination allowlist, definition/version,
  cutoff, currency/state/freshness disclosure, correction/retraction, retention,
  and delivery monitoring are approved. Evidence: ___
- [ ] Indonesian tax working papers: rule source/version, evidence scope,
  reconciliation totals, assumptions, retention, revision/supersession, and
  explicit no-filing boundary are approved. Evidence: ___

## Unsigned release sign-off

Release owner: `milzamsz`

Decision: [ ] APPROVE FOR SEPARATE ACTIVATION CHANGE
[ ] REJECT

Approved workflow names and versions: ___

Conditions/exclusions: ___

Evidence package/version reviewed: ___

I confirm that all required allowlists, credential diagnostics, named primary
and backup on-call assignments, malware/quarantine controls, retention
approvals, and accounting/write-policy decisions are complete. I also confirm
that the reviewed exports remain `active: false` and
`productionApproved: false`; this signature does not itself activate them.

Signature: ____________________________________

Date (UTC): ___________________________________
