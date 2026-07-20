#!/usr/bin/env python3
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "linkedin-to-crm": ("CRM Operations", True),
    "gmail-vendor-invoice": ("Accounts Payable Operations", True),
    "bank-statement-intake": ("Treasury Operations", True),
    "scheduled-business-briefs": ("Business Intelligence Operations", False),
    "indonesian-tax-working-papers": ("Tax Operations", False),
}
ALLOWED_TOOLS = {"odoo_search_read", "odoo_read", "odoo_create"}
FORBIDDEN = {
    "odoo_execute", "odoo_workflow_action", "odoo_delete", "odoo_update",
    "odoo_copy", "odoo_create_batch", "odoo_database_cleanup",
    "odoo_deep_cleanup", "odoo_stock_inventory_reversal_cleanup",
}
CAPABILITY_CASES = {
    "linkedin-to-crm": {
        "title": "PT Example expansion", "organization": "PT Example",
        "contact_name": "Ayu", "email": "ayu@example.com", "phone": None,
        "description": "Requested a follow-up.",
        "evidence_ref": "crm-source:linkedin:abc123",
        "idempotency_key": "crm-lead:v1:2f17432edde126fdaef91b4779f0d6223a855cfa3949dfc97e70dff120d7a387",
    },
    "gmail-vendor-invoice": {
        "partner_id": 7, "currency_id": 1, "invoice_date": "2026-07-20",
        "due_date": "2026-08-20", "payment_term_id": None,
        "vendor_reference": "INV-42",
        "lines": [{"product_id": None, "account_id": 601, "uom_id": None,
                   "description": "Services", "quantity_milli": 2000,
                   "unit_price_minor": 12500, "tax_ids": [3]}],
        "evidence_refs": ["document:sha256:abc"], "purchase_order_refs": [],
        "receipt_refs": [], "discrepancies": ["No purchase order supplied"],
        "idempotency_key": "vendor-bill:v1:88ec909248fcfdf56ef36bd9898aae36d2e9b19f7c46afcaabd495f47e38bf4e",
    },
    "bank-statement-intake": {
        "journal_id": 6, "transaction_date": "2026-07-20",
        "payment_reference": "Customer transfer", "amount_minor": 125000,
        "partner_id": 7, "foreign_currency_id": None, "amount_currency_minor": None,
        "external_transaction_id": "BANK-20260720-42",
        "evidence_refs": ["bank-file:sha256:abc"], "discrepancies": [],
        "idempotency_key": "bank-transaction:v1:5678a30a400732a53a98c4defd494ef6fdde3f0dbbd8fcfbc1d9485c4e7b9704",
    },
}
EVENT_CASES = {
    "linkedin-to-crm": {
        "artifact_ref": "artifact://linkedin/1", "content_hash": "sha256:" + "1" * 64,
        "source": {"url": "https://www.linkedin.com/posts/1", "capture_mechanism": "operator_url",
                   "captured_at": "2026-07-20T00:00:00Z", "provenance": "operator:crm-user"},
        "review": {"proposed_title": "PT Example expansion"},
    },
    "gmail-vendor-invoice": {
        "artifact_ref": "artifact://gmail/1", "content_hash": "sha256:" + "2" * 64,
        "source": {"mailbox": "ap@example.com", "sender": "vendor@example.com", "message_id": "gmail-1",
                   "filter_ref": "secret://n8n/gmail/vendor-invoice-filter",
                   "attachments": [{"mime_type": "application/pdf", "size_bytes": 1024,
                                      "malware_status": "clean", "content_hash": "sha256:" + "3" * 64}]},
        "extraction": {"vendor_reference": {"value": "INV-42"}},
    },
    "bank-statement-intake": {
        "artifact_ref": "artifact://bank/1", "content_hash": "sha256:" + "4" * 64,
        "source": {"source_id": "bank-portal", "account_map_ref": "secret://n8n/bank/account-map",
                   "filename": "statement.csv", "mime_type": "text/csv", "size_bytes": 2048},
        "statement": {"journal_id": 6, "account_last4": "1234", "currency": "USD",
                      "period_start": "2026-07-01", "period_end": "2026-07-20"},
    },
    "indonesian-tax-working-papers": {
        "artifact_ref": "artifact://tax/1", "content_hash": "sha256:" + "5" * 64,
        "request": {"tax_period": "2026-06", "rule_version": "PPN-v1",
                    "rule_source_ref": "rules://id/ppn/v1", "transaction_refs": ["odoo://account.move/1"],
                    "document_refs": []},
    },
}


def load(path):
    with path.open() as stream:
        return json.load(stream)


def check_javascript(code, label):
    result = subprocess.run(
        ["node", "--check", "-"],
        input=f"async function workflowCode(){{\n{code}\n}}\n",
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, f"{label}: {result.stderr}"


def run_bounded_javascript(code, payload):
    script = """
const payload=JSON.parse(process.argv[1]);
const $input={first:()=>({json:{payload}})};
async function workflowCode(){%s}
workflowCode().then(value=>process.stdout.write(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exit(2)});
""" % code
    return subprocess.run(
        ["node", "-e", script, json.dumps(payload, separators=(",", ":"))],
        text=True, capture_output=True, check=False,
    )


def run_validation_javascript(code, body):
    script = """
const body=JSON.parse(process.argv[1]);
const $input={first:()=>({json:{body}})};
async function workflowCode(){%s}
workflowCode().then(value=>process.stdout.write(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exit(2)});
""" % code
    return subprocess.run(
        ["node", "-e", script, json.dumps(body, separators=(",", ":"))],
        text=True, capture_output=True, check=False,
    )


def run_item_javascript(code, item):
    script = """
const item=JSON.parse(process.argv[1]);
const $input={first:()=>({json:item})};
async function workflowCode(){%s}
workflowCode().then(value=>process.stdout.write(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exit(2)});
""" % code
    return subprocess.run(
        ["node", "-e", script, json.dumps(item, separators=(",", ":"))],
        text=True, capture_output=True, check=False,
    )


def main():
    subprocess.run(
        ["node", "scripts/build_workflows.mjs", "--check"], cwd=ROOT, check=True
    )
    config = load(ROOT / "config/workflows.json")
    assert config["environment"] == "staging"
    assert config["instance_id"] == "ocloud-staging"
    assert config["company_id"] == 1
    assert all(not value["production_approved"] for value in config["workflows"].values())

    credential_config = load(ROOT / "config/credentials.json")
    credentials = credential_config["credentials"]
    assert len({item["name"] for item in credentials}) == len(credentials)
    assert all(item["secret_ref"].startswith(("secret://", "env://")) for item in credentials)
    endpoints = credential_config["endpoints"]
    assert {item["environment_variable"] for item in endpoints} == {
        "ODOO_MCP_STAGING_URL", "PHASE8_EXTRACTOR_URL", "PHASE8_TAX_RULES_URL",
        "PHASE8_BRIEF_DELIVERY_URL", "PHASE8_ALERT_URL",
    }
    assert all(item["config_ref"].startswith("config://") for item in endpoints)

    envelope = load(ROOT / "schemas/envelope.v1.schema.json")
    assert envelope["additionalProperties"] is False
    assert envelope["properties"]["context"]["properties"]["instance_id"]["const"] == "ocloud-staging"
    for slug, (owner, _) in EXPECTED.items():
        schema = load(ROOT / f"schemas/{slug}.v1.schema.json")
        assert schema["additionalProperties"] is False
        assert schema["properties"]["envelope"]["$ref"] == "envelope.v1.schema.json"
        assert owner in json.dumps(schema)

    for slug, (_, permits_create) in EXPECTED.items():
        path = ROOT / f"workflows/{slug}.v1.json"
        workflow = load(path)
        raw = path.read_text()
        assert workflow["active"] is False
        assert workflow["meta"]["productionApproved"] is False
        assert workflow["settings"]["saveDataErrorExecution"] == "none"
        assert workflow["settings"]["saveDataSuccessExecution"] == "none"
        assert workflow["settings"]["saveManualExecutions"] is False
        assert workflow["settings"]["executionTimeout"] <= 300
        assert not (FORBIDDEN & set(word.strip('" ,') for word in raw.split()))

        names = {node["name"] for node in workflow["nodes"]}
        ids = [node["id"] for node in workflow["nodes"]]
        assert len(ids) == len(set(ids))
        assert {"Validate Event", "Claim Event", "Is New", "Prepare Odoo Reads", "Read Odoo", "Decode Odoo Read", "Queue Review", "Alert Owner"} <= names
        for source, outputs in workflow["connections"].items():
            assert source in names
            for branch in outputs["main"]:
                for edge in branch:
                    assert edge["node"] in names

        tools = {
            node["parameters"]["tool"]["value"]
            for node in workflow["nodes"]
            if node["type"] == "@n8n/n8n-nodes-langchain.mcpClient"
        }
        assert tools <= ALLOWED_TOOLS
        assert ("odoo_create" in tools) is permits_create
        waits = {
            node["parameters"]["amount"]
            for node in workflow["nodes"]
            if node["type"] == "n8n-nodes-base.wait" and "Backoff" in node["name"]
        }
        assert waits == {2, 10, 30}
        for node in workflow["nodes"]:
            if " Backoff " in node["name"]:
                incoming = [
                    source for source, outputs in workflow["connections"].items()
                    for branch in outputs["main"] for edge in branch
                    if edge["node"] == node["name"]
                ]
                assert len(incoming) == 1 and " Retryable " in incoming[0]
            if node["name"].endswith("Attempt 4"):
                failure = workflow["connections"][node["name"]]["main"][1]
                assert len(failure) == 1 and failure[0]["node"].endswith("Classify Error 4")
        classifier = next(node for node in workflow["nodes"] if "Classify Error" in node["name"])
        classify = lambda item: json.loads(run_item_javascript(classifier["parameters"]["jsCode"], item).stdout)[0]["json"]["retryable"]
        assert classify({"error": {"message": "connect ECONNREFUSED 127.0.0.1:9"}}) is True
        assert classify({"error": {"message": "bad request", "httpCode": 400}}) is False
        assert classify({"error": {"message": "rate limited", "statusCode": 429}}) is True
        assert classify({"error": {"message": "access denied by company policy"}}) is False
        alert = next(node for node in workflow["nodes"] if node["name"] == "Alert Owner")
        assert all(secret not in alert["parameters"]["body"] for secret in ("payload", "content", "document", "email", "amount"))
        for node in workflow["nodes"]:
            if node["type"] == "n8n-nodes-base.webhook":
                assert node["parameters"]["authentication"] == "headerAuth"
                assert node["credentials"]["httpHeaderAuth"]["name"] == "phase8-webhook-header"
            if node.get("retryOnFail"):
                raise AssertionError(f"{slug}:{node['name']} uses fixed-delay retry")
            if node["type"] == "n8n-nodes-base.postgres":
                assert "queryReplacement" in node["parameters"]["options"]
                assert "={{" not in node["parameters"]["query"]
            if node["type"] == "n8n-nodes-base.code":
                check_javascript(node["parameters"]["jsCode"], f"{slug}:{node['name']}")

        validation = next(node for node in workflow["nodes"] if node["name"] == "Validate Event")
        if slug in EVENT_CASES:
            first = run_validation_javascript(validation["parameters"]["jsCode"], EVENT_CASES[slug])
            replay = run_validation_javascript(validation["parameters"]["jsCode"], EVENT_CASES[slug])
            assert first.returncode == replay.returncode == 0
            first_event = json.loads(first.stdout)[0]["json"]
            replay_event = json.loads(replay.stdout)[0]["json"]
            assert first_event["valid"] is True
            assert first_event["idempotency_key"] == replay_event["idempotency_key"]
            invalid = dict(EVENT_CASES[slug], content_hash="not-a-hash")
            rejected = run_validation_javascript(validation["parameters"]["jsCode"], invalid)
            assert rejected.returncode == 0
            assert json.loads(rejected.stdout)[0]["json"]["valid"] is False
        else:
            first = run_validation_javascript(validation["parameters"]["jsCode"], {})
            replay = run_validation_javascript(validation["parameters"]["jsCode"], {})
            assert first.returncode == replay.returncode == 0
            first_event = json.loads(first.stdout)[0]["json"]
            replay_event = json.loads(replay.stdout)[0]["json"]
            assert first_event["valid"] is True
            assert first_event["idempotency_key"] == replay_event["idempotency_key"]

        if permits_create:
            assert {"Extract Source", "Validate Extraction", "Match and Prepare Review"} <= names
            create = next(node for node in workflow["nodes"] if node["name"] == "Create Odoo Record")
            assert not create.get("retryOnFail", False)
            assert create["onError"] == "continueErrorOutput"
            assert workflow["connections"]["Create Odoo Record"]["main"][1][0]["node"] == "Queue Uncertain"
            assert {
                "Approval Trigger", "Consume Approval", "Approved?", "Decode Created Record",
                "Check Existing Odoo", "Decode Duplicate Check", "Classify Duplicate",
                "No Existing?", "Complete Duplicate", "Queue Approval Exception",
                "Verify Odoo Record", "Decode Verification", "Verify Postcondition",
            } <= names
            consume = next(node for node in workflow["nodes"] if node["name"] == "Consume Approval")
            assert consume["alwaysOutputData"] is True
            bounded = next(node for node in workflow["nodes"] if node["name"] == "Build Bounded Operation")
            assert "approval_id:input" not in bounded["parameters"]["jsCode"]
            assert "idempotency_key:input" not in bounded["parameters"]["jsCode"]
            assert "capabilityKey(" in bounded["parameters"]["jsCode"]
            case = CAPABILITY_CASES[slug]
            mapped = run_bounded_javascript(bounded["parameters"]["jsCode"], case)
            assert mapped.returncode == 0, mapped.stderr
            operation = json.loads(mapped.stdout)[0]["json"]
            assert set(operation) == {"instance", "model", "values", "context"}
            assert operation["instance"] == "ocloud-staging"
            assert operation["context"]["allowed_company_ids"] == [1]
            assert operation["context"]["force_company"] == 1
            mutated = dict(case)
            mutated["idempotency_key"] = case["idempotency_key"][:-1] + ("0" if case["idempotency_key"][-1] != "0" else "1")
            assert run_bounded_javascript(bounded["parameters"]["jsCode"], mutated).returncode != 0
            if slug == "bank-statement-intake":
                assert "record.is_reconciled===false" in raw
                assert all(model in raw for model in ("res.partner", "account.move", "account.payment"))
            elif slug == "gmail-vendor-invoice":
                assert all(model in raw for model in ("res.partner", "res.company", "account.account", "account.move", "purchase.order", "stock.picking", "product.product", "account.tax"))
            else:
                assert all(model in raw for model in ("res.partner", "crm.lead"))
        elif slug == "indonesian-tax-working-papers":
            assert {"Approval Trigger", "Consume Approval", "Approved?"} <= names
            assert "Calculate Tax Working Paper" in names
            assert all(value in raw for value in ("tax_object", "dpp_minor", "rate_basis_points", "tax_minor", "responsibility", "missing_documents", "statutory_submission_allowed"))
        else:
            assert "schedule_approval_ref" in raw
            assert "type\": \"n8n-nodes-base.scheduleTrigger" in raw
            assert {"Deliver Brief", "Complete"} <= names
            assert all(value in raw for value in ("period_start", "period_end", "data_fresh_at", "partial_failure", "included_states"))

    key = lambda content: hashlib.sha256(
        f"gmail.vendor_invoice_received.v1|ocloud-staging|1|artifact://invoice-1|sha256:{content}".encode()
    ).hexdigest()
    assert key("0" * 64) == key("0" * 64)
    assert key("0" * 64) != key("1" * 64)

    ddl = (ROOT / "db/001_phase8.sql").read_text()
    assert "idempotency_key text PRIMARY KEY" in ddl
    assert "UNIQUE (idempotency_key, payload_hash)" in ddl
    assert "REVOKE ALL" in ddl
    assert "events_metadata_audit" in ddl
    assert "reconciled" not in ddl.lower()
    metrics_ddl = (ROOT / "db/002_phase9_observability.sql").read_text()
    assert "phase8.workflow_metrics" in metrics_ddl
    assert all(metric in metrics_ddl for metric in (
        "events_total", "duration_seconds", "retries_total",
        "approvals_pending", "approval_age_seconds",
    ))
    assert "REVOKE ALL" in metrics_ddl
    print("phase8 contract checks: 5 workflows, 6 schemas, inactive staging gate PASS")


if __name__ == "__main__":
    main()
