import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Pro+ API Access — RESTful endpoints for commitment data
// GET /api-commitments — list commitments (supports ?status=, ?entity=, ?limit=, ?offset=)
// GET /api-commitments?id=<uuid> — get single commitment
// POST /api-commitments — create commitment
// PATCH /api-commitments — update commitment (requires id in body)
// DELETE /api-commitments?id=<uuid> — delete commitment

Deno.serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
      },
    });
  }

  // Auth: require Bearer token (Supabase JWT) or X-API-Key
  const authHeader = req.headers.get("Authorization");
  const apiKey = req.headers.get("X-API-Key");

  if (!authHeader && !apiKey) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Verify user from JWT
  let userId: string;
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      return jsonResponse({ error: "Invalid token" }, 401);
    }

    // Verify Pro+ subscription
    const { data: userData } = await supabase
      .from("users")
      .select("subscription_tier")
      .eq("id", user.id)
      .single();

    if (!userData || userData.subscription_tier !== "pro_plus") {
      return jsonResponse({ error: "API access requires Pro+ subscription" }, 403);
    }

    userId = user.id;
  } else {
    return jsonResponse({ error: "Bearer token required" }, 401);
  }

  const url = new URL(req.url);
  const params = url.searchParams;

  try {
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
        return jsonResponse({ error: "Method not allowed" }, 405);
    }
  } catch (error) {
    console.error("API error:", error);
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
  if (entity) query = query.ilike("entity_name", `%${entity}%`);

  const limit = parseInt(params.get("limit") || "50");
  const offset = parseInt(params.get("offset") || "0");
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

async function handlePost(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  req: Request,
) {
  const body = await req.json();

  const required = ["entity_name", "summary"];
  for (const field of required) {
    if (!body[field]) {
      return jsonResponse({ error: `Missing required field: ${field}` }, 400);
    }
  }

  const commitment = {
    user_id: userId,
    entity_name: body.entity_name,
    summary: body.summary,
    full_text: body.full_text || body.summary,
    deadline: body.deadline || null,
    dollar_amount: body.dollar_amount || null,
    status: body.status || "pending",
    confidence: body.confidence || 10,
    ai_reasoning: body.ai_reasoning || "Created via API",
    source: "manual",
    notes: body.notes || null,
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
  const body = await req.json();

  if (!body.id) {
    return jsonResponse({ error: "Missing commitment id" }, 400);
  }

  const allowedFields = [
    "entity_name", "summary", "full_text", "deadline",
    "dollar_amount", "status", "notes",
  ];
  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

  for (const field of allowedFields) {
    if (body[field] !== undefined) {
      updates[field] = body[field];
    }
  }

  const { data, error } = await supabase
    .from("commitments")
    .update(updates)
    .eq("id", body.id)
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

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
