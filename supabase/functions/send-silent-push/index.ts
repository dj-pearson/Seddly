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
    "Access-Control-Allow-Methods": "POST",
    "Access-Control-Allow-Headers": "Content-Type, X-Cron-Secret, X-Request-ID",
  };
}

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_BUNDLE_ID = "com.pearsonmedia.Seddly";

async function createAPNsJWT(): Promise<string> {
  const header = btoa(JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID }));
  const now = Math.floor(Date.now() / 1000);
  const claims = btoa(JSON.stringify({ iss: APNS_TEAM_ID, iat: now }));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(APNS_PRIVATE_KEY), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)));
  return `${header}.${claims}.${sig}`;
}

async function sendSilentPush(
  deviceToken: string,
  jwt: string,
): Promise<boolean> {
  const payload = JSON.stringify({
    aps: {
      "content-available": 1,
    },
  });

  try {
    const response = await fetch(
      `https://api.push.apple.com/3/device/${deviceToken}`,
      {
        method: "POST",
        headers: {
          Authorization: `bearer ${jwt}`,
          "apns-topic": APNS_BUNDLE_ID,
          "apns-push-type": "background",
          "apns-priority": "5",
        },
        body: payload,
      },
    );
    return response.ok;
  } catch {
    return false;
  }
}

const CRON_SECRET = Deno.env.get("CRON_SECRET")!;

Deno.serve(async (req) => {
  const requestId = req.headers.get("X-Request-ID") || crypto.randomUUID();

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { ...corsHeaders(req), ...SECURITY_HEADERS } });
  }

  // This function is triggered by pg_cron, not external requests
  if (req.method !== "POST") {
    structuredLog("warn", { requestId, action: "method_rejected", statusCode: 405 });
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS, ...corsHeaders(req) },
    });
  }

  // Authenticate: require X-Cron-Secret header matching CRON_SECRET env var
  const cronSecret = req.headers.get("X-Cron-Secret");
  if (!cronSecret || cronSecret !== CRON_SECRET) {
    structuredLog("warn", {
      requestId,
      action: "auth_rejected",
      statusCode: 403,
      reason: cronSecret ? "invalid_secret" : "missing_secret",
    });
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch all Pro/Pro+ users with registered device tokens
    const { data: users, error } = await supabase
      .from("users")
      .select("id, device_token")
      .in("subscription_tier", ["pro", "pro_plus"])
      .eq("subscription_status", "active")
      .not("device_token", "is", null);

    if (error) {
      structuredLog("error", { requestId, action: "db_query_failed", statusCode: 500, detail: String(error) });
      return new Response(JSON.stringify({ error: "Database query failed" }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
      });
    }

    if (!users?.length) {
      structuredLog("info", { requestId, action: "push_skipped", statusCode: 200, reason: "no_eligible_users" });
      return new Response(
        JSON.stringify({ sent: 0, message: "No eligible users" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    const jwt = await createAPNsJWT();

    let sent = 0;
    let failed = 0;

    for (const user of users) {
      if (user.device_token) {
        const success = await sendSilentPush(user.device_token, jwt);
        if (success) sent++;
        else failed++;
      }
    }

    structuredLog("info", { requestId, action: "push_completed", statusCode: 200, sent, failed, total: users.length });

    return new Response(JSON.stringify({ sent, failed, total: users.length }), {
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
    });
  } catch (error) {
    structuredLog("error", { requestId, action: "unhandled_error", statusCode: 500, detail: String(error) });
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
    });
  }
});
