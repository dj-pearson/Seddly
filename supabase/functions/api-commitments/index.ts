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

// Pro+ API Access — RESTful endpoints for commitment data
// GET /api-commitments — list commitments (supports ?status=, ?entity=, ?limit=, ?offset=)
// GET /api-commitments?id=<uuid> — get single commitment
// POST /api-commitments — create commitment
// PATCH /api-commitments — update commitment (requires id in body)
// DELETE /api-commitments?id=<uuid> — delete commitment

const ALLOWED_ORIGINS = ["https://seddly.com", "https://www.seddly.com"];

const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Cache-Control": "no-store",
};

const RATE_LIMIT_MAX = 60; // 60 requests per window
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute window

const kv = await Deno.openKv();

async function checkRateLimit(userId: string): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
  const key = ["rate_limit", "api-commitments", userId];
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  const entry = await kv.get<{ timestamps: number[] }>(key);
  const timestamps = (entry.value?.timestamps ?? []).filter((t) => t > windowStart);

  if (timestamps.length >= RATE_LIMIT_MAX) {
    const oldestInWindow = Math.min(...timestamps);
    const retryAfterSeconds = Math.ceil((oldestInWindow + RATE_LIMIT_WINDOW_MS - now) / 1000);
    return { allowed: false, retryAfterSeconds: Math.max(1, retryAfterSeconds) };
  }

  timestamps.push(now);
  await kv.set(key, { timestamps }, { expireIn: RATE_LIMIT_WINDOW_MS });
  return { allowed: true, retryAfterSeconds: 0 };
}

function corsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
  };
}

async function logAuthEvent(
  supabase: ReturnType<typeof createClient>,
  eventType: string,
  req: Request,
  userId?: string,
  details?: string,
) {
  try {
    await supabase.from("auth_events").insert({
      user_id: userId ?? null,
      event_type: eventType,
      ip_address: req.headers.get("X-Forwarded-For") ?? req.headers.get("CF-Connecting-IP") ?? null,
      user_agent: req.headers.get("User-Agent") ?? null,
      details,
    });
  } catch {
    // Auth event logging is non-critical — don't fail the request
  }
}

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(req) });
  }

  // Auth: require Bearer token (Supabase JWT) or X-API-Key
  const authHeader = req.headers.get("Authorization");
  const apiKey = req.headers.get("X-API-Key");

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  if (!authHeader && !apiKey) {
    structuredLog("warn", { requestId, action: "auth_missing", statusCode: 401 });
    await logAuthEvent(supabase, "auth_missing", req, undefined, "No auth header or API key");
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  // Verify user from JWT
  let userId: string;
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      structuredLog("warn", { requestId, action: "auth_failed", statusCode: 401 });
      await logAuthEvent(supabase, "auth_failed", req, undefined, "Invalid or expired JWT");
      return jsonResponse({ error: "Invalid token" }, 401);
    }

    // Verify Pro+ subscription
    const { data: userData } = await supabase
      .from("users")
      .select("subscription_tier")
      .eq("id", user.id)
      .single();

    if (!userData || userData.subscription_tier !== "pro_plus") {
      structuredLog("warn", { requestId, action: "subscription_required", userId: user.id, statusCode: 403 });
      await logAuthEvent(supabase, "subscription_check_failed", req, user.id, `tier: ${userData?.subscription_tier ?? "unknown"}`);
      return jsonResponse({ error: "API access requires Pro+ subscription" }, 403);
    }

    userId = user.id;
    await logAuthEvent(supabase, "auth_success", req, userId, `api-commitments ${req.method}`);
  } else {
    structuredLog("warn", { requestId, action: "auth_missing", statusCode: 401 });
    await logAuthEvent(supabase, "auth_missing", req, undefined, "Bearer token required");
    return jsonResponse({ error: "Bearer token required" }, 401);
  }

  // Rate limiting: 60 requests per minute per user
  const rateLimit = await checkRateLimit(userId);
  if (!rateLimit.allowed) {
    structuredLog("warn", { requestId, action: "rate_limited", userId, statusCode: 429 });
    return new Response(
      JSON.stringify({ error: "Rate limit exceeded. Please try again later." }),
      {
        status: 429,
        headers: {
          "Content-Type": "application/json",
          "Retry-After": String(rateLimit.retryAfterSeconds),
          ...corsHeaders(req),
        },
      },
    );
  }

  const url = new URL(req.url);
  const params = url.searchParams;

  try {
    structuredLog("info", { requestId, action: `api_${req.method.toLowerCase()}`, userId, statusCode: 200 });
    switch (req.method) {
      case "GET":
        return await handleGet(supabase, userId, params);
      case "POST":
        return await handlePost(supabase, userId, req);
      case "PATCH":
        return await handlePatch(supabase, userId, req);
      case "DELETE":
        return await handleDelete(supabase, userId, params);
      default:
        structuredLog("warn", { requestId, action: "method_rejected", userId, statusCode: 405 });
        return jsonResponse({ error: "Method not allowed" }, 405);
    }
  } catch (error) {
    structuredLog("error", { requestId, action: "unhandled_error", userId, statusCode: 500, detail: String(error) });
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

async function handleGet(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  params: URLSearchParams,
) {
  const id = params.get("id");

  if (id) {
    const { data, error } = await supabase
      .from("commitments")
      .select("*")
      .eq("id", id)
      .eq("user_id", userId)
      .single();

    if (error || !data) {
      return jsonResponse({ error: "Commitment not found" }, 404);
    }
    return jsonResponse(data);
  }

  // List with filters
  let query = supabase
    .from("commitments")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const status = params.get("status");
  if (status) query = query.eq("status", status);

  const entity = params.get("entity");
  if (entity && entity.length <= 100) query = query.ilike("entity_name", `%${entity}%`);

  const limit = Math.min(Math.max(parseInt(params.get("limit") || "50") || 50, 1), 100);
  const offset = Math.max(parseInt(params.get("offset") || "0") || 0, 0);
  query = query.range(offset, offset + limit - 1);

  const { data, error, count } = await query;

  if (error) {
    return jsonResponse({ error: "Failed to fetch commitments" }, 500);
  }

  return jsonResponse({
    data: data || [],
    pagination: { limit, offset, total: count },
  });
}

async function parseJsonBody(req: Request): Promise<{ data?: Record<string, unknown>; error?: Response }> {
  try {
    const data = await req.json();
    return { data };
  } catch {
    return {
      error: jsonResponse(
        { error: "Malformed JSON in request body", fields: { body: "Must be valid JSON" } },
        400,
      ),
    };
  }
}

const POST_ALLOWED_FIELDS = [
  "entity_name", "summary", "full_text", "deadline",
  "dollar_amount", "status", "confidence", "ai_reasoning", "notes",
];

const PATCH_ALLOWED_FIELDS = [
  "id", "entity_name", "summary", "full_text", "deadline",
  "dollar_amount", "status", "notes",
];

async function handlePost(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  req: Request,
) {
  const { data: body, error: parseError } = await parseJsonBody(req);
  if (parseError) return parseError;

  const fieldErrors: Record<string, string> = {};

  const unexpectedKeys = Object.keys(body!).filter((k) => !POST_ALLOWED_FIELDS.includes(k));
  if (unexpectedKeys.length > 0) {
    for (const key of unexpectedKeys) {
      fieldErrors[key] = "Unexpected field";
    }
  }

  const required = ["entity_name", "summary"];
  for (const field of required) {
    if (!body![field] || typeof body![field] !== "string") {
      fieldErrors[field] = "Required, must be a non-empty string";
    }
  }

  if (Object.keys(fieldErrors).length > 0) {
    return jsonResponse({ error: "Validation failed", fields: fieldErrors }, 400);
  }

  const commitment = {
    user_id: userId,
    entity_name: body!.entity_name,
    summary: body!.summary,
    full_text: body!.full_text || body!.summary,
    deadline: body!.deadline || null,
    dollar_amount: body!.dollar_amount || null,
    status: body!.status || "pending",
    confidence: body!.confidence || 10,
    ai_reasoning: body!.ai_reasoning || "Created via API",
    source: "manual",
    notes: body!.notes || null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const { data, error } = await supabase
    .from("commitments")
    .insert(commitment)
    .select()
    .single();

  if (error) {
    return jsonResponse({ error: "Failed to create commitment" }, 500);
  }

  return jsonResponse(data, 201);
}

async function handlePatch(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  req: Request,
) {
  const { data: body, error: parseError } = await parseJsonBody(req);
  if (parseError) return parseError;

  const fieldErrors: Record<string, string> = {};

  if (!body!.id || typeof body!.id !== "string") {
    fieldErrors.id = "Required, must be a non-empty string";
  }

  const unexpectedKeys = Object.keys(body!).filter((k) => !PATCH_ALLOWED_FIELDS.includes(k));
  if (unexpectedKeys.length > 0) {
    for (const key of unexpectedKeys) {
      fieldErrors[key] = "Unexpected field";
    }
  }

  if (Object.keys(fieldErrors).length > 0) {
    return jsonResponse({ error: "Validation failed", fields: fieldErrors }, 400);
  }

  const allowedFields = [
    "entity_name", "summary", "full_text", "deadline",
    "dollar_amount", "status", "notes",
  ];
  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

  for (const field of allowedFields) {
    if (body![field] !== undefined) {
      updates[field] = body![field];
    }
  }

  const { data, error } = await supabase
    .from("commitments")
    .update(updates)
    .eq("id", body!.id as string)
    .eq("user_id", userId)
    .select()
    .single();

  if (error || !data) {
    return jsonResponse({ error: "Commitment not found or update failed" }, 404);
  }

  return jsonResponse(data);
}

async function handleDelete(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  params: URLSearchParams,
) {
  const id = params.get("id");
  if (!id) {
    return jsonResponse({ error: "Missing commitment id" }, 400);
  }

  const { error } = await supabase
    .from("commitments")
    .delete()
    .eq("id", id)
    .eq("user_id", userId);

  if (error) {
    return jsonResponse({ error: "Failed to delete commitment" }, 500);
  }

  return jsonResponse({ deleted: true });
}

function jsonResponse(data: unknown, status = 200, req?: Request) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...SECURITY_HEADERS,
  };
  if (req) {
    Object.assign(headers, corsHeaders(req));
  }
  return new Response(JSON.stringify(data), { status, headers });
}
