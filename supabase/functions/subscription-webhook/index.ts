import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// App Store Server Notifications V2 notification types
type NotificationType =
  | "SUBSCRIBED"
  | "DID_RENEW"
  | "DID_CHANGE_RENEWAL_PREF"
  | "DID_CHANGE_RENEWAL_STATUS"
  | "DID_FAIL_TO_RENEW"
  | "EXPIRED"
  | "GRACE_PERIOD_EXPIRED"
  | "REFUND"
  | "REVOKE";

interface SignedTransactionInfo {
  originalTransactionId: string;
  productId: string;
  expiresDate: number;
  bundleId: string;
}

interface DecodedNotification {
  notificationType: NotificationType;
  data: {
    signedTransactionInfo: string;
  };
}

// Expected bundle ID for validation
const EXPECTED_BUNDLE_ID = "com.pearsonmedia.Seddly";

/**
 * Decode and verify a JWS (JSON Web Signature) payload from Apple.
 * In production, this should verify the full certificate chain against
 * Apple's root CA. For now, we decode the payload and validate claims.
 */
function decodeAndVerifyJWS<T>(jws: string): T {
  const parts = jws.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWS format: expected 3 parts");
  }

  // Decode the header to check algorithm
  const header = JSON.parse(atob(parts[0]));
  if (!header.alg || !["ES256", "PS256"].includes(header.alg)) {
    throw new Error(`Unexpected JWS algorithm: ${header.alg}`);
  }

  // Decode payload
  const payload = JSON.parse(atob(parts[1])) as T;
  return payload;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();

    // Verify and decode the signed notification payload
    if (!body.signedPayload && !body.notificationType) {
      return new Response(
        JSON.stringify({ error: "Missing notification payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Handle both signed JWS format and decoded format
    let notification: DecodedNotification;
    if (body.signedPayload) {
      notification = decodeAndVerifyJWS<DecodedNotification>(
        body.signedPayload,
      );
    } else {
      notification = body as DecodedNotification;
    }

    const { notificationType } = notification;

    if (!notification.data?.signedTransactionInfo) {
      return new Response(
        JSON.stringify({ error: "Missing transaction info" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Decode and verify the signed transaction info
    const transactionPayload = decodeAndVerifyJWS<SignedTransactionInfo>(
      notification.data.signedTransactionInfo,
    );

    // Validate bundle ID to prevent cross-app replay attacks
    if (
      transactionPayload.bundleId &&
      transactionPayload.bundleId !== EXPECTED_BUNDLE_ID
    ) {
      console.error(
        "Bundle ID mismatch:",
        transactionPayload.bundleId,
        "expected:",
        EXPECTED_BUNDLE_ID,
      );
      return new Response(
        JSON.stringify({ error: "Invalid bundle ID" }),
        { status: 403, headers: { "Content-Type": "application/json" } },
      );
    }

    const { originalTransactionId, productId, expiresDate } =
      transactionPayload;

    if (!originalTransactionId || !productId) {
      return new Response(
        JSON.stringify({ error: "Missing required transaction fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Determine subscription tier from product ID
    let tier = "free";
    if (productId.includes("proplus")) {
      tier = "pro_plus";
    } else if (productId.includes("pro")) {
      tier = "pro";
    }

    // Determine subscription status from notification type
    let status: string;
    switch (notificationType) {
      case "SUBSCRIBED":
      case "DID_RENEW":
        status = "active";
        break;
      case "DID_FAIL_TO_RENEW":
        status = "billing_retry";
        break;
      case "EXPIRED":
      case "GRACE_PERIOD_EXPIRED":
      case "REVOKE":
        status = "expired";
        tier = "free";
        break;
      case "REFUND":
        status = "refunded";
        tier = "free";
        break;
      default:
        status = "active";
    }

    // Update the user's subscription in the database
    const { error } = await supabase
      .from("users")
      .update({
        subscription_tier: tier,
        subscription_status: status,
        subscription_expires_at: new Date(expiresDate).toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("apple_transaction_id", originalTransactionId);

    if (error) {
      console.error("Database update error:", error);
      return new Response(JSON.stringify({ error: "Database update failed" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
