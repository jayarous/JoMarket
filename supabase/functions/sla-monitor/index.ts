// SLA Monitoring Edge Function
// Runs every 15 minutes to update ticket SLA statuses
// Updates tickets from 'normal' -> 'at_risk' -> 'breached' based on deadlines

import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ModerationQueueItem {
  id: string;
  ticket_id: string;
  status: string;
  priority: string;
  severity: string;
  sla_status: string | null;
  sla_deadline: string | null;
  escalated_at: string;
}

interface UpdateStats {
  atRisk: number;
  breached: number;
  errors: string[];
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

    try {
    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const SERVICE_NAME = "sla-monitor";

    function log(level: "info" | "warn" | "error", message: string, extras: Record<string, unknown> = {}) {
      const out = {
        timestamp: new Date().toISOString(),
        service: SERVICE_NAME,
        environment: Deno.env.get("ENVIRONMENT") ?? "staging",
        level,
        message,
        ...extras,
      };
      // Emit structured JSON to stdout so log forwarders can parse it
      console.log(JSON.stringify(out));
    }

    log("info", "Starting SLA status check");
    const now = new Date().toISOString();
    const stats: UpdateStats = { atRisk: 0, breached: 0, errors: [] };

    // Get all open moderation queue items that need SLA monitoring
    const { data: items, error: fetchError } = await supabase
      .from("moderation_queue")
      .select("*")
      .in("status", ["new", "open"])
      .not("sla_deadline", "is", null);

    if (fetchError) {
      throw new Error(`Failed to fetch queue items: ${fetchError.message}`);
    }

    if (!items || items.length === 0) {
      log("info", "No items to monitor");
      return new Response(
        JSON.stringify({
          success: true,
          message: "No items to monitor",
          stats,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    log("info", `Monitoring items`, { total_items: items.length });

    // Process each item
    for (const item of items as ModerationQueueItem[]) {
      try {
        const deadline = new Date(item.sla_deadline!);
        const nowDate = new Date(now);
        const timeUntilDeadline = deadline.getTime() - nowDate.getTime();
        const hoursRemaining = timeUntilDeadline / (1000 * 60 * 60);

        let newSlaStatus = item.sla_status;

        // Determine SLA status based on time remaining
        if (hoursRemaining < 0) {
          // Past deadline - BREACHED
            if (item.sla_status !== "breached") {
            newSlaStatus = "breached";
            stats.breached++;
            log("info", "Ticket breached", { ticket_id: item.ticket_id, overdue_hours: Math.abs(hoursRemaining).toFixed(1) });
          }
        } else if (hoursRemaining < 2) {
          // Less than 2 hours remaining - AT RISK
          if (item.sla_status !== "at_risk" && item.sla_status !== "breached") {
            newSlaStatus = "at_risk";
            stats.atRisk++;
            log("info", "Ticket at risk", { ticket_id: item.ticket_id, hours_remaining: hoursRemaining.toFixed(1) });
          }
        }

        // Update if status changed
        if (newSlaStatus !== item.sla_status) {
          const { error: updateError } = await supabase
            .from("moderation_queue")
            .update({
              sla_status: newSlaStatus,
              updated_at: now,
            })
            .eq("id", item.id);

          if (updateError) {
            const errMsg = `Failed to update item ${item.id}: ${updateError.message}`;
            log("error", errMsg, { item_id: item.id, supabase_error: updateError.message });
            stats.errors.push(errMsg);
          }

          // Log moderation action for audit trail
          const { error: logError } = await supabase
            .from("moderation_actions")
            .insert({
              ticket_id: item.ticket_id,
              action_type: "sla_status_change",
              action_details: {
                from_status: item.sla_status,
                to_status: newSlaStatus,
                deadline: item.sla_deadline,
                hours_remaining: hoursRemaining,
                automated: true,
              },
              performed_by: null, // System action
              created_at: now,
            });

          if (logError) {
            log("warn", "Failed to log action", { ticket_id: item.ticket_id, error: logError.message });
          }

          // TODO: Send notifications for breached SLAs
          // This can be enhanced with email/push notifications
          if (newSlaStatus === "breached") {
            log("info", "TODO: Send breach notification", { ticket_id: item.ticket_id });
          }
        }
      } catch (itemError) {
        const errMsg = `Error processing item ${item.id}: ${itemError instanceof Error ? itemError.message : "Unknown error"}`;
        log("error", errMsg, { item_id: item.id, error: itemError instanceof Error ? itemError.message : String(itemError) });
        stats.errors.push(errMsg);
      }
    }

    const summary = {
      success: true,
      message: "SLA monitoring completed",
      stats: {
        total_monitored: items.length,
        marked_at_risk: stats.atRisk,
        marked_breached: stats.breached,
        errors: stats.errors.length,
      },
      timestamp: now,
    };

    // Emit structured summary
    try {
      log("info", "Summary", { summary });

      // Write a lightweight metrics row to Supabase for quick dashboarding (optional schema)
      try {
        const { error: metricErr } = await supabase.from("function_metrics").insert({
          function: SERVICE_NAME,
          environment: Deno.env.get("ENVIRONMENT") ?? "staging",
          total_monitored: items.length,
          marked_at_risk: stats.atRisk,
          marked_breached: stats.breached,
          errors: stats.errors.length,
          created_at: now,
        });

        if (metricErr) {
          log("warn", "Failed to write metrics", { error: metricErr.message });
        }
      } catch (e) {
        log("warn", "Failed to write metrics (exception)", { error: e instanceof Error ? e.message : String(e) });
      }

    } catch (e) {
      // If sending summary fails, still return success payload
      log("warn", "Failed to emit summary", { error: e instanceof Error ? e.message : String(e) });
    }

    return new Response(
      JSON.stringify(summary),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    log("error", "Fatal error", { error: error instanceof Error ? error.message : String(error) });

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
