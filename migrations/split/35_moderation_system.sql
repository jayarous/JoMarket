-- 35_moderation_system.sql
-- Moderation Queue and Actions for Admin Support/Moderation Tooling

-- Add escalation fields to support_tickets if they don't exist
DO $$ BEGIN
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS escalated boolean NOT NULL DEFAULT false;
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS escalation_reason text;
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS escalated_at timestamptz;
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS severity text NOT NULL DEFAULT 'medium'; -- low, medium, high, critical
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS sla_status text NOT NULL DEFAULT 'on_track'; -- on_track, at_risk, breached
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS first_response_at timestamptz;
  ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS resolved_at timestamptz;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- Moderation Queue: tracks tickets in the moderation/admin workflow
CREATE TABLE IF NOT EXISTS public.moderation_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  assigned_admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'new', -- new, open, in_progress, pending_seller, resolved, closed
  priority text NOT NULL DEFAULT 'medium', -- low, medium, high, critical
  severity text NOT NULL DEFAULT 'medium', -- low, medium, high, critical
  escalated_at timestamptz,
  tags text[] NOT NULL DEFAULT '{}',
  sla_deadline timestamptz,
  notes jsonb NOT NULL DEFAULT '[]'::jsonb, -- internal admin notes
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_moderation_queue_ticket ON public.moderation_queue(ticket_id);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_assigned ON public.moderation_queue(assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_status ON public.moderation_queue(status);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_priority ON public.moderation_queue(priority);
CREATE INDEX IF NOT EXISTS idx_moderation_queue_sla ON public.moderation_queue(sla_deadline);

-- Moderation Actions: audit trail of admin actions on tickets
CREATE TABLE IF NOT EXISTS public.moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action text NOT NULL, -- assigned, status_changed, note_added, refund_issued, warning_issued, vendor_suspended, escalated, resolved
  target_entity_type text, -- vendor, order, user (for enforcement actions)
  target_entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_moderation_actions_ticket ON public.moderation_actions(ticket_id);
CREATE INDEX IF NOT EXISTS idx_moderation_actions_admin ON public.moderation_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_moderation_actions_created ON public.moderation_actions(created_at);

-- Vendor Warnings/Enforcement Actions
CREATE TABLE IF NOT EXISTS public.vendor_enforcement_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE SET NULL,
  admin_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action_type text NOT NULL, -- warning, suspension, permanent_ban, restriction
  reason text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true,
  expires_at timestamptz, -- for temporary suspensions
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_enforcement_vendor ON public.vendor_enforcement_actions(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_enforcement_active ON public.vendor_enforcement_actions(active);
CREATE INDEX IF NOT EXISTS idx_vendor_enforcement_ticket ON public.vendor_enforcement_actions(ticket_id);

-- Add updated_at triggers
CREATE OR REPLACE FUNCTION update_moderation_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moderation_queue_updated_at ON public.moderation_queue;
CREATE TRIGGER moderation_queue_updated_at
  BEFORE UPDATE ON public.moderation_queue
  FOR EACH ROW
  EXECUTE FUNCTION update_moderation_queue_updated_at();

-- Function to calculate SLA deadline based on priority/severity
CREATE OR REPLACE FUNCTION calculate_sla_deadline(
  p_priority text,
  p_severity text,
  p_created_at timestamptz DEFAULT now()
)
RETURNS timestamptz AS $$
DECLARE
  hours_to_add int;
BEGIN
  -- Critical tickets: 2 hours for critical severity, 4 for high priority
  IF p_severity = 'critical' THEN
    hours_to_add := 2;
  ELSIF p_severity = 'high' OR p_priority = 'critical' THEN
    hours_to_add := 4;
  ELSIF p_priority = 'high' THEN
    hours_to_add := 8;
  ELSIF p_priority = 'medium' THEN
    hours_to_add := 24;
  ELSE
    hours_to_add := 48;
  END IF;
  
  RETURN p_created_at + (hours_to_add || ' hours')::interval;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate SLA deadline on moderation_queue insert
CREATE OR REPLACE FUNCTION set_moderation_queue_sla()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.sla_deadline IS NULL THEN
    NEW.sla_deadline := calculate_sla_deadline(NEW.priority, NEW.severity, NEW.created_at);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moderation_queue_sla_deadline ON public.moderation_queue;
CREATE TRIGGER moderation_queue_sla_deadline
  BEFORE INSERT ON public.moderation_queue
  FOR EACH ROW
  EXECUTE FUNCTION set_moderation_queue_sla();

-- Function to update SLA status based on current time
CREATE OR REPLACE FUNCTION update_sla_status()
RETURNS void AS $$
BEGIN
  -- Update tickets that are at risk (within 25% of deadline)
  UPDATE public.moderation_queue
  SET sla_status = 'at_risk'
  WHERE status NOT IN ('resolved', 'closed')
    AND sla_status = 'on_track'
    AND sla_deadline IS NOT NULL
    AND now() >= (sla_deadline - (sla_deadline - created_at) * 0.25);
  
  -- Update tickets that have breached SLA
  UPDATE public.moderation_queue
  SET sla_status = 'breached'
  WHERE status NOT IN ('resolved', 'closed')
    AND sla_status IN ('on_track', 'at_risk')
    AND sla_deadline IS NOT NULL
    AND now() >= sla_deadline;
    
  -- Update support_tickets table as well
  UPDATE public.support_tickets st
  SET sla_status = mq.sla_status
  FROM public.moderation_queue mq
  WHERE st.id = mq.ticket_id
    AND st.sla_status != mq.sla_status;
END;
$$ LANGUAGE plpgsql;
