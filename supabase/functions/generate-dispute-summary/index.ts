import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

interface Commitment {
  summary: string;
  deadline: string | null;
  dollar_amount: number | null;
  status: string;
  screenshot_date: string;
  source: string;
  confidence: number;
}

const SUMMARY_PROMPT = `You are generating a formal dispute timeline document. This document may be used in landlord-tenant disputes, freelance payment disputes, insurance claims, or customer service escalations.

Given the following commitments from a single entity, create a professional, chronological timeline. The tone should be factual, clear, and suitable for forwarding to a lawyer, property manager, or customer service escalation team.

Format:
1. Start with "Timeline of commitments from [Entity Name]:"
2. List each commitment chronologically with:
   - Date the commitment was made
   - What was promised
   - The deadline (if any)
   - The dollar amount (if any)
   - Current status (pending, fulfilled, overdue, disputed)
   - Source (screenshot, manual entry)
3. End with a summary: "X of Y commitments fulfilled. Z overdue."

Use plain, professional language. No legal conclusions — just facts and dates.
Respond with the formatted text only, no JSON wrapping.`;

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
    const { entity_name, commitments } = (await req.json()) as {
      entity_name: string;
      commitments: Commitment[];
    };

    if (!entity_name || !commitments?.length) {
      return new Response(
        JSON.stringify({ error: "Missing entity_name or commitments" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const commitmentsText = commitments
      .map(
        (c, i) =>
          `${i + 1}. Summary: "${c.summary}" | Date: ${c.screenshot_date} | Deadline: ${c.deadline ?? "None"} | Amount: ${c.dollar_amount ? `$${c.dollar_amount}` : "None"} | Status: ${c.status} | Source: ${c.source}`,
      )
      .join("\n");

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        messages: [
          {
            role: "user",
            content: `${SUMMARY_PROMPT}\n\nEntity Name: ${entity_name}\n\nCommitments:\n${commitmentsText}`,
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
    const summaryText = aiResponse.content?.[0]?.text ?? "";

    return new Response(
      JSON.stringify({ summary: summaryText }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
