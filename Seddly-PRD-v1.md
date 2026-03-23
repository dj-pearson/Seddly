# SEDDLY — Screenshot Accountability Engine
### seddly.com

## Product Requirements Document

**Version 1.0 | March 2026**
**Pearson Media LLC**
**Platform:** iOS (Swift Native) | **Backend:** Self-Hosted Supabase + Edge Functions | **Web:** Cloudflare Pages

---

## 1. Executive Summary

Seddly turns the screenshots already in your camera roll into an active accountability system. Every day, people screenshot promises from landlords, bosses, sellers, contractors, friends, and service providers. Those screenshots sit in a camera roll and die — until the promise is broken and the person frantically scrolls back trying to find proof.

Seddly solves this by automatically detecting commitments, deadlines, and dollar amounts inside screenshots using on-device OCR and AI-powered extraction. It builds a live ledger of every promise made to you, alerts you when deadlines approach or pass, and compiles dispute-ready timelines when things go wrong.

The AI is not generating content or acting as a chatbot. It is extracting structured obligations from visual data that lives exclusively on the user's device — a capability that cannot be replicated by pasting text into a prompt box.

---

## 2. The Problem

People screenshot promises constantly and for good reason — screenshots feel like proof. But they fail as an accountability tool in every way:

**Screenshots are unstructured.** A photo of a text conversation contains a promise buried in casual language. There's no metadata, no deadline tag, no reminder attached.

**Screenshots are unfindable.** The average iPhone user has 2,000+ screenshots. When you need that one text where your landlord said he'd fix the AC "by next Friday," you're scrolling through months of memes and receipts.

**Screenshots are passive.** A screenshot doesn't remind you that a deadline passed. It doesn't compile a timeline. It doesn't generate a summary you can forward to a lawyer, a property manager, or a customer service escalation team.

**The result:** people lose disputes they should win, miss deadlines they should enforce, and let commitments slide because the friction of manually tracking promises is too high.

---

## 3. Target Demographics

### 3.1 Primary — Renters & Tenants (ages 22-40)

The single largest group of people who screenshot promises and later need them as evidence. Landlord-tenant disputes are the #1 source of "I wish I had proof" moments. 44 million US households rent. Common pain points: maintenance promises, security deposit commitments, lease term clarifications, move-in/move-out condition agreements. This demographic is tech-comfortable, already screenshots heavily, and has direct financial motivation to track commitments.

### 3.2 Secondary — Freelancers, Contractors & Small Business Owners

People who operate on handshake agreements, DMs, and email promises daily. Scope changes discussed over text, payment timelines agreed in email, verbal commitments confirmed via Slack. When a client says "we'll pay on Net 30" in a text and it's now Net 60, the freelancer needs that receipt. Estimated 59 million freelancers in the US. They're accustomed to paying for tools that protect their income.

### 3.3 Tertiary — Online Buyers & Sellers

eBay, Facebook Marketplace, Poshmark, Mercari — anyone transacting peer-to-peer. Seller says "ships tomorrow," buyer screenshots it. Seller guarantees "no scratches," buyer screenshots it. When the item arrives late or damaged, that screenshot is the dispute evidence. This group already screenshots compulsively as a transaction habit.

### 3.4 Expansion — Parents, Caregivers & Family Coordinators

Co-parenting agreements confirmed over text. Childcare commitments. Family members who promised to handle something. Insurance and medical provider commitments. This segment is less tech-forward but has high emotional stakes around accountability.

---

## 4. Core Principles

### 4.1 Privacy is the Product, Not a Feature

Seddly processes screenshots on-device first. Raw images never leave the phone. Only extracted text from screenshots the user has explicitly approved is sent for AI analysis. The user can see exactly what text is being sent before it goes anywhere. If a user wants fully offline mode, the app still functions with on-device OCR and rule-based commitment detection — AI enrichment is additive, not required.

### 4.2 Zero-Input Operation

The user should never have to type, tag, categorize, or organize anything. The app watches the screenshot album, extracts commitments, sets deadlines, and files everything automatically. The user's only required action is granting photo access. Every other interaction is optional editing, not required input.

### 4.3 Accountability, Not Surveillance

Seddly tracks what OTHER people promised YOU. It is not a monitoring tool, a spy app, or a relationship tracker. The language, marketing, and UX should consistently reinforce: this is about holding others accountable to their words, not about watching or tracking other people's behavior.

### 4.4 Useful on Day One

The app must deliver value immediately — even before the AI has processed anything. On first launch, the app should offer to backfill by scanning existing screenshots (last 30/60/90 days). The user should see their first extracted commitment within 60 seconds of granting photo access.

### 4.5 Manual Control Always Available

Automation is the default. Manual override is always available. Users can manually add commitments without a screenshot. Users can edit any AI-extracted commitment. Users can delete any commitment. Users can mark commitments as fulfilled, irrelevant, or disputed. The AI is a suggestion engine — the user has final authority over their ledger.

---

## 5. Navigating the Hard Problems

### 5.1 Photo Library Permission Optics

**The Problem:**
Requesting photo library access is the single highest-friction moment in the app. Users are conditioned to distrust apps that want their photos. Apple reviewers scrutinize photo access requests heavily. A vague or broad permission request will get rejected by users and potentially by App Review.

**The Solution — Limited Photo Access (PHPicker + PHAsset for Screenshots Only):**

iOS 17+ introduced `PHAccessLevel.limited` which lets users grant access to specific photos or albums rather than the full library. However, the Screenshots smart album cannot be directly selected through the limited picker in all cases. The recommended approach:

**Onboarding Flow (Critical to Get Right):**

1. Before requesting any permission, show a clear explainer screen: "Seddly only reads your screenshots — never your personal photos, videos, or camera roll. Here's exactly what happens:" followed by a 3-step visual: Screenshot taken → Text extracted on your phone → Commitments added to your ledger.
2. Show a second screen: "What Seddly NEVER does:" with explicit statements: never uploads your screenshots, never accesses photos or videos, never reads screenshots in the background without showing you, never shares data with third parties.
3. Request `PHAuthorizationStatus.limited` access. If the user grants limited access, prompt them to select the Screenshots album specifically. If they grant full access, the app auto-filters to only the Screenshots smart album (`PHAssetCollectionSubtype.smartAlbumScreenshots`) and ignores everything else.
4. In Settings, show a "What Seddly Can See" screen that lists exactly which albums are accessible, with a count of photos in each. Full transparency.

**App Review Strategy:**

The App Store metadata, review notes, and privacy description must explicitly state: "This app accesses only the Screenshots smart album. It does not access, process, or store any non-screenshot photos or videos. All image processing occurs on-device using Apple Vision framework. No images are transmitted to external servers." Include a screen recording demo in the review notes showing the permission flow and the fact that non-screenshot photos are never displayed or processed.

**Privacy Nutrition Label:**

Photos or Videos — Used for App Functionality — Not Linked to User Identity. This is the correct declaration for screenshot-only OCR processing.

**Fallback for Permission-Shy Users:**

If a user refuses photo access entirely, the app still works through manual screenshot import. The user can share individual screenshots to Seddly via the iOS Share Sheet (no photo library permission required). This is a degraded experience but ensures the app is functional for privacy-conscious users who refuse blanket access.

### 5.2 Background Processing Limits

**The Problem:**
iOS aggressively limits background execution. You cannot run a persistent background service that monitors the camera roll in real-time. `BGAppRefreshTask` gives you roughly 30 seconds of execution at intervals iOS decides (typically 15-60 minutes, but can be hours). `BGProcessingTask` gives more time but runs overnight and is not guaranteed. There is no real-time screenshot monitoring on iOS.

**The Solution — Hybrid Processing Model:**

**Primary Processing (Foreground):**
When the user opens the app, immediately scan for new screenshots since last check. This is the most reliable processing path. Design the home screen so that the first thing the user sees is "3 new screenshots found — processing..." with a subtle progress indicator. New commitments appear in real-time as they're extracted. This creates a "pull to refresh" habit — users open the app to see what's new.

**Secondary Processing (BGAppRefreshTask):**
Register a `BGAppRefreshTask` that runs on-device OCR only (no network calls). When iOS grants background time, the app scans for new screenshots, runs Vision OCR, and runs the local classifier. If potential commitments are detected, queue them for AI extraction on next foreground session. Schedule the next background refresh immediately after completion to maintain frequency. Set `earliestBeginDate` to 15 minutes to signal to iOS that timely processing is desired.

**Tertiary Processing (Push-Triggered):**
Send a silent push notification from Supabase at configurable intervals (default: twice daily — morning and evening). When the silent push wakes the app, it gets ~30 seconds to scan and process. This is more reliable than BGAppRefreshTask alone because it's server-triggered.

**User Expectation Setting:**
The onboarding flow must explicitly tell users: "Seddly processes your screenshots when you open the app. You'll also get background updates throughout the day, but for best results, open the app once daily." Do NOT promise real-time monitoring. Frame it as "your daily accountability check-in."

**Notification Strategy:**
Send a daily local notification at a user-configured time (default: 8pm): "You have 4 new screenshots to review." This drives the foreground session where real processing happens. The notification itself is the engagement hook — the background processing is supplementary.

**Offline Queue:**
If the on-device classifier flags a screenshot as containing a commitment but the AI extraction hasn't run yet (no network, background limits), store it in a local queue with status "pending analysis." When the user next opens the app with connectivity, process the queue. Never lose a screenshot because of processing timing.

### 5.3 False Positives

**The Problem:**
Not every screenshot with a date, dollar amount, or future-tense language is a commitment. "Let's try to grab lunch next Tuesday" is not a binding promise. "The repair will probably cost around $500" is an estimate, not a guaranteed price. "I'll try to get that done this week" is hedged, not firm. If the ledger fills with weak commitments, users lose trust in the system and stop using it.

**The Solution — Three-Layer Filtering:**

**Layer 1 — On-Device Classifier (Zero AI Cost):**
A Core ML classifier trained to categorize screenshots into: conversation (text/DM/email/Slack), receipt/confirmation, terms/agreement, UI/app screenshot, meme/image, and other. Only conversation, receipt, and terms categories proceed. This eliminates 60-70% of screenshots before any AI involvement. Training data: collect and label 500-1,000 screenshots across categories. Use Create ML for initial training, iterate with user-reported misclassifications.

**Layer 2 — On-Device Rule-Based Pre-Filter (Zero AI Cost):**
After OCR text extraction, apply rule-based filters before sending to AI. Check for commitment signal words: "will," "guarantee," "promise," "by [date]," "no later than," "committed to," "scheduled for," "confirmed," "agreed." Check for hedging language that disqualifies: "might," "probably," "try to," "hopefully," "if possible," "no guarantees." Calculate a local confidence score (0-100) based on signal density. Only screenshots scoring above a configurable threshold (default: 40) proceed to AI analysis.

**Layer 3 — AI Extraction with Confidence Scoring (Paid, But Filtered):**
The AI prompt explicitly instructs Claude to assign a confidence score (1-10) to each extracted commitment and to categorize the commitment type: firm promise (explicit guarantee with deadline), soft commitment (stated intention without firm deadline), informational (price quote, estimate, or timeline that isn't a promise), and irrelevant (no actionable commitment detected).

Only commitments scoring 7+ on confidence are auto-added to the ledger. Commitments scoring 4-6 are placed in a "Review" queue where the user can confirm or dismiss. Commitments scoring 1-3 are silently discarded.

**The AI Extraction Prompt Structure:**

The prompt sent to Claude includes: the extracted text from the screenshot, instruction to identify ALL commitments, deadlines, and dollar amounts, instruction to determine who made each commitment and to whom, instruction to assign a confidence score with explicit criteria, instruction to flag hedging language that weakens a commitment, and instruction to respond in structured JSON only.

Example output the AI returns:

```json
{
  "commitments": [
    {
      "text": "I'll have the AC fixed by next Friday",
      "made_by": "Landlord (John)",
      "made_to": "User",
      "type": "firm_promise",
      "deadline": "2026-03-28",
      "dollar_amount": null,
      "confidence": 9,
      "reasoning": "Explicit commitment with specific deadline. No hedging language."
    }
  ],
  "rejected": [
    {
      "text": "I'll try to get someone out there this week",
      "type": "soft_commitment",
      "confidence": 4,
      "reasoning": "Hedged with 'try to' and vague timeline 'this week'."
    }
  ]
}
```

**User Feedback Loop:**
When a user dismisses a commitment (false positive) or manually adds one the app missed (false negative), log this feedback locally. Over time, use these signals to adjust the Layer 2 rule-based thresholds. In a future phase, aggregate anonymized feedback to fine-tune the Core ML classifier and improve the AI prompt.

**Transparency in the UX:**
Every commitment card shows a small confidence badge. Users can tap it to see: "Why Seddly flagged this" with the reasoning string from the AI. This builds trust and gives users language to understand why some items appear and others don't. It also sets the expectation that the system is probabilistic, not perfect.

### 5.4 Privacy Perception

**The Problem:**
An app that "reads all your screenshots" sounds invasive. Screenshots contain private conversations, financial information, medical details, personal photos of screens, and sensitive content. Even if the app is technically secure, the perception of an app scanning your personal screenshots is a significant trust barrier.

**The Solution — Privacy-by-Architecture:**

**On-Device First, Always:**
OCR (Vision framework), screenshot classification (Core ML), and rule-based filtering all run on-device. No screenshots or raw extracted text are sent anywhere until the AI extraction step — and even then, only filtered, relevant text is sent. Approximately 70% of all processing happens with zero network calls.

**AI Text Review Screen:**
Before ANY text is sent to the AI API for the first time, show the user exactly what will be sent. "Seddly wants to analyze this text for commitments:" followed by the extracted text. The user can approve, edit (redact sensitive parts), or skip. After the user has approved 5-10 extractions and understands the pattern, offer a toggle: "Auto-analyze future screenshots without asking." This progressive trust model respects cautious users while reducing friction for comfortable ones.

**No Image Transmission, Ever:**
The screenshot image file never leaves the device. Only extracted text (after OCR and filtering) is sent to the AI endpoint. The API request contains plain text — no image data, no metadata, no EXIF data, no file paths. Even if the network traffic were intercepted, no visual content would be exposed.

**Local-Only Mode:**
Offer a fully offline mode that uses only on-device OCR + rule-based commitment detection (Layer 1 + Layer 2 from Section 5.3). This mode has lower accuracy (no AI enrichment) but processes zero data off-device. Label this clearly in settings: "Offline Mode — All processing stays on your device. Commitment detection may be less accurate."

**Explicit Data Handling in Settings:**
A dedicated "Your Data" screen in settings showing: what data is stored locally (commitments, extracted text, screenshot references), what data is sent to the server (extracted text snippets for AI analysis, anonymized — no name, email, or device ID attached), what data is synced to Supabase (commitments, deadlines, entities — for cross-device sync on Pro+ only), and a "Delete All Data" button that nukes everything — local and server-side — with a single tap.

**No Account Required for Free Tier:**
The free tier operates entirely on-device with no account creation. No email, no phone number, no sign-up. The user installs, grants screenshot access, and the app works. Account creation is only required for Pro+ features (cross-device sync, cloud backup). This dramatically reduces the perceived data footprint for new users.

**Privacy Policy — Plain English Version:**
In addition to the legal privacy policy, provide a human-readable "How Your Data Works" page accessible from the app and the marketing website. Written in first person: "When you take a screenshot, here's exactly what happens..." with a numbered flow diagram. No legal jargon. This becomes a marketing asset — link to it in App Store description and social media.

**App Store Privacy Label:**
Data Linked to You: None (free tier), Identifiers + Usage Data (Pro+ with account). Data Not Linked to You: Diagnostics. Data Used to Track You: None. This clean privacy label is a competitive advantage.

---

## 6. Core Features

### 6.1 The Ledger (Home Screen)

The ledger is the primary interface — a chronological, filterable list of all active commitments.

Each commitment card shows: the entity/person who made the commitment, a one-line summary of what was promised, the deadline (with color-coded urgency: green for 7+ days, yellow for 1-6 days, red for overdue), the source (auto-detected or manual), and the confidence badge.

Cards are sorted by deadline proximity by default. Users can switch to: sort by entity (group all commitments from the same person/company), sort by date added, and sort by status (overdue first).

Swipe actions on each card: swipe right to mark as fulfilled (moves to history with a green checkmark), swipe left to dismiss/delete. Tap to open detail view.

**Empty State:** For new users with no commitments yet, the home screen shows: "No commitments tracked yet. Take a screenshot of a promise someone made, or add one manually." with buttons for "Scan Existing Screenshots" and "Add Manually."

### 6.2 Commitment Detail View

Tapping a commitment card opens the full detail view:

**Original Screenshot:** Displayed at the top with the relevant text highlighted/underlined. If the commitment was added manually, this section shows "Manually added — no screenshot attached" with an option to attach one.

**Extracted Details (All Editable):**
- Who: The person or entity who made the commitment. Editable text field.
- What: The commitment summary. Editable text field.
- Deadline: Date picker. If the AI detected an implicit deadline ("next Friday"), it shows the resolved date with a note: "Interpreted from 'next Friday' in original text."
- Amount: Dollar amount if applicable. Editable.
- Status: Dropdown — Pending, Fulfilled, Overdue, Disputed, Dismissed.
- Confidence: Read-only badge with "Why?" tap-through showing AI reasoning.
- Notes: Free-text field for user's own context. "Called them about this on 3/15, they said one more week."

**Related Screenshots:** If the app detects multiple screenshots from the same entity mentioning similar topics, they're grouped here. Tap to see each one's extracted text.

**Actions:**
- Edit any field (pencil icon, always accessible)
- Delete commitment entirely (trash icon with confirmation)
- Share as text summary (Share Sheet — generates a clean text block)
- Export timeline (Pro+ — generates a PDF of all commitments from this entity)
- Set custom reminder (override the automatic deadline-based alerts)

### 6.3 Manual Commitment Entry

A "+" button is always visible on the home screen. Tapping it opens a form:

- Who (required): text field with autocomplete from existing entities
- What (required): text field for the commitment description
- Deadline (optional): date picker
- Amount (optional): currency field
- Attach Screenshot (optional): opens a photo picker filtered to Screenshots album, or allows camera capture
- Notes (optional): free text

This is critical for commitments made verbally, over phone calls, or in situations where a screenshot wasn't taken. It also serves as the fallback for users who don't grant photo library access.

### 6.4 Entity Profiles

Tapping a person or company name anywhere in the app opens their entity profile. This is a chronological timeline of ALL commitments from that entity — fulfilled, pending, and overdue.

The profile shows: total commitments tracked, fulfillment rate (percentage of commitments marked fulfilled vs. overdue/disputed), average time to fulfillment, and a timeline view with each commitment as a node.

**Dispute Summary (Pro+):**
A "Generate Summary" button compiles all commitments from this entity into a formatted timeline document. Output example: "Timeline of commitments from Acme Property Management: March 1, 2026 — Promised AC repair by March 15. Source: text message screenshot. March 16 — No action taken. Deadline passed. March 18 — Promised technician visit by March 22. Source: email screenshot. March 23 — No action taken. Second deadline passed. Status: 2 of 2 commitments overdue." This is exportable as PDF or shareable as formatted text. This is the feature that makes Pro+ worth paying for.

### 6.5 Search & Filter

Full-text search across all commitments, entity names, and extracted text. Filter by: status (pending / fulfilled / overdue / disputed), entity, date range, has deadline vs. no deadline, and dollar amount range.

### 6.6 Notifications & Alerts

**Deadline Approaching:** 24 hours before a commitment deadline, send a local push notification: "Reminder: [Entity] promised [commitment summary] by tomorrow."

**Deadline Passed:** On the day after a deadline passes: "[Entity]'s commitment to [summary] is now overdue."

**Daily Digest (Optional):** A configurable daily notification summarizing: X new screenshots processed, Y new commitments detected, Z commitments due this week. This drives the daily foreground session.

**All notifications are local.** No server-side push required for core functionality. Server-side push is only used for the silent background processing trigger (see Section 5.2).

### 6.7 Backfill (First Launch)

On first launch after granting photo access, offer to scan existing screenshots. Present options: last 7 days, last 30 days, last 90 days, or all screenshots. Show a progress indicator with real-time results: "Scanning... 47 screenshots found. 12 potential commitments detected." This delivers immediate value and fills the ledger on day one.

### 6.8 Share Sheet Extension

Register a Share Sheet extension so users can share any screenshot directly to Seddly from any app (Photos, Messages, Safari, etc.) without opening Seddly first. This is the fallback processing path for users who denied photo library access and a convenience feature for everyone else.

---

## 7. Subscription & Monetization

### 7.1 Pricing Tiers

| Tier | Price | What They Get |
|------|-------|--------------|
| Free | $0 | No account required. Manual screenshot import via Share Sheet only (no auto-scan). 5 active commitments max. On-device processing only (no AI enrichment). Basic deadline alerts. 30-day history. |
| Pro | $4.99/mo or $39.99/yr | Auto-scan Screenshots album. Unlimited active commitments. AI-powered commitment extraction with confidence scoring. Full notification suite (approaching, overdue, daily digest). 1-year history. Search and filter. Entity profiles with fulfillment rates. |
| Pro+ | $9.99/mo or $79.99/yr | Everything in Pro. AI-generated dispute summaries per entity. Export to PDF. iCloud sync across devices (via Supabase). Unlimited history. Custom reminder scheduling. Priority AI processing. |

### 7.2 Why This Tier Structure Works

The free tier is genuinely useful — manual import with on-device OCR and rule-based detection still works. But it's friction-heavy enough (manual import, 5-commitment cap) that anyone who takes more than 3 screenshots of promises will feel the constraint immediately.

The upgrade trigger is natural: "You have 6 commitments detected but your free plan allows 5. Upgrade to Pro to track them all." This happens organically as the backfill surfaces commitments the user forgot about.

Pro+ is a distinct value tier, not just "more of Pro." The dispute summary feature is a concrete deliverable with obvious dollar value — anyone who's ever been in a landlord dispute, freelance payment issue, or insurance claim knows that a compiled timeline of evidence is worth far more than $9.99/month.

### 7.3 Billing Architecture

All billing via StoreKit 2 with App Store subscriptions. Subscription status is verified on-device using `Transaction.currentEntitlements`. For Pro+ (cloud sync), subscription status is also synced to Supabase via App Store Server Notifications V2 to gate server-side features. The free tier requires zero server interaction — no account, no network calls for core functionality.

---

## 8. Technical Architecture

### 8.1 iOS App (Swift Native)

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (iOS 17+ minimum deployment target) |
| Architecture | MVVM with Swift Concurrency (async/await) |
| On-Device OCR | Vision framework (VNRecognizeTextRequest) |
| Screenshot Classification | Core ML (custom-trained image classifier) |
| Local Storage | SwiftData (commitments, entities, processing queue) |
| Photo Access | PhotoKit (PHAsset, filtered to smartAlbumScreenshots) |
| Background Processing | BGAppRefreshTask + silent push triggers |
| Subscriptions | StoreKit 2 |
| Auth (Pro+ only) | Supabase Auth (Apple Sign-In) |
| Networking | URLSession for AI API calls; supabase-swift for Pro+ sync |
| Share Extension | Share Sheet extension for manual screenshot import |
| Notifications | UNUserNotificationCenter (all local for Free/Pro) |
| Minimum iOS | iOS 17.0 (required for limited photo access improvements) |

### 8.2 Backend (Self-Hosted Supabase on Contabo via Coolify)

| Component | Detail |
|-----------|--------|
| Database | PostgreSQL 15+ (Supabase bundled) |
| Auth | Supabase Auth with Apple Sign-In (Pro+ accounts only) |
| Realtime | Not required for MVP — commitments sync via periodic pull |
| Edge Functions | Deno-based: AI commitment extraction, dispute summary generation, subscription webhook handler, silent push dispatcher |
| Push Delivery | APNs HTTP/2 via Edge Functions for silent background triggers only |
| Storage | Not required for MVP — screenshots never leave device |
| CDN/DNS | Cloudflare |
| Secrets | Environment variables via Coolify (Anthropic API key, APNs credentials, App Store Connect keys) |

### 8.3 Edge Functions

**extract-commitments**

The core AI processing function. Receives: extracted text (string), screenshot metadata (timestamp, app source if detectable). Sends structured prompt to Claude Sonnet API. Returns: JSON array of commitments with confidence scores. Rate limited per user to prevent abuse. Estimated cost: $0.002-0.004 per call.

**generate-dispute-summary (Pro+ only)**

Receives: array of commitments for a given entity. Sends to Claude with instructions to generate a chronological, professional-tone timeline document suitable for dispute resolution. Returns: formatted text and structured data for PDF generation. Estimated cost: $0.01-0.03 per generation (longer context window).

**subscription-webhook**

Handles App Store Server Notifications V2. Updates user subscription status in Supabase. Gates Pro+ features (sync, dispute summaries).

**send-silent-push**

Triggered by pg_cron twice daily (configurable). Sends silent APNs push to all Pro/Pro+ users to wake the app for background screenshot processing. Includes no user-visible content — purely a background trigger.

### 8.4 Database Schema

**users** (Pro+ only — free/Pro users have no server-side account)
`id` (uuid, PK), `apple_user_id`, `email`, `subscription_tier`, `subscription_status`, `subscription_expires_at`, `created_at`, `updated_at`

**commitments** (Pro+ sync only)
`id` (uuid, PK), `user_id` (FK users), `entity_name`, `summary`, `full_text`, `deadline` (timestamptz, nullable), `dollar_amount` (decimal, nullable), `status` (pending|fulfilled|overdue|disputed|dismissed), `confidence` (int), `ai_reasoning` (text), `source` (auto|manual|share_sheet), `screenshot_date` (timestamptz), `notes` (text, nullable), `created_at`, `updated_at`

**entities** (Pro+ sync only)
`id` (uuid, PK), `user_id` (FK users), `name`, `total_commitments` (int), `fulfilled_count` (int), `overdue_count` (int), `created_at`, `updated_at`

**processing_log** (analytics, all tiers via anonymous device ID)
`id` (uuid, PK), `device_id` (anonymized hash), `screenshots_processed` (int), `commitments_extracted` (int), `false_positive_dismissals` (int), `manual_additions` (int), `processed_at` (timestamptz)

### 8.5 RLS Policies

- Users can only read/write their own commitments and entities
- Processing_log is write-only from Edge Functions, no user reads
- Subscription data writable only by subscription-webhook Edge Function (service role)
- All queries filtered by authenticated user_id

### 8.6 On-Device Data Model (SwiftData)

The local SwiftData schema mirrors the Supabase schema but is the primary data store for ALL tiers. For Free and Pro users, SwiftData is the only data store — nothing exists server-side. For Pro+ users, SwiftData is the primary store with periodic sync to Supabase for cross-device backup.

**LocalCommitment:** id, entityName, summary, fullText, deadline, dollarAmount, status, confidence, aiReasoning, source, screenshotAssetID (PHAsset local identifier), screenshotDate, notes, needsAIProcessing (bool), syncStatus (local|synced|pendingSync), createdAt, updatedAt

**LocalEntity:** id, name, commitments (relationship to LocalCommitment), createdAt, updatedAt

**ProcessingQueue:** id, screenshotAssetID, extractedText, classifierResult, ruleBasedScore, status (pending|processing|completed|skipped), createdAt

---

## 9. Marketing Website (Cloudflare Pages)

### 9.1 Architecture

Static site built with Astro or simple HTML/CSS/JS. Hosted on Cloudflare Pages with automatic deployments from a GitHub repository. Domain: seddly.com, managed via Cloudflare DNS.

### 9.2 Pages

**Landing Page (/)**
Hero section: "Every promise. Every deadline. Every receipt." with app mockup showing the ledger UI. Three-step explanation: Screenshot → AI extracts the promise → You get reminded when it's due. Social proof section (post-launch): testimonials and use case stories. Pricing section with tier comparison. FAQ section addressing privacy concerns prominently. App Store download button (primary CTA).

**How It Works (/how-it-works)**
Detailed visual walkthrough of the processing pipeline. Animated diagrams showing: screenshot taken → on-device OCR → classification → AI extraction → commitment appears in ledger. Emphasis on on-device processing and privacy architecture.

**Privacy (/privacy)**
Plain-English explanation of data handling. Visual flow diagram: "What stays on your phone" vs. "What is processed in the cloud." Answers to common concerns: "Can Seddly see my personal photos?" (No.) "Are my screenshots uploaded?" (No, never.) "What happens if I delete the app?" (All data deleted.) Link to full legal privacy policy.

**Legal Privacy Policy (/privacy/legal)**
Standard legal privacy policy covering: data collection, data processing, third-party services (Anthropic API for AI processing), data retention, user rights (access, deletion, export), children's privacy (13+ age gate), contact information.

**Support (/support)**
FAQ, troubleshooting guides, contact form. Common issues: "Why didn't Seddly detect my screenshot?" "How do I grant photo access after denying it?" "How do I export my commitment history?"

**Blog (/blog)**
SEO-focused content targeting: "how to document landlord promises," "keeping track of freelance client commitments," "screenshot as legal evidence," "tenant rights documentation." Content strategy focused on the problem Seddly solves, not the product itself. Drives organic traffic from people searching for accountability solutions.

### 9.3 SEO & Metadata

JSON-LD schema markup for SoftwareApplication. Open Graph and Twitter Card meta tags for social sharing. IndexNow integration for new blog posts via Cloudflare Worker. Target keywords: screenshot tracker, promise tracker, commitment tracker, landlord accountability, freelance payment tracking, dispute evidence app.

---

## 10. User Experience Flows

### 10.1 First Launch Flow

1. App opens to a welcome screen: "Seddly — Hold everyone to their word."
2. Three-screen onboarding carousel explaining the concept (visual, not text-heavy).
3. Photo access request with pre-permission explainer (see Section 5.1).
4. If access granted: "Want to scan your existing screenshots for commitments?" with time range options.
5. Backfill runs with progress indicator. Commitments populate the ledger in real-time.
6. If no commitments found: "No commitments detected yet. Take a screenshot of a promise, or add one manually."
7. If commitments found: Land on the Ledger showing results. Subtle banner: "Review your commitments — tap any to edit or dismiss."

### 10.2 Daily Usage Flow

1. User receives daily digest notification: "3 new screenshots processed. 1 new commitment detected. 2 deadlines approaching this week."
2. Opens app to Ledger. New commitment highlighted with a "New" badge.
3. User reviews: taps to see detail, edits entity name for clarity, confirms deadline is correct.
4. Sees an overdue commitment in red at the top. Taps into entity profile to see full history.
5. On Pro+: taps "Generate Summary" to create a dispute timeline. Shares via email to landlord/client.

### 10.3 Manual Add Flow

1. User taps "+" on Ledger.
2. Enters: "John from Apex Plumbing said he'd come back to fix the leak by end of month. $0 charge since it's under warranty."
3. App stores as manual commitment with no screenshot attached.
4. User can optionally attach a screenshot later if they take one.

### 10.4 Share Sheet Flow

1. User is in iMessage, sees a text from a contractor making a promise.
2. Takes a screenshot.
3. Opens Share Sheet, taps Seddly.
4. Seddly extension processes the screenshot immediately (on-device OCR + classification).
5. If commitment detected: "Commitment found: [summary]. Add to ledger?" with Confirm/Edit/Skip options.
6. User confirms. Commitment appears in the ledger next time they open the app.

---

## 11. MVP Scope & Phasing

### 11.1 Phase 1 — MVP (Weeks 1-4)

- Single-screen Ledger with commitment cards (status, entity, deadline, summary)
- On-device OCR via Vision framework
- Core ML screenshot classifier (conversation vs. receipt vs. irrelevant)
- Rule-based pre-filter for commitment signal language
- AI commitment extraction via Supabase Edge Function calling Claude Sonnet
- Commitment detail view with full edit capability (who, what, deadline, amount, status, notes)
- Manual commitment entry (+ button)
- Share Sheet extension for manual screenshot import
- Swipe to fulfill / swipe to dismiss
- Entity grouping (tap entity name to see all their commitments)
- Local notifications for approaching and overdue deadlines
- Backfill scan on first launch
- Free tier (manual import, 5 commitments, on-device only) + Pro tier ($4.99/mo)
- StoreKit 2 subscription management
- Settings: photo access status, notification preferences, privacy info
- Marketing website on Cloudflare Pages (landing, how-it-works, privacy)
- All data stored locally via SwiftData — no server-side account required

### 11.2 Phase 2 — Growth (Weeks 5-10)

- Pro+ tier ($9.99/mo) with Supabase account and cloud sync
- Apple Sign-In for Pro+ accounts
- AI-generated dispute summaries per entity (PDF export)
- Entity profiles with fulfillment rate and timeline view
- Search and full-text filter across all commitments
- BGAppRefreshTask + silent push for background processing
- Daily digest notification
- Confidence badge with "Why?" reasoning tap-through
- AI text review screen (approve/edit before first AI sends)
- Auto-analyze toggle after trust is established
- App Store Server Notifications V2 for subscription management
- Blog content for SEO (5-10 launch articles)

### 11.3 Phase 3 — Expansion (Weeks 11-18)

- Progressive trust model: AI auto-analyze after user approves 5+ extractions
- Smart entity merging (AI recognizes "John," "John from Acme," and "Acme Property Management" as the same entity)
- Commitment categories (housing, freelance, purchases, personal, medical, insurance)
- Widgets: home screen widget showing count of overdue commitments
- Siri Shortcuts: "Hey Siri, add a commitment" for voice-based manual entry
- Export all data as CSV/JSON
- Local-only mode toggle for fully offline operation
- Improved classifier from user feedback data
- Referral program: share Seddly with a friend, both get 1 month Pro free
- Android companion app (Phase 3b, if iOS proves the model)

---

## 12. Success Metrics

| Metric | MVP Target (3 months) | Growth Target (6 months) |
|--------|----------------------|--------------------------|
| Downloads | 5,000 | 25,000 |
| Photo Access Grant Rate | > 60% | > 70% (with onboarding optimization) |
| Commitments Extracted per User (monthly) | > 8 | > 15 |
| False Positive Rate (user dismissals) | < 25% | < 15% |
| Free-to-Pro Conversion | > 6% | > 10% |
| Pro-to-Pro+ Conversion | > 15% of Pro users | > 20% |
| Monthly Churn (Pro) | < 10% | < 7% |
| D7 Retention | > 40% | > 50% |
| D30 Retention | > 20% | > 30% |
| MRR | $1,500 | $8,000 |

---

## 13. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| App Store rejects photo access justification | Launch blocked | Submit with detailed review notes, screen recordings, and explicit privacy documentation. Offer Share Sheet fallback so app functions without photo access. Prepare appeal with precedent apps that use screenshot access. |
| Users refuse photo library permission | Core loop breaks for those users | Share Sheet extension provides full functionality without photo access. Prominent manual add feature. Onboarding positions permission as optional enhancement, not requirement. |
| AI extraction accuracy is too low at launch | Users lose trust, high churn | Three-layer filter system means only high-confidence items auto-add. "Review" queue for medium confidence. User can correct and dismiss freely. Ship with conservative thresholds, loosen as accuracy proves out. |
| iOS background processing is too unreliable | Screenshots not processed timely | Design for foreground-first processing. Daily notification drives foreground session. Background processing is supplementary, not primary. Set user expectations correctly in onboarding. |
| Privacy backlash / negative reviews | Reputation damage, downloads drop | Privacy-by-architecture (Section 5.4). No account required for free tier. AI text review screen. Prominent plain-English privacy page. Proactive transparency in marketing. |
| Anthropic API downtime or rate limiting | AI extraction fails for all users | On-device rule-based extraction provides degraded but functional fallback. Queue failed extractions for retry. Show "pending analysis" status rather than failing silently. |
| Low organic discovery for a new category | Slow growth, can't reach MRR targets | SEO blog content targeting existing search intent ("how to track landlord promises"). TikTok/Reels content showing the "aha moment" of Seddly finding forgotten commitments in a camera roll. Product Hunt launch. Reddit engagement in r/landlord, r/freelance, r/legaladvice communities. |
| Apple restricts screenshot album access in future iOS | Core feature broken by OS update | Share Sheet extension works regardless of photo library APIs. Manual entry always available. Monitor Apple developer betas for PhotoKit changes. Diversify input methods early (clipboard monitoring for pasted text, Mail/Messages extensions). |

---

## 14. Competitive Landscape

There is no direct competitor doing screenshot-based commitment extraction. Adjacent products include:

**Generic Note/Reminder Apps (Apple Notes, Google Keep, Todoist):** Require manual entry for every commitment. No screenshot awareness. No AI extraction. No entity tracking. Seddly's advantage: zero-input automation.

**Contract Management SaaS (PandaDoc, DocuSign, Ironclad):** Enterprise-focused, document-centric, $25-500+/month. Designed for formal contracts, not text message promises. Seddly's advantage: consumer-friendly, handles informal commitments, fraction of the price.

**AI Screenshot Apps (Google Lens, Apple Live Text):** Extract text from images but do nothing with it — no commitment detection, no deadline tracking, no accountability. Seddly's advantage: the intelligence layer that turns extracted text into structured, actionable obligations.

**Reminder/Deadline Apps (Due, Reminders, TickTick):** Require manual setup per reminder. No awareness of why a deadline exists or who set it. No evidence trail. Seddly's advantage: the commitment carries its own context, evidence, and entity association.

Seddly creates a new category: **screenshot intelligence.** The closest analogy is how Mint turned bank statements (passive data) into financial insights (active intelligence). Seddly does the same for screenshots.

---

## 15. Appendix

### 15.1 App Store Metadata (Draft)

**App Name:** Seddly — Promise Tracker
**Subtitle:** Hold everyone to their word.
**Category:** Productivity (Primary), Utilities (Secondary)
**Keywords:** promise tracker, screenshot tracker, commitment tracker, deadline reminder, landlord accountability, dispute evidence, receipt tracker, agreement tracker, proof, accountability
**App Store Description (first paragraph):** "People make promises over text, email, and DMs every day. Seddly makes sure they keep them. Just take a screenshot — Seddly automatically detects commitments, deadlines, and dollar amounts, and reminds you when they're due. No typing. No organizing. Just accountability."

### 15.2 iOS Entitlements Required

- Photo Library (Limited or Full — filtered to Screenshots only)
- Background App Refresh
- Push Notifications (silent push for background processing trigger)
- Sign in with Apple (Pro+ tier only)
- App Groups (for Share Sheet extension data sharing)

### 15.3 Third-Party Dependencies

- Anthropic Claude API (via Supabase Edge Functions) — AI commitment extraction
- Supabase Swift SDK (Pro+ tier cloud sync)
- No analytics SDK in MVP — use App Store Connect Analytics + custom processing_log table
- No crash reporting SDK in MVP — use Apple's built-in crash reporting via Xcode Organizer

### 15.4 Estimated AI Cost Model

| Scenario | Screenshots/Day | AI Calls/Day | Monthly Cost/User |
|----------|----------------|-------------|------------------|
| Light user | 2-3 | 1 | $0.06 |
| Average user | 5-7 | 3 | $0.18 |
| Heavy user | 10-15 | 6 | $0.36 |
| Blended average | — | — | $0.20 |

At $4.99/month (Pro) after Apple's 30% cut: $3.49 revenue. Minus $0.20 AI costs, $0.05 infrastructure. **Net margin per user: $3.24/month (93%).**

At $9.99/month (Pro+) after Apple's 30% cut: $6.99 revenue. Minus $0.35 AI costs (includes dispute summaries), $0.10 infrastructure (Supabase sync). **Net margin per user: $6.54/month (94%).**
