-- 35_moderation_policies.sql
-- Row-Level Security policies for moderation system

-- Enable RLS on new tables
ALTER TABLE public.moderation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_enforcement_actions ENABLE ROW LEVEL SECURITY;

-- ====================
-- MODERATION_QUEUE Policies
-- ====================

-- Only platform admins can view moderation queue
DROP POLICY IF EXISTS "moderation_queue_admin_read" ON public.moderation_queue;
CREATE POLICY "moderation_queue_admin_read" ON public.moderation_queue
FOR SELECT USING (
  public.is_platform_admin(auth.uid())
);

-- Only platform admins can insert into moderation queue
DROP POLICY IF EXISTS "moderation_queue_admin_insert" ON public.moderation_queue;
CREATE POLICY "moderation_queue_admin_insert" ON public.moderation_queue
FOR INSERT WITH CHECK (
  public.is_platform_admin(auth.uid())
);

-- Only platform admins can update moderation queue
DROP POLICY IF EXISTS "moderation_queue_admin_update" ON public.moderation_queue;
CREATE POLICY "moderation_queue_admin_update" ON public.moderation_queue
FOR UPDATE USING (
  public.is_platform_admin(auth.uid())
);

-- Only platform admins can delete from moderation queue
DROP POLICY IF EXISTS "moderation_queue_admin_delete" ON public.moderation_queue;
CREATE POLICY "moderation_queue_admin_delete" ON public.moderation_queue
FOR DELETE USING (
  public.is_platform_admin(auth.uid())
);

-- ====================
-- MODERATION_ACTIONS Policies
-- ====================

-- Platform admins can view all moderation actions
DROP POLICY IF EXISTS "moderation_actions_admin_read" ON public.moderation_actions;
CREATE POLICY "moderation_actions_admin_read" ON public.moderation_actions
FOR SELECT USING (
  public.is_platform_admin(auth.uid())
);

-- Platform admins can insert moderation actions
DROP POLICY IF EXISTS "moderation_actions_admin_insert" ON public.moderation_actions;
CREATE POLICY "moderation_actions_admin_insert" ON public.moderation_actions
FOR INSERT WITH CHECK (
  public.is_platform_admin(auth.uid())
);

-- No updates or deletes allowed on moderation_actions (audit trail)

-- ====================
-- VENDOR_ENFORCEMENT_ACTIONS Policies
-- ====================

-- Platform admins can view all enforcement actions
DROP POLICY IF EXISTS "vendor_enforcement_admin_read" ON public.vendor_enforcement_actions;
CREATE POLICY "vendor_enforcement_admin_read" ON public.vendor_enforcement_actions
FOR SELECT USING (
  public.is_platform_admin(auth.uid())
);

-- Vendors can view enforcement actions against them
DROP POLICY IF EXISTS "vendor_enforcement_vendor_read" ON public.vendor_enforcement_actions;
CREATE POLICY "vendor_enforcement_vendor_read" ON public.vendor_enforcement_actions
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.vendors v
    WHERE v.id = vendor_enforcement_actions.vendor_id
      AND (v.owner_user_id = auth.uid() 
           OR EXISTS (SELECT 1 FROM public.vendor_staff vs 
                     WHERE vs.vendor_id = v.id 
                       AND vs.user_id = auth.uid()))
  )
);

-- Platform admins can insert enforcement actions
DROP POLICY IF EXISTS "vendor_enforcement_admin_insert" ON public.vendor_enforcement_actions;
CREATE POLICY "vendor_enforcement_admin_insert" ON public.vendor_enforcement_actions
FOR INSERT WITH CHECK (
  public.is_platform_admin(auth.uid())
);

-- Platform admins can update enforcement actions (e.g., deactivate, extend expiry)
DROP POLICY IF EXISTS "vendor_enforcement_admin_update" ON public.vendor_enforcement_actions;
CREATE POLICY "vendor_enforcement_admin_update" ON public.vendor_enforcement_actions
FOR UPDATE USING (
  public.is_platform_admin(auth.uid())
);

-- ====================
-- Update SUPPORT_TICKETS policies for admin access
-- ====================

-- Platform admins can view all support tickets
DROP POLICY IF EXISTS "support_tickets_admin_read" ON public.support_tickets;
CREATE POLICY "support_tickets_admin_read" ON public.support_tickets
FOR SELECT USING (
  public.is_platform_admin(auth.uid())
);

-- Platform admins can update all support tickets
DROP POLICY IF EXISTS "support_tickets_admin_update" ON public.support_tickets;
CREATE POLICY "support_tickets_admin_update" ON public.support_tickets
FOR UPDATE USING (
  public.is_platform_admin(auth.uid())
);

-- ====================
-- Update TICKET_MESSAGES policies for admin access
-- ====================

-- Platform admins can view all ticket messages
DROP POLICY IF EXISTS "ticket_messages_admin_read" ON public.ticket_messages;
CREATE POLICY "ticket_messages_admin_read" ON public.ticket_messages
FOR SELECT USING (
  public.is_platform_admin(auth.uid())
);

-- Platform admins can insert messages
DROP POLICY IF EXISTS "ticket_messages_admin_insert" ON public.ticket_messages;
CREATE POLICY "ticket_messages_admin_insert" ON public.ticket_messages
FOR INSERT WITH CHECK (
  public.is_platform_admin(auth.uid())
);
