CREATE SCHEMA IF NOT EXISTS phase8;

CREATE TABLE IF NOT EXISTS phase8.events (
  idempotency_key text PRIMARY KEY,
  workflow text NOT NULL,
  schema_version text NOT NULL,
  correlation_id uuid NOT NULL,
  content_hash text NOT NULL,
  artifact_ref text NOT NULL,
  status text NOT NULL CHECK (status IN (
    'received', 'review_pending', 'approved', 'rejected', 'completed',
    'duplicate', 'exception', 'uncertain'
  )),
  owner text NOT NULL,
  odoo_model text,
  odoo_record_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS phase8.approvals (
  approval_id uuid PRIMARY KEY,
  idempotency_key text NOT NULL REFERENCES phase8.events(idempotency_key),
  capability text NOT NULL CHECK (capability IN (
    'create_crm_lead_draft.v1', 'prepare_vendor_bill_draft.v1',
    'import_bank_transaction_draft.v1', 'brief_delivery.v1',
    'id_tax_working_paper_signoff.v1'
  )),
  payload_hash text NOT NULL,
  payload jsonb NOT NULL,
  reviewer_role text NOT NULL,
  reviewer_id text,
  state text NOT NULL CHECK (state IN ('pending', 'approved', 'rejected', 'expired', 'consumed')),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  UNIQUE (idempotency_key, payload_hash)
);

CREATE TABLE IF NOT EXISTS phase8.exceptions (
  exception_id uuid PRIMARY KEY,
  idempotency_key text NOT NULL REFERENCES phase8.events(idempotency_key),
  error_class text NOT NULL CHECK (error_class IN ('retryable', 'permanent', 'uncertain')),
  reason_code text NOT NULL,
  owner text NOT NULL,
  replay_after timestamptz,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS phase8.audit (
  audit_id bigserial PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  workflow text NOT NULL,
  correlation_id uuid NOT NULL,
  idempotency_key text NOT NULL,
  decision text NOT NULL,
  result_class text NOT NULL,
  owner text NOT NULL,
  approval_id uuid,
  odoo_model text,
  odoo_record_id bigint
);

CREATE OR REPLACE FUNCTION phase8.audit_event_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = phase8, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO phase8.audit (
      workflow, correlation_id, idempotency_key, decision, result_class,
      owner, odoo_model, odoo_record_id
    ) VALUES (
      NEW.workflow, NEW.correlation_id, NEW.idempotency_key, NEW.status,
      NEW.status, NEW.owner, NEW.odoo_model, NEW.odoo_record_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS events_metadata_audit ON phase8.events;
CREATE TRIGGER events_metadata_audit
AFTER INSERT OR UPDATE OF status ON phase8.events
FOR EACH ROW EXECUTE FUNCTION phase8.audit_event_status();

REVOKE ALL ON SCHEMA phase8 FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA phase8 FROM PUBLIC;
REVOKE ALL ON FUNCTION phase8.audit_event_status() FROM PUBLIC;
