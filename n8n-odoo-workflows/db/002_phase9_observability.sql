CREATE OR REPLACE VIEW phase8.workflow_metrics AS
SELECT 'events_total'::text metric, workflow, status label, count(*)::numeric value
FROM phase8.events GROUP BY workflow, status
UNION ALL
SELECT 'duration_seconds', workflow, status,
       coalesce(avg(extract(epoch FROM updated_at - created_at)), 0)::numeric
FROM phase8.events GROUP BY workflow, status
UNION ALL
SELECT 'retries_total', e.workflow, x.error_class, count(*)::numeric
FROM phase8.exceptions x JOIN phase8.events e USING (idempotency_key)
GROUP BY e.workflow, x.error_class
UNION ALL
SELECT 'approvals_pending', e.workflow, a.state, count(*)::numeric
FROM phase8.approvals a JOIN phase8.events e USING (idempotency_key)
WHERE a.state = 'pending' GROUP BY e.workflow, a.state
UNION ALL
SELECT 'approval_age_seconds', e.workflow, a.state,
       coalesce(max(extract(epoch FROM now() - e.updated_at)), 0)::numeric
FROM phase8.approvals a JOIN phase8.events e USING (idempotency_key)
WHERE a.state = 'pending' GROUP BY e.workflow, a.state;

REVOKE ALL ON phase8.workflow_metrics FROM PUBLIC;
