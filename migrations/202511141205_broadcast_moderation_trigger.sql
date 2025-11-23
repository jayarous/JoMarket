-- Migration: broadcast moderation trigger
-- Creates realtime broadcast trigger for public.moderation_queue
CREATE OR REPLACE FUNCTION public.broadcast_moderation_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM realtime.broadcast_changes(
    'ticket:' || COALESCE(NEW.ticket_id, OLD.ticket_id)::text,
    TG_OP, TG_TABLE_NAME, TG_TABLE_SCHEMA, NEW, OLD
  );
  RETURN COALESCE(NEW, OLD);
END;$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE t.tgname = 'moderation_queue_broadcast_trigger'
      AND c.relname = 'moderation_queue'
  ) THEN
    CREATE TRIGGER moderation_queue_broadcast_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.moderation_queue
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_moderation_change();
  END IF;
END$$;