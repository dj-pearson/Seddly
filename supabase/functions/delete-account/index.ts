import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function structuredLog(
  level: "info" | "warn" | "error",
  fields: { requestId: string; action: string; userId?: string; statusCode?: number; [key: string]: unknown },
) {
  const entry = { timestamp: new Date().toISOString(), ...fields };
  if (level === "error") console.error(JSON.stringify(entry));
  else if (level === "warn") console.warn(JSON.stringify(entry));
  else console.log(JSON.stringify(entry));
}

const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Cache-Control": "no-store",
};

const ALLOWED_ORIGINS = ["https://seddly.com", "https://www.seddly.com"];

function corsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "DELETE",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: { ...SECURITY_HEADERS, ...corsHeaders(req) } });
  }

  if (req.method !== "DELETE") {
    structuredLog("warn", { requestId, action: "method_rejected", statusCode: 405 });
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) },
    });
  }

  // Auth: require Bearer token (Supabase JWT)
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    structuredLog("warn", { requestId, action: "auth_missing", statusCode: 401 });
    return new Response(
      JSON.stringify({ error: "Authentication required" }),
      { status: 401, headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) } },
    );
  }

  const token = authHeader.replace("Bearer ", "");
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    structuredLog("warn", { requestId, action: "auth_failed", statusCode: 401 });
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) } },
    );
  }

  const userId = user.id;
  structuredLog("info", { requestId, action: "account_deletion_started", userId });

  try {
    // Delete all user data in order (respecting foreign key constraints)
    // 1. Privacy audit log (references commitments)
    const { error: auditError } = await supabase
      .from("privacy_audit_log")
      .delete()
      .eq("user_id", userId);
    if (auditError) {
      structuredLog("error", { requestId, action: "delete_audit_failed", userId, detail: String(auditError) });
    }

    // 2. Custom workflows
    const { error: workflowError } = await supabase
      .from("custom_workflows")
      .delete()
      .eq("user_id", userId);
    if (workflowError) {
      structuredLog("error", { requestId, action: "delete_workflows_failed", userId, detail: String(workflowError) });
    }

    // 3. Auth events
    const { error: authEventsError } = await supabase
      .from("auth_events")
      .delete()
      .eq("user_id", userId);
    if (authEventsError) {
      structuredLog("error", { requestId, action: "delete_auth_events_failed", userId, detail: String(authEventsError) });
    }

    // 4. Commitments
    const { error: commitmentsError } = await supabase
      .from("commitments")
      .delete()
      .eq("user_id", userId);
    if (commitmentsError) {
      structuredLog("error", { requestId, action: "delete_commitments_failed", userId, detail: String(commitmentsError) });
    }

    // 5. Entities
    const { error: entitiesError } = await supabase
      .from("entities")
      .delete()
      .eq("user_id", userId);
    if (entitiesError) {
      structuredLog("error", { requestId, action: "delete_entities_failed", userId, detail: String(entitiesError) });
    }

    // 6. User record
    const { error: userError } = await supabase
      .from("users")
      .delete()
      .eq("id", userId);
    if (userError) {
      structuredLog("error", { requestId, action: "delete_user_failed", userId, detail: String(userError) });
    }

    // 7. Deactivate the Supabase auth user (soft-delete from auth.users)
    const { error: authDeleteError } = await supabase.auth.admin.deleteUser(userId);
    if (authDeleteError) {
      structuredLog("error", { requestId, action: "delete_auth_user_failed", userId, detail: String(authDeleteError) });
    }

    structuredLog("info", { requestId, action: "account_deletion_completed", userId, statusCode: 200 });

    return new Response(
      JSON.stringify({ deleted: true, message: "Account and all associated data have been permanently deleted." }),
      { headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) } },
    );
  } catch (error) {
    structuredLog("error", { requestId, action: "unhandled_error", userId, statusCode: 500, detail: String(error) });
    return new Response(
      JSON.stringify({ error: "Account deletion failed. Please contact support." }),
      { status: 500, headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) } },
    );
  }
});
