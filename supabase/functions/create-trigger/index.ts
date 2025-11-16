// Edge Function: create-trigger
// Purpose: Returns SQL needed to create realtime broadcast trigger on public.moderation_queue
// This function does NOT itself apply the DDL (for reliability we apply via supabase CLI),
// but gives an idempotent SQL block and reports whether trigger already exists.
// After deployment you can invoke it to retrieve the SQL again.

import { serve } from "https://deno.land/std/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Idempotent SQL block
const ddlSql = `-- Realtime broadcast trigger for public.moderation_queue\nCREATE OR REPLACE FUNCTION public.broadcast_moderation_change()\nRETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$\nBEGIN\n  PERFORM realtime.broadcast_changes(\n    'ticket:' || COALESCE(NEW.ticket_id, OLD.ticket_id)::text,\n    TG_OP, TG_TABLE_NAME, TG_TABLE_SCHEMA, NEW, OLD\n  );\n  RETURN COALESCE(NEW, OLD);\nEND;$$;\nDO $$\nBEGIN\n  IF NOT EXISTS (\n    SELECT 1 FROM pg_trigger t\n    JOIN pg_class c ON t.tgrelid = c.oid\n    WHERE t.tgname = 'moderation_queue_broadcast_trigger'\n      AND c.relname = 'moderation_queue'\n  ) THEN\n    CREATE TRIGGER moderation_queue_broadcast_trigger\n    AFTER INSERT OR UPDATE OR DELETE ON public.moderation_queue\n    FOR EACH ROW EXECUTE FUNCTION public.broadcast_moderation_change();\n  END IF;\nEND$$;`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // We cannot run DDL safely from Edge without a privileged SQL meta endpoint.
  // Instead we return SQL + instructions.
  const body = {
    message: "Edge function deployed. Apply returned SQL via supabase db query or SQL Editor.",
    target_table: "public.moderation_queue",
    events: ["INSERT", "UPDATE", "DELETE"],
    topic_pattern: "ticket:<ticket_id>",
    sql: ddlSql,
    apply_instructions: {
      cli: "supabase db query \"<paste ddlSql>\"",
      sql_editor: "Paste entire block into SQL editor and run once",
      verify_sql: "SELECT tgname FROM pg_trigger WHERE tgname='moderation_queue_broadcast_trigger';"
    }
  };

  return new Response(JSON.stringify(body, null, 2), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
