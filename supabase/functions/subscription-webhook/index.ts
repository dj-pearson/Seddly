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

// ──────────────────────────────────────────────────────────────
// Apple Root CA - G3 (base64 DER)
// Trust anchor for App Store Server Notifications V2
// Subject: CN=Apple Root CA - G3, OU=Apple Certification Authority, O=Apple Inc., C=US
// Valid: 2014-04-30 to 2039-04-30
// ──────────────────────────────────────────────────────────────
const APPLE_ROOT_CA_G3_BASE64 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS" +
  "QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u" +
  "IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN" +
  "MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS" +
  "b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y" +
  "aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49" +
  "AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf" +
  "TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517" +
  "IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3GKhOtABF6JagSIx0bxnp0B0" +
  "MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA" +
  "MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4" +
  "at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM" +
  "6BgD56KyKA==";

// ──────────────────────────────────────────────────────────────
// App Store Server Notifications V2 Types
// ──────────────────────────────────────────────────────────────

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

const EXPECTED_BUNDLE_ID = "com.pearsonmedia.Seddly";

// ──────────────────────────────────────────────────────────────
// Base64 Utilities
// ──────────────────────────────────────────────────────────────

function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function base64urlToBytes(b64url: string): Uint8Array {
  let b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4) b64 += "=";
  return base64ToBytes(b64);
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

// ──────────────────────────────────────────────────────────────
// Minimal DER/ASN.1 Parser
// ──────────────────────────────────────────────────────────────

interface DERElement {
  tag: number;
  value: Uint8Array;
  raw: Uint8Array;
  children?: DERElement[];
}

function parseDER(data: Uint8Array, offset = 0): DERElement {
  const start = offset;
  const tag = data[offset++];
  let length = data[offset++];

  if (length & 0x80) {
    const numBytes = length & 0x7f;
    length = 0;
    for (let i = 0; i < numBytes; i++) {
      length = (length << 8) | data[offset++];
    }
  }

  const headerLen = offset - start;
  const value = data.slice(start + headerLen, start + headerLen + length);
  const raw = data.slice(start, start + headerLen + length);

  const element: DERElement = { tag, value, raw };

  if (tag & 0x20) {
    element.children = [];
    let childOffset = 0;
    while (childOffset < value.length) {
      const child = parseDER(value, childOffset);
      element.children.push(child);
      childOffset += child.raw.length;
    }
  }

  return element;
}

// ──────────────────────────────────────────────────────────────
// X.509 Certificate Parsing
// ──────────────────────────────────────────────────────────────

function extractSPKI(certDER: Uint8Array): Uint8Array {
  const cert = parseDER(certDER);
  const tbs = cert.children![0];
  const tbsChildren = tbs.children!;
  const spkiIndex = tbsChildren[0].tag === 0xa0 ? 6 : 5;
  return tbsChildren[spkiIndex].raw;
}

function extractTBS(certDER: Uint8Array): Uint8Array {
  const cert = parseDER(certDER);
  return cert.children![0].raw;
}

function extractCertSignature(certDER: Uint8Array): Uint8Array {
  const cert = parseDER(certDER);
  const sigBitString = cert.children![2];
  return sigBitString.value.slice(1);
}

function extractSignatureAlgorithmOID(certDER: Uint8Array): Uint8Array {
  const cert = parseDER(certDER);
  return cert.children![1].children![0].value;
}

function getCurveFromSPKI(spkiBytes: Uint8Array): "P-256" | "P-384" {
  const spki = parseDER(spkiBytes);
  const curveOID = spki.children![0].children![1].value;
  // P-256 OID: 1.2.840.10045.3.1.7 encoded as 2a 86 48 ce 3d 03 01 07
  if (
    curveOID.length === 8 && curveOID[0] === 0x2a && curveOID[7] === 0x07
  ) {
    return "P-256";
  }
  // P-384 OID: 1.3.132.0.34 encoded as 2b 81 04 00 22
  if (
    curveOID.length === 5 && curveOID[0] === 0x2b && curveOID[4] === 0x22
  ) {
    return "P-384";
  }
  throw new Error("Unsupported EC curve in certificate");
}

function getHashFromSignatureOID(oidBytes: Uint8Array): "SHA-256" | "SHA-384" {
  // ecdsa-with-SHA256: ...04.03.02
  // ecdsa-with-SHA384: ...04.03.03
  if (oidBytes.length >= 8 && oidBytes[7] === 0x02) return "SHA-256";
  if (oidBytes.length >= 8 && oidBytes[7] === 0x03) return "SHA-384";
  throw new Error("Unsupported signature algorithm OID");
}

function derSignatureToP1363(
  derSig: Uint8Array,
  componentSize: number,
): Uint8Array {
  const seq = parseDER(derSig);
  const rBytes = seq.children![0].value;
  const sBytes = seq.children![1].value;

  const result = new Uint8Array(componentSize * 2);

  const rStart = rBytes[0] === 0 ? 1 : 0;
  const rLen = rBytes.length - rStart;
  result.set(rBytes.slice(rStart), componentSize - rLen);

  const sStart = sBytes[0] === 0 ? 1 : 0;
  const sLen = sBytes.length - sStart;
  result.set(sBytes.slice(sStart), componentSize * 2 - sLen);

  return result;
}

// ──────────────────────────────────────────────────────────────
// Certificate Chain Verification
// ──────────────────────────────────────────────────────────────

async function verifyCertSignature(
  childDER: Uint8Array,
  parentDER: Uint8Array,
): Promise<void> {
  const tbs = extractTBS(childDER);
  const sigBytes = extractCertSignature(childDER);
  const sigOID = extractSignatureAlgorithmOID(childDER);
  const hash = getHashFromSignatureOID(sigOID);

  const parentSPKI = extractSPKI(parentDER);
  const parentCurve = getCurveFromSPKI(parentSPKI);
  const componentSize = parentCurve === "P-256" ? 32 : 48;

  const parentKey = await crypto.subtle.importKey(
    "spki",
    parentSPKI,
    { name: "ECDSA", namedCurve: parentCurve },
    false,
    ["verify"],
  );

  const p1363Sig = derSignatureToP1363(sigBytes, componentSize);

  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash },
    parentKey,
    p1363Sig,
    tbs,
  );

  if (!valid) {
    throw new Error("Certificate chain signature verification failed");
  }
}

// ──────────────────────────────────────────────────────────────
// Apple JWS Verification
// ──────────────────────────────────────────────────────────────

async function verifyAppleJWS<T>(jws: string): Promise<T> {
  const parts = jws.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWS format: expected 3 parts");
  }

  const [headerB64, payloadB64, signatureB64] = parts;
  const header = JSON.parse(
    new TextDecoder().decode(base64urlToBytes(headerB64)),
  );

  if (!header.x5c || !Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error("JWS missing x5c certificate chain");
  }

  if (!header.alg || !["ES256", "PS256"].includes(header.alg)) {
    throw new Error(`Unsupported JWS algorithm: ${header.alg}`);
  }

  // Decode the certificate chain from x5c header
  const certChain: Uint8Array[] = header.x5c.map((b64: string) =>
    base64ToBytes(b64)
  );

  // Verify root certificate matches pinned Apple Root CA - G3
  const rootCertDER = certChain[certChain.length - 1];
  const appleRootDER = base64ToBytes(APPLE_ROOT_CA_G3_BASE64);
  if (!bytesEqual(rootCertDER, appleRootDER)) {
    throw new Error(
      "Certificate chain root does not match Apple Root CA - G3",
    );
  }

  // Verify each certificate is signed by the next in the chain
  for (let i = 0; i < certChain.length - 1; i++) {
    await verifyCertSignature(certChain[i], certChain[i + 1]);
  }

  // Verify root certificate is self-signed
  await verifyCertSignature(rootCertDER, rootCertDER);

  // Verify the JWS signature using the leaf certificate's public key
  const leafSPKI = extractSPKI(certChain[0]);
  const leafCurve = getCurveFromSPKI(leafSPKI);

  const leafKey = await crypto.subtle.importKey(
    "spki",
    leafSPKI,
    { name: "ECDSA", namedCurve: leafCurve },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(
    `${headerB64}.${payloadB64}`,
  );
  const signature = base64urlToBytes(signatureB64);

  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: leafCurve === "P-256" ? "SHA-256" : "SHA-384" },
    leafKey,
    signature,
    signingInput,
  );

  if (!valid) {
    throw new Error("JWS signature verification failed");
  }

  return JSON.parse(
    new TextDecoder().decode(base64urlToBytes(payloadB64)),
  ) as T;
}

// ──────────────────────────────────────────────────────────────
// Webhook Handler
// ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  if (req.method !== "POST") {
    structuredLog("warn", { requestId, action: "method_rejected", statusCode: 405 });
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
    });
  }

  try {
    const body = await req.json();

    if (!body.signedPayload) {
      structuredLog("warn", { requestId, action: "missing_payload", statusCode: 400 });
      return new Response(
        JSON.stringify({ error: "Missing signed notification payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Verify and decode the signed notification payload
    let notification: DecodedNotification;
    try {
      notification = await verifyAppleJWS<DecodedNotification>(
        body.signedPayload,
      );
    } catch (verifyError) {
      structuredLog("error", { requestId, action: "jws_verification_failed", statusCode: 400, detail: String(verifyError) });
      return new Response(
        JSON.stringify({ error: "Invalid JWS signature" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const { notificationType } = notification;

    if (!notification.data?.signedTransactionInfo) {
      structuredLog("warn", { requestId, action: "missing_transaction_info", statusCode: 400 });
      return new Response(
        JSON.stringify({ error: "Missing transaction info" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Verify and decode the signed transaction info
    let transactionPayload: SignedTransactionInfo;
    try {
      transactionPayload = await verifyAppleJWS<SignedTransactionInfo>(
        notification.data.signedTransactionInfo,
      );
    } catch (verifyError) {
      structuredLog("error", { requestId, action: "transaction_jws_failed", statusCode: 400, detail: String(verifyError) });
      return new Response(
        JSON.stringify({ error: "Invalid transaction signature" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Validate bundle ID to prevent cross-app replay attacks
    if (
      transactionPayload.bundleId &&
      transactionPayload.bundleId !== EXPECTED_BUNDLE_ID
    ) {
      structuredLog("error", { requestId, action: "bundle_id_mismatch", statusCode: 403, receivedBundleId: transactionPayload.bundleId });
      return new Response(
        JSON.stringify({ error: "Invalid bundle ID" }),
        { status: 403, headers: { "Content-Type": "application/json" } },
      );
    }

    const { originalTransactionId, productId, expiresDate } =
      transactionPayload;

    if (!originalTransactionId || !productId) {
      structuredLog("warn", { requestId, action: "missing_transaction_fields", statusCode: 400 });
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
      structuredLog("error", { requestId, action: "db_update_failed", statusCode: 500, notificationType, detail: String(error) });
      return new Response(
        JSON.stringify({ error: "Database update failed" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
        },
      );
    }

    structuredLog("info", { requestId, action: "webhook_processed", statusCode: 200, notificationType, tier, subscriptionStatus: status });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
    });
  } catch (error) {
    structuredLog("error", { requestId, action: "unhandled_error", statusCode: 500, detail: String(error) });
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", ...SECURITY_HEADERS },
      },
    );
  }
});
