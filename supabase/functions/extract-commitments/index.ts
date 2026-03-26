import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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
const MAX_TEXT_LENGTH = 50000; // 50KB limit
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
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders(req) },
    });
  }

  // Auth: require Bearer token (Supabase JWT)
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Authentication required. Provide a valid Bearer token." }),
      { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }

  const token = authHeader.replace("Bearer ", "");
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }

  // Rate limiting: 10 requests per minute per user
  const rateLimit = await checkRateLimit(user.id);
  if (!rateLimit.allowed) {
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

  try {
    const { text } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing or empty 'text' field" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    if (text.length > MAX_TEXT_LENGTH) {
      return new Response(
        JSON.stringify({ error: `Text exceeds maximum length of ${MAX_TEXT_LENGTH} characters` }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

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
      console.error("Anthropic API error:", response.status, errorBody);
      return new Response(
        JSON.stringify({ error: "AI processing failed" }),
        { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
      );
    }

    const aiResponse = await response.json();
    const content = aiResponse.content?.[0]?.text;

    if (!content) {
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
      console.error("Failed to parse AI response as JSON:", content.substring(0, 200));
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

    return new Response(JSON.stringify(extraction), {
      headers: { "Content-Type": "application/json", ...corsHeaders(req) },
    });
  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders(req) } },
    );
  }
});
