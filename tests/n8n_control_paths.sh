#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N8N_BIN="${N8N_BIN:?set N8N_BIN to the pinned n8n 2.30.7 executable}"
N8N_PORT="${PHASE8_TEST_N8N_PORT:-15678}"
SERVICE_PORT="${PHASE8_TEST_SERVICE_PORT:-15680}"
PG_PORT=15439
PG_CONTAINER="phase8-n8n-control-$$"
N8N_DIR="$(mktemp -d /tmp/phase8-n8n-control.XXXXXX)"
N8N_PID=
SERVICE_PID=

cleanup() {
  local status=$?
  if [[ $status -ne 0 && -n "$SERVICE_PID" ]]; then curl -fsS "http://127.0.0.1:${SERVICE_PORT}/evidence" || true; fi
  if [[ $status -ne 0 ]] && docker ps --format '{{.Names}}' | grep -qx "$PG_CONTAINER"; then
    docker exec "$PG_CONTAINER" psql -x -U phase8 -d phase8 -c \
      "SELECT e.workflow,e.artifact_ref,e.status,x.error_class,x.reason_code FROM phase8.events e LEFT JOIN phase8.exceptions x USING(idempotency_key) ORDER BY e.created_at DESC LIMIT 8" || true
  fi
  if [[ $status -ne 0 && -f "$N8N_DIR/n8n.log" ]]; then cat "$N8N_DIR/n8n.log"; fi
  if [[ -n "$N8N_PID" ]]; then kill "$N8N_PID" 2>/dev/null || true; fi
  if [[ -n "$SERVICE_PID" ]]; then kill "$SERVICE_PID" 2>/dev/null || true; fi
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  if [[ "${PHASE8_KEEP_TEST_STATE:-false}" == true ]]; then
    printf 'kept failed n8n state at %s\n' "$N8N_DIR"
  else
    rm -rf "$N8N_DIR"
  fi
}
trap cleanup EXIT

docker run -d --name "$PG_CONTAINER" -p "127.0.0.1:${PG_PORT}:5432" \
  -e POSTGRES_DB=phase8 -e POSTGRES_USER=phase8 -e POSTGRES_PASSWORD=phase8-test \
  postgres:17-alpine >/dev/null
for _ in {1..30}; do
  docker exec "$PG_CONTAINER" pg_isready -U phase8 -d phase8 >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$PG_CONTAINER" pg_isready -U phase8 -d phase8 >/dev/null
docker exec -i "$PG_CONTAINER" psql -v ON_ERROR_STOP=1 -U phase8 -d phase8 < "$ROOT/db/001_phase8.sql" >/dev/null

export N8N_USER_FOLDER="$N8N_DIR"
export N8N_ENCRYPTION_KEY=phase8-control-path-test-only
export N8N_DIAGNOSTICS_ENABLED=false
export N8N_PORT
export N8N_HOST=127.0.0.1
export N8N_PROTOCOL=http
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false
export NODE_FUNCTION_ALLOW_BUILTIN=crypto
export PHASE8_EXTRACTOR_URL="http://127.0.0.1:${SERVICE_PORT}"
export PHASE8_ALERT_URL="http://127.0.0.1:${SERVICE_PORT}/alert"
export PHASE8_TAX_RULES_URL="http://127.0.0.1:${SERVICE_PORT}/tax-rules"
export PHASE8_BRIEF_DELIVERY_URL="http://127.0.0.1:${SERVICE_PORT}/brief-delivery"
export ODOO_MCP_STAGING_URL="${ODOO_MCP_STAGING_URL:-http://127.0.0.1:9/mcp}"
export PHASE8_TEST_SERVICE_PORT="$SERVICE_PORT"

node "$ROOT/tests/phase8_test_services.mjs" &
SERVICE_PID=$!
for _ in {1..30}; do
  curl -fsS "http://127.0.0.1:${SERVICE_PORT}/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${SERVICE_PORT}/health" >/dev/null

"$N8N_BIN" import:credentials --input="$ROOT/tests/fixtures/n8n-local-credentials.json" >/dev/null
"$N8N_BIN" import:workflow --separate --input="$ROOT/workflows" >/dev/null
while IFS= read -r workflow_id; do
  "$N8N_BIN" publish:workflow --id="$workflow_id" >/dev/null
done < <("$N8N_BIN" list:workflow --onlyId)
[[ "$("$N8N_BIN" list:workflow --active=true --onlyId | wc -l)" -eq 5 ]]
export N8N_LOG_LEVEL="${PHASE8_TEST_LOG_LEVEL:-error}"
"$N8N_BIN" start >"$N8N_DIR/n8n.log" 2>&1 &
N8N_PID=$!
for _ in {1..60}; do
  curl -fsS "http://127.0.0.1:${N8N_PORT}/healthz" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${N8N_PORT}/healthz" >/dev/null
for _ in {1..60}; do
  webhook_status="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
    "http://127.0.0.1:${N8N_PORT}/webhook/phase8/linkedin-to-crm/v1")"
  [[ "$webhook_status" != 404 ]] && break
  sleep 1
done
[[ "$webhook_status" != 404 ]]

request() {
  local expected=$1 path=$2 body=$3 output status
  output="$(mktemp "$N8N_DIR/response.XXXXXX")"
  status="$(curl -sS -o "$output" -w '%{http_code}' -H 'X-Phase8-Test: phase8-test' \
    -H 'Content-Type: application/json' --data "$body" "http://127.0.0.1:${N8N_PORT}${path}")"
  [[ "$status" == "$expected" ]] || { printf 'expected HTTP %s, got %s: ' "$expected" "$status"; cat "$output"; return 1; }
}

invalid='{"artifact_ref":"artifact://linkedin/invalid","content_hash":"bad","source":{}}'
request 422 /webhook/phase8/linkedin-to-crm/v1 "$invalid"
request 200 /webhook/phase8/linkedin-to-crm/v1 "$invalid"

docker exec "$PG_CONTAINER" psql -v ON_ERROR_STOP=1 -U phase8 -d phase8 -c \
  "INSERT INTO phase8.events(idempotency_key,workflow,schema_version,correlation_id,content_hash,artifact_ref,status,owner) VALUES ('expired-approval','id.tax_working_paper_requested.v1','1.0','11111111-1111-4111-8111-111111111111','sha256:0000000000000000000000000000000000000000000000000000000000000000','artifact://tax/expired','review_pending','Tax Operations'); INSERT INTO phase8.approvals(approval_id,idempotency_key,capability,payload_hash,payload,reviewer_role,state,expires_at) VALUES ('22222222-2222-4222-8222-222222222222','expired-approval','id_tax_working_paper_signoff.v1','sha256:0000000000000000000000000000000000000000000000000000000000000000','{}','tax_manager','pending',now()-interval '1 minute');" >/dev/null
approval='{"approval_id":"22222222-2222-4222-8222-222222222222","decision":"approved","reviewer_id":"phase8-test-reviewer","payload_hash":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}'
request 409 /webhook/phase8/indonesian-tax-working-papers/v1/approval "$approval"

valid='{"artifact_ref":"artifact://linkedin/retry","content_hash":"sha256:1111111111111111111111111111111111111111111111111111111111111111","source":{"url":"https://www.linkedin.com/posts/retry","capture_mechanism":"operator_url","captured_at":"2026-07-20T00:00:00Z","provenance":"operator:phase8-test"}}'
request 503 /webhook/phase8/linkedin-to-crm/v1 "$valid"

sql() { docker exec "$PG_CONTAINER" psql -Atq -U phase8 -d phase8 -c "$1"; }
expect_sql() {
  local label=$1 expected=$2 query=$3 actual
  actual="$(sql "$query")"
  [[ "$actual" == "$expected" ]] || { printf '%s: expected %s, got %s\n' "$label" "$expected" "$actual"; return 1; }
}
expect_sql invalid-replay-count 1 "SELECT count(*) FROM phase8.events WHERE artifact_ref='artifact://linkedin/invalid'"
expect_sql invalid-class exception:permanent "SELECT e.status || ':' || x.error_class FROM phase8.events e JOIN phase8.exceptions x USING(idempotency_key) WHERE e.artifact_ref='artifact://linkedin/invalid'"
expect_sql retry-class exception:retryable "SELECT e.status || ':' || x.error_class FROM phase8.events e JOIN phase8.exceptions x USING(idempotency_key) WHERE e.artifact_ref='artifact://linkedin/retry'"
expect_sql expired-approval review_pending:pending "SELECT e.status || ':' || a.state FROM phase8.events e JOIN phase8.approvals a USING(idempotency_key) WHERE e.idempotency_key='expired-approval'"

printf 'n8n control paths: permanent/duplicate/expired-approval/retry-exhaustion PASS\n'

if [[ "${PHASE8_LIVE_ACCEPTANCE:-false}" == true ]]; then
  token="$(date +%s)"

  approve() {
    local slug=$1 artifact=$2 model=$3 idempotency approval_id payload_hash body
    idempotency="$(sql "SELECT idempotency_key FROM phase8.events WHERE artifact_ref='$artifact'")"
    approval_id="$(sql "SELECT approval_id FROM phase8.approvals WHERE idempotency_key='$idempotency'")"
    payload_hash="$(sql "SELECT payload_hash FROM phase8.approvals WHERE idempotency_key='$idempotency'")"
    [[ -n "$approval_id" && -n "$payload_hash" ]]
    body="$(printf '{"approval_id":"%s","decision":"approved","reviewer_id":"milzamsz","payload_hash":"%s"}' "$approval_id" "$payload_hash")"
    request 200 "/webhook/phase8/${slug}/v1/approval" "$body"
    if [[ -n "$model" ]]; then
      expect_sql "$slug" "completed:$model" "SELECT status || ':' || odoo_model FROM phase8.events WHERE idempotency_key='$idempotency'"
    else
      expect_sql "$slug" completed "SELECT status FROM phase8.events WHERE idempotency_key='$idempotency'"
    fi
  }

  linkedin_artifact="artifact://linkedin/live-$token"
  linkedin="$(printf '{"artifact_ref":"%s","content_hash":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","source":{"url":"https://www.linkedin.com/posts/live-%s","capture_mechanism":"operator_url","captured_at":"2026-07-20T00:00:00Z","provenance":"operator:milzamsz"}}' "$linkedin_artifact" "$token")"
  request 202 /webhook/phase8/linkedin-to-crm/v1 "$linkedin"
  approve linkedin-to-crm "$linkedin_artifact" crm.lead
  request 200 /webhook/phase8/linkedin-to-crm/v1 "$linkedin"

  gmail_artifact="artifact://gmail/live-$token"
  gmail="$(printf '{"artifact_ref":"%s","content_hash":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","source":{"mailbox":"ap@example.com","sender":"vendor@example.com","message_id":"live-%s","filter_ref":"secret://n8n/gmail/vendor-invoice-filter","attachments":[{"mime_type":"application/pdf","size_bytes":1024,"malware_status":"clean","content_hash":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}]}}' "$gmail_artifact" "$token")"
  request 202 /webhook/phase8/gmail-vendor-invoice/v1 "$gmail"
  approve gmail-vendor-invoice "$gmail_artifact" account.move
  request 200 /webhook/phase8/gmail-vendor-invoice/v1 "$gmail"

  bank_artifact="artifact://bank/live-$token"
  bank="$(printf '{"artifact_ref":"%s","content_hash":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","source":{"source_id":"bank-portal","account_map_ref":"secret://n8n/bank/account-map","filename":"live-%s.csv","mime_type":"text/csv","size_bytes":2048},"statement":{"journal_id":6,"account_last4":"1234","currency":"USD","period_start":"2026-07-01","period_end":"2026-07-20"}}' "$bank_artifact" "$token")"
  request 202 /webhook/phase8/bank-statement-intake/v1 "$bank"
  approve bank-statement-intake "$bank_artifact" account.bank.statement.line
  request 200 /webhook/phase8/bank-statement-intake/v1 "$bank"

  tax_artifact="artifact://tax/live-$token"
  tax="$(printf '{"artifact_ref":"%s","content_hash":"sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","request":{"tax_period":"2026-06","rule_version":"PPN-v1","rule_source_ref":"rules://id/ppn/v1","transaction_refs":["odoo://account.move/1"],"document_refs":[]}}' "$tax_artifact")"
  request 202 /webhook/phase8/indonesian-tax-working-papers/v1 "$tax"
  approve indonesian-tax-working-papers "$tax_artifact" ''
  request 200 /webhook/phase8/indonesian-tax-working-papers/v1 "$tax"

  request 200 /webhook/phase8/scheduled-business-briefs/v1/replay '{}'
  expect_sql scheduled-business-brief completed "SELECT status FROM phase8.events WHERE artifact_ref LIKE 'schedule://daily-management/%'"
  request 200 /webhook/phase8/scheduled-business-briefs/v1/replay '{}'

  service_evidence="$(curl -fsS "http://127.0.0.1:${SERVICE_PORT}/evidence")"
  [[ "$(printf '%s' "$service_evidence" | jq -r '.briefs')" -eq 1 ]]
  [[ "$(printf '%s' "$service_evidence" | jq -r '.extracts')" -eq 3 ]]
  [[ "$(printf '%s' "$service_evidence" | jq -r '.matches')" -eq 3 ]]
  [[ "$(printf '%s' "$service_evidence" | jq -r '.tax')" -eq 1 ]]
  expect_sql live-event-count 5 "SELECT count(*) FROM phase8.events WHERE artifact_ref IN ('$linkedin_artifact','$gmail_artifact','$bank_artifact','$tax_artifact') OR artifact_ref LIKE 'schedule://daily-management/%'"
  expect_sql live-completed-count 5 "SELECT count(*) FROM phase8.events WHERE status='completed' AND (artifact_ref IN ('$linkedin_artifact','$gmail_artifact','$bank_artifact','$tax_artifact') OR artifact_ref LIKE 'schedule://daily-management/%')"
  expect_sql live-exception-count 0 "SELECT count(*) FROM phase8.events e JOIN phase8.exceptions x USING(idempotency_key) WHERE e.artifact_ref IN ('$linkedin_artifact','$gmail_artifact','$bank_artifact','$tax_artifact') OR e.artifact_ref LIKE 'schedule://daily-management/%'"
  live_records="$(sql "SELECT jsonb_object_agg(workflow,jsonb_build_object('status',status,'odoo_model',odoo_model,'odoo_record_id',odoo_record_id)) FROM phase8.events WHERE artifact_ref IN ('$linkedin_artifact','$gmail_artifact','$bank_artifact','$tax_artifact') OR artifact_ref LIKE 'schedule://daily-management/%'")"
  printf 'n8n live evidence: %s services=%s\n' "$live_records" "$service_evidence"
  printf 'n8n live acceptance: LinkedIn/Gmail/bank/brief/tax Odoo reconciliation PASS\n'
fi
