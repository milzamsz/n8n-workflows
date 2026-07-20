\set ON_ERROR_STOP on

INSERT INTO phase8.events (
  idempotency_key, workflow, schema_version, correlation_id, content_hash,
  artifact_ref, status, owner
) VALUES (
  'gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'gmail.vendor_invoice_received.v1', '1.0',
  '11111111-1111-4111-8111-111111111111',
  'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'artifact://invoice/1', 'received', 'Accounts Payable Operations'
);

INSERT INTO phase8.events (
  idempotency_key, workflow, schema_version, correlation_id, content_hash,
  artifact_ref, status, owner
) VALUES (
  'gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'gmail.vendor_invoice_received.v1', '1.0',
  '22222222-2222-4222-8222-222222222222',
  'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'artifact://invoice/1', 'received', 'Accounts Payable Operations'
) ON CONFLICT DO NOTHING;

DO $$ BEGIN
  IF (SELECT count(*) FROM phase8.events) <> 1 THEN
    RAISE EXCEPTION 'duplicate event escaped idempotency barrier';
  END IF;
END $$;

INSERT INTO phase8.approvals (
  approval_id, idempotency_key, capability, payload_hash, payload,
  reviewer_role, state, expires_at
) VALUES (
  '33333333-3333-4333-8333-333333333333',
  'gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'prepare_vendor_bill_draft.v1',
  'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  '{"partner_id": 7}', 'accounts_payable_manager', 'pending', now() + interval '15 minutes'
);

UPDATE phase8.approvals SET state='consumed'
WHERE approval_id='33333333-3333-4333-8333-333333333333'
  AND state='pending'
  AND payload_hash='sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

DO $$ BEGIN
  IF (SELECT state FROM phase8.approvals WHERE approval_id='33333333-3333-4333-8333-333333333333') <> 'pending' THEN
    RAISE EXCEPTION 'mutated payload consumed approval';
  END IF;
END $$;

UPDATE phase8.approvals SET state='consumed', reviewer_id='ap-reviewer', consumed_at=now()
WHERE approval_id='33333333-3333-4333-8333-333333333333'
  AND state='pending' AND expires_at>now()
  AND payload_hash='sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
  AND reviewer_role='accounts_payable_manager';

DO $$ BEGIN
  IF (SELECT state FROM phase8.approvals WHERE approval_id='33333333-3333-4333-8333-333333333333') <> 'consumed' THEN
    RAISE EXCEPTION 'valid approval did not consume';
  END IF;
END $$;

UPDATE phase8.approvals SET reviewer_id='replay'
WHERE approval_id='33333333-3333-4333-8333-333333333333' AND state='pending';

DO $$ BEGIN
  IF (SELECT reviewer_id FROM phase8.approvals WHERE approval_id='33333333-3333-4333-8333-333333333333') <> 'ap-reviewer' THEN
    RAISE EXCEPTION 'consumed approval replayed';
  END IF;
END $$;

INSERT INTO phase8.approvals (
  approval_id, idempotency_key, capability, payload_hash, payload,
  reviewer_role, state, expires_at
) VALUES (
  '44444444-4444-4444-8444-444444444444',
  'gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'prepare_vendor_bill_draft.v1',
  'sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
  '{"partner_id": 8}', 'accounts_payable_manager', 'pending', now() - interval '1 second'
);

UPDATE phase8.approvals SET state='consumed'
WHERE approval_id='44444444-4444-4444-8444-444444444444'
  AND state='pending' AND expires_at>now();

DO $$ BEGIN
  IF (SELECT state FROM phase8.approvals WHERE approval_id='44444444-4444-4444-8444-444444444444') <> 'pending' THEN
    RAISE EXCEPTION 'expired approval consumed';
  END IF;
END $$;

INSERT INTO phase8.exceptions (
  exception_id, idempotency_key, error_class, reason_code, owner
) VALUES (
  '55555555-5555-4555-8555-555555555555',
  'gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'uncertain', 'odoo_write_or_verify_uncertain', 'Accounts Payable Operations'
);
UPDATE phase8.events SET status='uncertain'
WHERE idempotency_key='gmail-vendor-invoice:v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

DO $$ BEGIN
  IF (SELECT status FROM phase8.events) <> 'uncertain' THEN
    RAISE EXCEPTION 'uncertain result remained replayable';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM phase8.audit WHERE decision='received')
     OR NOT EXISTS (SELECT 1 FROM phase8.audit WHERE decision='uncertain') THEN
    RAISE EXCEPTION 'metadata state audit is incomplete';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM phase8.workflow_metrics
    WHERE metric='events_total'
      AND workflow='gmail.vendor_invoice_received.v1'
      AND value >= 1
  ) THEN
    RAISE EXCEPTION 'workflow metrics view is incomplete';
  END IF;
END $$;

SELECT 'duplicate/approval/replay/expiry/uncertain PASS' AS phase8_state_machine;
