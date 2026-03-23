# Seddly — Complete Setup Guide

Everything needed to go from a fresh clone to a working CI/CD pipeline, backend, and marketing site.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Apple Developer Setup](#2-apple-developer-setup)
3. [App Store Connect API Key](#3-app-store-connect-api-key)
4. [Code Signing (Certificates & Profiles)](#4-code-signing-certificates--profiles)
5. [Supabase Backend Setup](#5-supabase-backend-setup)
6. [Anthropic API Key](#6-anthropic-api-key)
7. [Cloudflare Setup](#7-cloudflare-setup)
8. [GitHub Repository Configuration](#8-github-repository-configuration)
9. [StoreKit Product Registration](#9-storekit-product-registration)
10. [First Build Verification](#10-first-build-verification)
11. [Post-Launch Checklist](#11-post-launch-checklist)
12. [Quick Reference — All Secrets](#12-quick-reference--all-secrets)

---

## 1. Prerequisites

You need accounts on the following services before starting:

| Service | URL | Cost |
|---------|-----|------|
| Apple Developer Program | https://developer.apple.com/programs/ | $99/year |
| GitHub | https://github.com | Free (Actions minutes on macOS: 10x multiplier) |
| Cloudflare | https://dash.cloudflare.com | Free tier sufficient |
| Anthropic | https://console.anthropic.com | Pay-per-use ($0.002-0.004/API call) |
| Contabo VPS (for Supabase) | https://contabo.com | ~$5-10/month |
| Coolify (for Supabase hosting) | https://coolify.io | Free (self-hosted) |

**Tools required on a Mac** (for initial certificate generation):
- Xcode 16.3+ installed
- Keychain Access
- Terminal / shell access

---

## 2. Apple Developer Setup

All of these steps happen at https://developer.apple.com/account/

### 2.1 Register App IDs

Go to **Certificates, Identifiers & Profiles → Identifiers → +**

Register two App IDs:

**App ID 1 — Main App**
- Platform: iOS
- Description: `Seddly`
- Bundle ID: `com.pearsonmedia.Seddly` (Explicit)
- Capabilities to enable:
  - ✅ App Groups
  - ✅ Push Notifications
  - ✅ Sign In with Apple
  - ✅ Background Modes (will be configured in Xcode, not here)

**App ID 2 — Share Extension**
- Platform: iOS
- Description: `Seddly Share Extension`
- Bundle ID: `com.pearsonmedia.Seddly.ShareExtension` (Explicit)
- Capabilities to enable:
  - ✅ App Groups

### 2.2 Register App Group

Go to **Identifiers → App Groups → +**

- Description: `Seddly Shared`
- Identifier: `group.com.pearsonmedia.Seddly`

Then go back to both App IDs above and assign this App Group to each one.

### 2.3 Register APNs Key (for Silent Push)

Go to **Keys → +**

- Key Name: `Seddly APNs`
- Enable: ✅ Apple Push Notifications service (APNs)
- Click Continue → Register

**Save these values — you only get one chance to download the key:**
- Key ID (10-character string, e.g., `ABC123DEF4`)
- Download the `.p8` file (e.g., `AuthKey_ABC123DEF4.p8`)
- Note your Team ID (visible at top-right of the portal, e.g., `9ABCDEF123`)

These become `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, and `APNS_TEAM_ID` in Supabase.

### 2.4 Note Your Team ID

Your 10-character Apple Developer Team ID is shown in **Membership Details** or at the top-right of the developer portal. Example: `9ABCDEF123`.

This becomes `APPLE_TEAM_ID` in GitHub Secrets.

---

## 3. App Store Connect API Key

Go to https://appstoreconnect.apple.com/access/integrations/api

### 3.1 Create a Key

- Click **Generate API Key** (or the + button)
- Name: `Seddly CI/CD`
- Access: **App Manager** (minimum role needed for TestFlight uploads)
- Click Generate

### 3.2 Save the Credentials

**Save these immediately — the private key can only be downloaded once:**

| Value | Where to Find It | Becomes GitHub Secret |
|-------|-------------------|----------------------|
| Issuer ID | Shown at top of the Keys page | `APP_STORE_CONNECT_ISSUER_ID` |
| Key ID | Shown in the key row (e.g., `2X9R4HXF34`) | `APP_STORE_CONNECT_API_KEY_ID` |
| Private Key (.p8 file) | Download button (one-time only) | `APP_STORE_CONNECT_API_PRIVATE_KEY` |

### 3.3 Encode the Private Key

```bash
base64 -i AuthKey_2X9R4HXF34.p8 | pbcopy
```

The clipboard now contains the base64-encoded key. This goes into `APP_STORE_CONNECT_API_PRIVATE_KEY`.

---

## 4. Code Signing (Certificates & Profiles)

### 4.1 Create a Distribution Certificate

**Option A — Via Xcode (easiest):**
1. Open Xcode → Settings → Accounts → Select your team
2. Click "Manage Certificates"
3. Click + → "Apple Distribution"
4. Xcode creates the certificate and installs it in your Keychain

**Option B — Via Apple Developer Portal:**
1. Go to **Certificates → +**
2. Select "Apple Distribution"
3. Create a Certificate Signing Request (CSR) via Keychain Access:
   - Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
   - Enter your email, select "Saved to disk"
4. Upload the CSR, download the `.cer` file
5. Double-click to install in Keychain

### 4.2 Export as .p12

1. Open **Keychain Access**
2. In the "login" keychain, find the "Apple Distribution: [Your Name]" certificate
3. Expand it to verify the private key is attached
4. Right-click → "Export..."
5. Format: Personal Information Exchange (.p12)
6. **Set a strong password** — you'll need this as `APPLE_CERTIFICATE_PASSWORD`
7. Save as `Certificates.p12`

### 4.3 Encode the Certificate

```bash
base64 -i Certificates.p12 | pbcopy
```

The clipboard now contains `APPLE_CERTIFICATE_P12`.

### 4.4 Create Provisioning Profiles

Go to **Certificates, Identifiers & Profiles → Profiles → +**

**Profile 1 — Main App**
- Type: App Store Connect
- App ID: `Seddly (com.pearsonmedia.Seddly)`
- Certificate: Select your Apple Distribution certificate
- Profile Name: `Seddly_AppStore`
- Download the `.mobileprovision` file

**Profile 2 — Share Extension**
- Type: App Store Connect
- App ID: `Seddly Share Extension (com.pearsonmedia.Seddly.ShareExtension)`
- Certificate: Select your Apple Distribution certificate
- Profile Name: `SeddlyShareExt_AppStore`
- Download the `.mobileprovision` file

### 4.5 Encode the Profiles

```bash
base64 -i Seddly_AppStore.mobileprovision | pbcopy
# Paste into PROVISIONING_PROFILE_APP

base64 -i SeddlyShareExt_AppStore.mobileprovision | pbcopy
# Paste into PROVISIONING_PROFILE_SHARE_EXT
```

**Important:** The profile names `Seddly_AppStore` and `SeddlyShareExt_AppStore` must match what's in `ExportOptions.plist`. If you name them differently in the portal, update `ExportOptions.plist` to match.

---

## 5. Supabase Backend Setup

### 5.1 Deploy Supabase on Contabo via Coolify

1. **Provision a Contabo VPS** (minimum: 4GB RAM, 2 vCPU)
2. **Install Coolify** on the VPS:
   ```bash
   curl -fsSL https://cdn.coolify.io/install.sh | bash
   ```
3. **Deploy Supabase** via Coolify's one-click service:
   - In Coolify dashboard → New Resource → Service → Supabase
   - This deploys PostgreSQL, GoTrue (auth), PostgREST, Edge Functions runtime, and Studio
4. **Note your Supabase URL** (e.g., `https://supabase.yourdomain.com`)
5. **Note your Service Role Key** from the Supabase Studio dashboard → Settings → API

### 5.2 Run the Database Migration

Connect to your Supabase PostgreSQL instance and run the migration:

```bash
psql "postgresql://postgres:YOUR_PASSWORD@your-server:5432/postgres" \
  -f supabase/migrations/20260323000000_initial_schema.sql
```

Or paste the SQL into Supabase Studio → SQL Editor.

### 5.3 Configure Edge Function Environment Variables

In Coolify (or your Supabase instance's environment config), set these env vars for the Edge Functions runtime:

| Variable | Value | Used By |
|----------|-------|---------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key (see Section 6) | extract-commitments, generate-dispute-summary |
| `SUPABASE_URL` | Your Supabase instance URL | subscription-webhook, send-silent-push |
| `SUPABASE_SERVICE_ROLE_KEY` | From Supabase Studio → Settings → API | subscription-webhook, send-silent-push |
| `APNS_KEY_ID` | From Section 2.3 | send-silent-push |
| `APNS_TEAM_ID` | Your Apple Developer Team ID | send-silent-push |
| `APNS_PRIVATE_KEY` | Base64 of the `.p8` file from Section 2.3 | send-silent-push |

### 5.4 Deploy Edge Functions

If using the Supabase CLI locally:
```bash
supabase functions deploy extract-commitments --project-ref YOUR_PROJECT_REF
supabase functions deploy generate-dispute-summary --project-ref YOUR_PROJECT_REF
supabase functions deploy subscription-webhook --project-ref YOUR_PROJECT_REF
supabase functions deploy send-silent-push --project-ref YOUR_PROJECT_REF
```

Or push to `main` and the `deploy-supabase.yml` workflow handles it (after GitHub Secrets are configured).

### 5.5 Enable pg_cron for Silent Push Scheduling

In Supabase Studio → SQL Editor, run:

```sql
-- Enable the pg_cron and pg_net extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule silent push twice daily
SELECT cron.schedule(
  'send-morning-push',
  '0 8 * * *',
  $$SELECT net.http_post(
    url := 'YOUR_SUPABASE_URL/functions/v1/send-silent-push',
    body := '{}'::jsonb
  )$$
);

SELECT cron.schedule(
  'send-evening-push',
  '0 20 * * *',
  $$SELECT net.http_post(
    url := 'YOUR_SUPABASE_URL/functions/v1/send-silent-push',
    body := '{}'::jsonb
  )$$
);
```

Replace `YOUR_SUPABASE_URL` with your actual Supabase URL.

### 5.6 Configure Apple Sign-In (Pro+ Only)

In Supabase Studio → Authentication → Providers → Apple:
1. Enable Apple provider
2. Enter your Service ID, Team ID, Key ID, and Private Key
3. Set the callback URL in your Apple Developer portal (Services IDs section)

### 5.7 Get Supabase CLI Credentials

For the GitHub Actions deploy workflow:

| Value | Where to Find It | Becomes GitHub Secret |
|-------|-------------------|----------------------|
| Project Ref | Supabase Studio → Settings → General → Reference ID | `SUPABASE_PROJECT_REF` |
| Access Token | https://supabase.com/dashboard/account/tokens (or generate via CLI) | `SUPABASE_ACCESS_TOKEN` |

**Note:** If self-hosting Supabase, you may need to configure the CLI to point at your instance rather than supabase.com. See `supabase login` and `supabase link` commands.

---

## 6. Anthropic API Key

1. Go to https://console.anthropic.com/settings/keys
2. Click **Create Key**
3. Name: `Seddly Production`
4. Copy the key (starts with `sk-ant-...`)

This key goes into:
- Supabase Edge Function env var: `ANTHROPIC_API_KEY`

**Estimated costs per the PRD:**

| User Type | AI Calls/Day | Monthly Cost/User |
|-----------|-------------|-------------------|
| Light | 1 | $0.06 |
| Average | 3 | $0.18 |
| Heavy | 6 | $0.36 |

Set a usage limit in the Anthropic console to prevent runaway costs during launch.

---

## 7. Cloudflare Setup

### 7.1 Add Your Domain

1. Go to https://dash.cloudflare.com
2. Add site: `seddly.com`
3. Update your domain registrar's nameservers to the ones Cloudflare provides
4. Wait for DNS propagation (usually 5-30 minutes)

### 7.2 Create a Cloudflare Pages Project

```bash
# Option A: Create via CLI after building the site
cd website
npm install
npm run build
npx wrangler pages project create seddly

# Option B: Create via Cloudflare dashboard
# Go to Workers & Pages → Create → Pages → Upload assets
```

### 7.3 Get API Credentials

**API Token:**
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use template: "Edit Cloudflare Workers"
4. Or create custom with permissions:
   - Account → Cloudflare Pages → Edit
   - Account → Workers Scripts → Edit
5. Copy the token

**Account ID:**
1. Go to any domain in Cloudflare dashboard
2. Scroll down on the Overview page → right sidebar → "Account ID"
3. Or go to https://dash.cloudflare.com → the URL contains your account ID

| Value | Becomes GitHub Secret |
|-------|----------------------|
| API Token | `CLOUDFLARE_API_TOKEN` |
| Account ID | `CLOUDFLARE_ACCOUNT_ID` |

### 7.4 DNS Records

After Cloudflare Pages is set up, add a CNAME record:
- Name: `@` (or `seddly.com`)
- Target: `seddly.pages.dev`
- Proxied: Yes

---

## 8. GitHub Repository Configuration

### 8.1 Add All Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

Add each secret from the table in [Section 12](#12-quick-reference--all-secrets).

### 8.2 Create the Production Environment

Go to **Settings → Environments → New environment**

- Name: `production`
- (Optional) Add required reviewers for deployment approval
- (Optional) Restrict to `main` branch only

The `release.yml` workflow references this environment, so it must exist.

### 8.3 Verify Workflow Permissions

Go to **Settings → Actions → General**

- Workflow permissions: **Read and write permissions**
- Allow GitHub Actions to create and approve pull requests: ✅ (if you want)

---

## 9. StoreKit Product Registration

### 9.1 Create the App in App Store Connect

1. Go to https://appstoreconnect.apple.com → My Apps → +
2. New App:
   - Platform: iOS
   - Name: `Seddly — Promise Tracker`
   - Primary Language: English (U.S.)
   - Bundle ID: `com.pearsonmedia.Seddly`
   - SKU: `seddly-ios`

### 9.2 Register Subscription Products

Go to **App → Subscriptions → +** (create a subscription group first)

**Subscription Group: "Seddly Premium"**

| Product ID | Reference Name | Duration | Price |
|------------|---------------|----------|-------|
| `com.pearsonmedia.Seddly.pro.monthly` | Pro Monthly | 1 Month | $4.99 |
| `com.pearsonmedia.Seddly.pro.yearly` | Pro Yearly | 1 Year | $39.99 |
| `com.pearsonmedia.Seddly.proplus.monthly` | Pro+ Monthly | 1 Month | $9.99 |
| `com.pearsonmedia.Seddly.proplus.yearly` | Pro+ Yearly | 1 Year | $79.99 |

These Product IDs must exactly match `SharedConstants.swift`.

### 9.3 Configure App Store Server Notifications V2

In App Store Connect → App → App Information → App Store Server Notifications:

- Production URL: `https://YOUR_SUPABASE_URL/functions/v1/subscription-webhook`
- Sandbox URL: Same URL (or a separate staging instance)
- Version: V2

This enables the `subscription-webhook` edge function to receive real-time subscription events.

### 9.4 StoreKit Testing Configuration (Development)

For local testing without real purchases, create a StoreKit Configuration file:

1. In Xcode: File → New → File → StoreKit Configuration File
2. Add the 4 subscription products with matching Product IDs
3. Set the scheme to use this configuration: Edit Scheme → Run → Options → StoreKit Configuration

---

## 10. First Build Verification

### 10.1 Verify CI (No Signing Required)

```bash
git push origin main
```

The `ci.yml` workflow should:
- ✅ Trigger on push
- ✅ Install XcodeGen
- ✅ Generate the Xcode project
- ✅ Build for iOS Simulator (no signing needed)
- ✅ Run unit tests
- ✅ Upload test results artifact

### 10.2 Verify Release Pipeline (Requires All Apple Secrets)

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `release.yml` workflow should:
- ✅ Generate Xcode project
- ✅ Import code signing certificate
- ✅ Install provisioning profiles
- ✅ Archive for Release
- ✅ Export IPA
- ✅ Upload to TestFlight
- ✅ Build appears in App Store Connect → TestFlight

### 10.3 Verify Website Deploy

Make any change to `website/` and push to `main`. The `deploy-website.yml` workflow should:
- ✅ Build the Astro site
- ✅ Deploy to Cloudflare Pages
- ✅ Site is live at `seddly.com`

### 10.4 Verify Edge Functions

Push any change to `supabase/functions/` and push to `main`. Or test manually:

```bash
curl -X POST https://YOUR_SUPABASE_URL/functions/v1/extract-commitments \
  -H "Content-Type: application/json" \
  -d '{"text": "I will fix your AC by next Friday, guaranteed."}'
```

Expected response:
```json
{
  "commitments": [{
    "text": "I will fix your AC by next Friday",
    "made_by": "Speaker",
    "made_to": "User",
    "type": "firm_promise",
    "deadline": "2026-03-27",
    "confidence": 9,
    "reasoning": "Explicit commitment with specific deadline. No hedging language."
  }],
  "rejected": []
}
```

---

## 11. Post-Launch Checklist

After all setup is complete and the first build is verified:

- [ ] Submit app for App Review with detailed review notes (see PRD Section 5.1)
- [ ] Include screen recording demo of permission flow in review notes
- [ ] Set Anthropic API usage limits in console
- [ ] Enable Cloudflare caching rules for the marketing site
- [ ] Set up error alerting for Edge Functions (Coolify or external monitoring)
- [ ] Create App Store screenshots and metadata
- [ ] Write the "How Your Data Works" blog post for SEO
- [ ] Test subscription flow end-to-end in Sandbox environment
- [ ] Verify silent push notifications work in TestFlight
- [ ] Update `aps-environment` from `development` to `production` in `Seddly.entitlements` for the release build

---

## 12. Quick Reference — All Secrets

### GitHub Repository Secrets

| Secret Name | Value Source | Used By |
|-------------|-------------|---------|
| `APPLE_TEAM_ID` | Apple Developer → Membership → Team ID | `release.yml`, `ExportOptions.plist` |
| `APPLE_CERTIFICATE_P12` | `base64 -i Certificates.p12` | `release.yml` |
| `APPLE_CERTIFICATE_PASSWORD` | Password you set when exporting .p12 | `release.yml` |
| `PROVISIONING_PROFILE_APP` | `base64 -i Seddly_AppStore.mobileprovision` | `release.yml` |
| `PROVISIONING_PROFILE_SHARE_EXT` | `base64 -i SeddlyShareExt_AppStore.mobileprovision` | `release.yml` |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Integrations → Keys | `release.yml` |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect → Integrations → Keys | `release.yml` |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | `base64 -i AuthKey_XXXX.p8` | `release.yml` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare → Profile → API Tokens | `deploy-website.yml` |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare dashboard → Overview sidebar | `deploy-website.yml` |
| `SUPABASE_PROJECT_REF` | Supabase Studio → Settings → General | `deploy-supabase.yml` |
| `SUPABASE_ACCESS_TOKEN` | Supabase dashboard → Account → Tokens | `deploy-supabase.yml` |

**Total: 12 GitHub Secrets**

### Supabase Edge Function Environment Variables

| Variable | Value Source | Used By |
|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | Anthropic Console → API Keys | extract-commitments, generate-dispute-summary |
| `SUPABASE_URL` | Your Supabase instance URL | subscription-webhook, send-silent-push |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Studio → Settings → API | subscription-webhook, send-silent-push |
| `APNS_KEY_ID` | Apple Developer → Keys | send-silent-push |
| `APNS_TEAM_ID` | Apple Developer → Membership | send-silent-push |
| `APNS_PRIVATE_KEY` | `base64 -i AuthKey_XXXX.p8` | send-silent-push |

**Total: 6 Supabase env vars**

### Identifiers Registered in Apple Developer Portal

| Identifier | Type |
|------------|------|
| `com.pearsonmedia.Seddly` | App ID |
| `com.pearsonmedia.Seddly.ShareExtension` | App ID |
| `group.com.pearsonmedia.Seddly` | App Group |
| APNs Key | Key |
| Apple Distribution Certificate | Certificate |
| `Seddly_AppStore` | Provisioning Profile |
| `SeddlyShareExt_AppStore` | Provisioning Profile |

### App Store Connect Products

| Product ID | Type |
|------------|------|
| `com.pearsonmedia.Seddly.pro.monthly` | Auto-Renewable Subscription |
| `com.pearsonmedia.Seddly.pro.yearly` | Auto-Renewable Subscription |
| `com.pearsonmedia.Seddly.proplus.monthly` | Auto-Renewable Subscription |
| `com.pearsonmedia.Seddly.proplus.yearly` | Auto-Renewable Subscription |
