import { createHash } from 'node:crypto';
import { createServer } from 'node:http';

const port = Number(process.env.PHASE8_TEST_SERVICE_PORT || 15680);
const evidence = { alerts: 0, briefs: 0, extracts: 0, matches: 0, tax: 0, errors: [] };
const stable = value => Array.isArray(value)
  ? `[${value.map(stable).join(',')}]`
  : value && typeof value === 'object'
    ? `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stable(value[key])}`).join(',')}}`
    : JSON.stringify(value);
const key = (prefix, value) => `${prefix}:v1:${createHash('sha256').update(stable(value)).digest('hex')}`;
const rows = body => (body.odoo || []).flatMap(result => result.records || []);
const reply = (response, status, body = {}) => {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
};

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1_000_000) throw new Error('payload_too_large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

function linkedinExtract(event) {
  const evidenceRefs = [event.artifact_ref];
  return {
    extraction: {
      organization: { value: 'Acme Corporation', confidence: 1, evidence_refs: evidenceRefs },
      person: { value: null, confidence: 1, evidence_refs: evidenceRefs },
      stated_need: { value: 'Requested a staging follow-up', confidence: 1, evidence_refs: evidenceRefs },
      location: { value: null, confidence: 1, evidence_refs: evidenceRefs },
      facts: ['Organization stated in approved test source', 'Follow-up explicitly requested'],
      inferences: [],
    },
  };
}

function linkedinMatch(body) {
  const event = body.event;
  const partner = rows(body).find(record => record.name === 'Acme Corporation');
  const token = event.artifact_ref.split('/').at(-1);
  const payload = {
    title: `Phase 8 live lead ${token}`,
    organization: 'Acme Corporation', contact_name: null, email: null, phone: null,
    description: 'Requested a staging follow-up.', evidence_ref: event.artifact_ref,
  };
  payload.idempotency_key = key('crm-lead', {
    capability: 'create_crm_lead_draft.v1', instance_id: 'ocloud-staging', company_id: 1, ...payload,
  });
  return {
    duplicates: { partner_candidates: partner ? [partner] : [], lead_candidates: [], match_explanation: 'Exact approved organization-name search; no exact lead title existed.' },
    review: { state: 'pending', owner: 'CRM Operations' }, capability_payload: payload,
  };
}

function gmailExtract(event) {
  const ref = `P8-${event.source.message_id}`.slice(0, 100);
  const field = value => ({ value, confidence: 1, evidence_ref: event.artifact_ref });
  return {
    extraction: {
      vendor_name: field('Acme Corporation'), vendor_reference: field(ref),
      invoice_date: field('2026-07-20'), due_date: field(null), currency: field('USD'),
      subtotal_minor: field(10000), tax_minor: field(0), total_minor: field(10000),
      lines: [{ description: 'Phase 8 live services', quantity_milli: 1000, unit_price_minor: 10000, confidence: 1, evidence_ref: event.artifact_ref }],
    },
  };
}

function gmailMatch(body) {
  const records = rows(body);
  const partner = records.find(record => record.name === 'Acme Corporation' && Object.hasOwn(record, 'supplier_rank'));
  const company = records.find(record => record.id === 1 && Object.hasOwn(record, 'currency_id') && !Object.hasOwn(record, 'move_type'));
  const account = records.find(record => ['expense', 'expense_direct_cost'].includes(record.account_type));
  if (!partner || !company || !account) throw new Error('missing_odoo_invoice_reference');
  const event = body.event;
  const extraction = body.extraction.extraction;
  const payload = {
    partner_id: partner.id, currency_id: company.currency_id[0], invoice_date: extraction.invoice_date.value,
    due_date: null, payment_term_id: null, vendor_reference: extraction.vendor_reference.value,
    lines: [{ product_id: null, account_id: account.id, uom_id: null, description: 'Phase 8 live services', quantity_milli: 1000, unit_price_minor: 10000, tax_ids: [] }],
    evidence_refs: [event.artifact_ref], purchase_order_refs: [], receipt_refs: [], discrepancies: ['No purchase order supplied for staging acceptance'],
  };
  payload.idempotency_key = key('vendor-bill', {
    capability: 'prepare_vendor_bill_draft.v1', instance_id: 'ocloud-staging', company_id: 1, ...payload,
  });
  return {
    resolution: { company_id: 1, vendor_id: partner.id, duplicate_vendor_reference: false },
    matching: { purchase_orders: [], receipts: [], discrepancies: payload.discrepancies },
    review: { state: 'pending', owner: 'Accounts Payable Operations', posting_allowed: false },
    capability_payload: payload,
  };
}

function bankExtract(event) {
  const token = event.artifact_ref.split('/').at(-1);
  return {
    statement: { journal_id: 6 },
    lines: [{ external_transaction_id: `P8-${token}`, normalized_description: 'Acme Corporation', amount_minor: 12345 }],
  };
}

function bankMatch(body) {
  const event = body.event;
  const line = body.extraction.lines[0];
  const partner = rows(body).find(record => record.name === 'Acme Corporation');
  const payload = {
    journal_id: 6, transaction_date: '2026-07-20', payment_reference: `Phase 8 ${line.external_transaction_id}`,
    amount_minor: line.amount_minor, partner_id: partner?.id ?? null,
    foreign_currency_id: null, amount_currency_minor: null,
    external_transaction_id: line.external_transaction_id,
    evidence_refs: [event.artifact_ref], discrepancies: [],
  };
  payload.idempotency_key = key('bank-transaction', {
    capability: 'import_bank_transaction_draft.v1', instance_id: 'ocloud-staging', company_id: 1, ...payload,
  });
  return {
    lines: [{ ...line, classification: partner ? 'one_to_one' : 'unmatched', confidence: partner ? 1 : 0, evidence_refs: [event.artifact_ref], candidates: partner ? [partner] : [] }],
    review: { state: 'pending', owner: 'Treasury Operations', reconciliation_confirmation_allowed: false },
    capability_payload: payload,
  };
}

function taxPaper(body) {
  const records = rows(body);
  const total = Math.round(records.reduce((sum, record) => sum + Number(record.amount_tax || 0), 0) * 100);
  return {
    rule_version: body.request.rule_version,
    calculation: [{ tax_object: 'PPN staging evidence', dpp_minor: total, rate_basis_points: 0, tax_minor: total, responsibility: 'Tax Operations', evidence_refs: body.request.transaction_refs, assumptions: ['Read-only staging reconciliation'] }],
    reconciliation: { odoo_total_minor: total, working_paper_total_minor: total, difference_minor: 0, missing_documents: [], exceptions: [] },
  };
}

createServer(async (request, response) => {
  try {
    if (request.method === 'GET' && request.url === '/health') return reply(response, 200, { status: 'ok' });
    if (request.method === 'GET' && request.url === '/evidence') return reply(response, 200, evidence);
    if (request.headers['x-phase8-test'] !== 'phase8-test') return reply(response, 401, { error: 'unauthorized' });
    const body = await readJson(request);
    if (request.url === '/alert') { evidence.alerts += 1; return reply(response, 200, { accepted: true }); }
    if (request.url === '/brief-delivery') { evidence.briefs += 1; return reply(response, 202, { accepted: true }); }
    if (request.url === '/tax-rules') { evidence.tax += 1; return reply(response, 200, taxPaper(body)); }
    if (body.artifact_ref?.endsWith('/retry')) return reply(response, 503, { error: 'retryable_test_failure' });
    if (request.url?.endsWith('/extract/v1')) {
      evidence.extracts += 1;
      if (request.url.includes('linkedin-to-crm')) return reply(response, 200, linkedinExtract(body));
      if (request.url.includes('gmail-vendor-invoice')) return reply(response, 200, gmailExtract(body));
      if (request.url.includes('bank-statement-intake')) return reply(response, 200, bankExtract(body));
    }
    if (request.url?.endsWith('/match/v1')) {
      evidence.matches += 1;
      if (request.url.includes('linkedin-to-crm')) return reply(response, 200, linkedinMatch(body));
      if (request.url.includes('gmail-vendor-invoice')) return reply(response, 200, gmailMatch(body));
      if (request.url.includes('bank-statement-intake')) return reply(response, 200, bankMatch(body));
    }
    return reply(response, 404, { error: 'not_found' });
  } catch (error) {
    evidence.errors.push({ url: request.url, message: String(error.message || error) });
    return reply(response, 422, { error: String(error.message || error) });
  }
}).listen(port, '127.0.0.1');
