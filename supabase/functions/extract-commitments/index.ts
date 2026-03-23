import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

interface CommitmentExtraction {
  commitments: Array<{
    text: string;
    made_by: string;
    made_to: string;
    type: "firm_promise" | "soft_commitment" | "informational" | "irrelevant";
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
5. The deadline (as ISO 8601 date yyyy-MM-dd if detectable, null otherwise). If the text says "next Friday" or "by end of month", resolve it relative to today's date.
6. Any dollar amount mentioned (as a number, null if none)
7. A confidence score from 1-10:
   - 9-10: Explicit, unambiguous commitment with clear deadline
   - 7-8: Clear commitment, deadline may be implicit
   - 4-6: Possible commitment, some hedging or ambiguity
   - 1-3: Very weak or no real commitment detected
8. Reasoning explaining why you assigned that confidence score. Flag any hedging language ("try to", "might", "probably", "hopefully", "if possible") that weakens the commitment.

Respond ONLY with valid JSON matching this schema:
{
  "commitments": [{ "text", "made_by", "made_to", "type", "deadline", "dollar_amount", "confidence", "reasoning" }],
  "rejected": [{ "text", "type", "confidence", "reasoning" }]
}

Place items with confidence >= 4 in "commitments" and items with confidence < 4 in "rejected".
Do not include any text outside the JSON object.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { text } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing or empty 'text' field" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
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
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const aiResponse = await response.json();
    const content = aiResponse.content?.[0]?.text;

    if (!content) {
      return new Response(
        JSON.stringify({ commitments: [], rejected: [] }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Parse the JSON from Claude's response
    const extraction: CommitmentExtraction = JSON.parse(content);

    return new Response(JSON.stringify(extraction), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
