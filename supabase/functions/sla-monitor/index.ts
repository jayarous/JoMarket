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

    console.log("[SLA Monitor] Starting SLA status check...");
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
      console.log("[SLA Monitor] No items to monitor");
      return new Response(
        JSON.stringify({
          success: true,
          message: "No items to monitor",
          stats,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    console.log(`[SLA Monitor] Monitoring ${items.length} items`);

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
            console.log(
              `[SLA Monitor] Ticket ${item.ticket_id} BREACHED (${
                Math.abs(hoursRemaining).toFixed(1)
              }h overdue)`,
            );
          }
        } else if (hoursRemaining < 2) {
          // Less than 2 hours remaining - AT RISK
          if (item.sla_status !== "at_risk" && item.sla_status !== "breached") {
            newSlaStatus = "at_risk";
            stats.atRisk++;
            console.log(
              `[SLA Monitor] Ticket ${item.ticket_id} AT RISK (${
                hoursRemaining.toFixed(1)
              }h remaining)`,
            );
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
            const errMsg =
              `Failed to update item ${item.id}: ${updateError.message}`;
            console.error(`[SLA Monitor] ${errMsg}`);
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
            console.warn(
              `[SLA Monitor] Failed to log action for ${item.ticket_id}: ${logError.message}`,
            );
          }

          // TODO: Send notifications for breached SLAs
          // This can be enhanced with email/push notifications
          if (newSlaStatus === "breached") {
            console.log(
              `[SLA Monitor] TODO: Send breach notification for ticket ${item.ticket_id}`,
            );
          }
        }
      } catch (itemError) {
        const errMsg = `Error processing item ${item.id}: ${
          itemError instanceof Error ? itemError.message : "Unknown error"
        }`;
        console.error(`[SLA Monitor] ${errMsg}`);
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

    console.log("[SLA Monitor] Summary:", JSON.stringify(summary, null, 2));

    return new Response(
      JSON.stringify(summary),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("[SLA Monitor] Fatal error:", error);

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
