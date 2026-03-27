import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
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

interface CommitmentExtraction {
  commitments: Array<{
    text: string;
    made_by: string;
    made_to: string;
    type: "firm_promise" | "soft_commitment" | "informational" | "irrelevant";
    category: "housing" | "freelance" | "purchases" | "personal" | "medical" | "insurance" | "uncategorized";
    deadline: string | null;
    dollar_amount: number | null;
    confidence: number;
    reasoning: string;
  }>;
  rejected: Array<{
    text: string;
    type: string;
    confidence: number;
    reasoning: string;
  }>;
}

const EXTRACTION_PROMPT = `You are a commitment extraction engine. Analyze the following text extracted from a screenshot and identify ALL commitments, promises, deadlines, and dollar amounts.

For each commitment found, determine:
1. The exact text of the commitment
2. Who made the commitment (the person/entity making the promise)
3. Who the commitment was made to (usually "User")
4. The type: "firm_promise" (explicit guarantee with deadline), "soft_commitment" (stated intention without firm deadline), "informational" (price quote/estimate, not a promise), or "irrelevant" (no actionable commitment)
5. The category — classify the commitment into one of: "housing" (landlord, rent, repairs, maintenance, lease), "freelance" (payments, invoices, client work, contracts), "purchases" (orders, deliveries, refunds, warranties, returns), "medical" (appointments, prescriptions, procedures, billing), "insurance" (claims, coverage, payouts), "personal" (friends, family, personal favors), or "uncategorized" if none fit
6. The deadline (as ISO 8601 date yyyy-MM-dd if detectable, null otherwise). If the text says "next Friday" or "by end of month", resolve it relative to today's date.
7. Any dollar amount mentioned (as a number, null if none)
8. A confidence score from 1-10:
   - 9-10: Explicit, unambiguous commitment with clear deadline
   - 7-8: Clear commitment, deadline may be implicit
   - 4-6: Possible commitment, some hedging or ambiguity
   - 1-3: Very weak or no real commitment detected
8. Reasoning explaining why you assigned that confidence score. Flag any hedging language ("try to", "might", "probably", "hopefully", "if possible") that weakens the commitment.

Respond ONLY with valid JSON matching this schema:
{
  "commitments": [{ "text", "made_by", "made_to", "type", "category", "deadline", "dollar_amount", "confidence", "reasoning" }],
  "rejected": [{ "text", "type", "confidence", "reasoning" }]
}

Place items with confidence >= 4 in "commitments" and items with confidence < 4 in "rejected".
Do not include any text outside the JSON object.`;

const ALLOWED_ORIGINS = ["https://seddly.com", "https://www.seddly.com"];
const MAX_TEXT_LENGTH = 10000; // 10K char limit
const RATE_LIMIT_MAX = 10; // 10 requests per window
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute window

const kv = await Deno.openKv();

async function checkRateLimit(userId: string): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
  const key = ["rate_limit", "extract-commitments", userId];
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
    "Access-Control-Allow-Methods": "POST",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    structuredLog("warn", { requestId, action: "method_rejected", statusCode: 405 });
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders(req) },
    });
  }

  // Auth: require Bearer token (Supabase JWT)
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    structuredLog("warn", { requestId, action: "auth_missing", statusCode: 401 });
    return new Response(
      JSON.stringify({ error: "Authentication required. Provide a valid Bearer token." }),
      { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }

  const token = authHeader.replace("Bearer ", "");
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    structuredLog("warn", { requestId, action: "auth_failed", statusCode: 401 });
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }

  const userId = user.id;

  // Rate limiting: 10 requests per minute per user
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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    structuredLog("warn", { requestId, action: "invalid_json", userId, statusCode: 400 });
    return new Response(
      JSON.stringify({ error: "Malformed JSON in request body", fields: { body: "Must be valid JSON" } }),
      { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }

  try {
    const textRaw = body.text;

    if (!textRaw || typeof textRaw !== "string" || textRaw.trim().length === 0) {
      structuredLog("warn", { requestId, action: "validation_failed", userId, statusCode: 400, field: "text" });
      return new Response(
        JSON.stringify({ error: "Validation failed", fields: { text: "Required, must be a non-empty string" } }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    const text: string = textRaw;

    if (text.length > MAX_TEXT_LENGTH) {
      structuredLog("warn", { requestId, action: "validation_failed", userId, statusCode: 400, field: "text_too_long", textLength: text.length });
      return new Response(
        JSON.stringify({ error: "Validation failed", fields: { text: `Must not exceed ${MAX_TEXT_LENGTH} characters` } }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    structuredLog("info", { requestId, action: "extraction_started", userId, textLength: text.length });

    const today = new Date().toISOString().split("T")[0];

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 2048,
        messages: [
          {
            role: "user",
            content: `${EXTRACTION_PROMPT}\n\nToday's date: ${today}\n\nExtracted text from screenshot:\n\n${text}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      structuredLog("error", { requestId, action: "ai_api_error", userId, statusCode: 502, upstreamStatus: response.status, detail: errorBody.substring(0, 500) });
      return new Response(
        JSON.stringify({ error: "AI processing failed" }),
        { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    const aiResponse = await response.json();
    const content = aiResponse.content?.[0]?.text;

    if (!content) {
      structuredLog("warn", { requestId, action: "ai_empty_response", userId, statusCode: 200 });
      return new Response(
        JSON.stringify({ commitments: [], rejected: [] }),
        { headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    // Parse the JSON from Claude's response safely
    let extraction: CommitmentExtraction;
    try {
      extraction = JSON.parse(content);
    } catch {
      structuredLog("error", { requestId, action: "ai_parse_error", userId, statusCode: 200, responseLength: content.length });
      return new Response(
        JSON.stringify({ commitments: [], rejected: [] }),
        { headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    // Validate response structure
    if (!Array.isArray(extraction.commitments)) {
      extraction.commitments = [];
    }
    if (!Array.isArray(extraction.rejected)) {
      extraction.rejected = [];
    }

    // Log extraction to privacy_audit_log
    await supabase.from("privacy_audit_log").insert({
      user_id: userId,
      event_type: "ai_extraction",
      destination: "anthropic_api",
      data_summary: `Extracted ${extraction.commitments.length} commitments, ${extraction.rejected.length} rejected`,
      text_length_sent: text.length,
    });

    structuredLog("info", {
      requestId, action: "extraction_completed", userId, statusCode: 200,
      commitmentsFound: extraction.commitments.length, rejectedCount: extraction.rejected.length,
    });

    return new Response(JSON.stringify(extraction), {
      headers: { "Content-Type": "application/json", ...corsHeaders(req) },
    });
  } catch (error) {
    structuredLog("error", { requestId, action: "unhandled_error", userId, statusCode: 500, detail: String(error) });
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }
});
