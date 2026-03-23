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
}

interface DecodedNotification {
  notificationType: NotificationType;
  data: {
    signedTransactionInfo: string;
  };
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

    // In production, verify the JWS signature from Apple
    // For now, decode the payload directly
    const notification = body as DecodedNotification;
    const { notificationType } = notification;

    // Decode the signed transaction info (JWS)
    // In production, verify the signature against Apple's certificate chain
    const transactionParts =
      notification.data.signedTransactionInfo.split(".");
    const transactionPayload = JSON.parse(
      atob(transactionParts[1]),
    ) as SignedTransactionInfo;

    const { originalTransactionId, productId, expiresDate } =
      transactionPayload;

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
