# Seddly — Google Play Data Safety Disclosure

Source copy for the Play Console **Data safety** form. Mirrors
`Seddly/Resources/PrivacyInfo.xcprivacy` verbatim — any change here should be
reflected there and vice versa.

Last reviewed: 2026-04-21

---

## 1. Data collection & sharing overview

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (Pro+ sync users only). Free tier: No. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — TLS 1.3 with certificate pinning to the Seddly Supabase project. |
| Do you provide a way for users to request that their data be deleted? | **Yes** — Settings → Delete Account (hard-deletes the Supabase row and clears the local Room database). |

---

## 2. Data types

### Collected

| Category | Data type | Collected? | Shared? | Optional? | Purposes |
|---|---|---|---|---|---|
| Personal info | Email address | Yes (Pro+ only) | No | Yes — only collected when user signs in for cloud sync | Account management |
| App info & performance | Crash logs | Yes | No | No — automatic via system crash reporter | App functionality, Analytics |
| App info & performance | Diagnostics | Yes | No | No | App functionality |
| App activity | Other user-generated content (commitment summaries) | Yes (Pro+ sync only) | No | Yes — opt-in via Pro+ subscription | App functionality |
| Messages | — | No | No | — | — |
| Photos and videos | Photos | **No — processed on device only, never uploaded** | No | — | — |
| Files and docs | — | No | No | — | — |
| Contacts | — | No | No | — | — |
| Location | — | No | No | — | — |
| Web browsing | — | No | No | — | — |
| Financial info | — | No | No | — | — |

### Not collected

Photos, screenshots, raw OCR text, contacts, location, financial details, web
browsing history. On-device ML Kit OCR runs locally and the raw bitmap never
leaves the device.

---

## 3. Security practices

- **Data in transit:** TLS 1.3 mandatory; `network_security_config.xml` disables
  cleartext and pins the Supabase SPKI.
- **Data at rest:** Room database on internal storage. Auth tokens protected by
  `EncryptedSharedPreferences` (AES256-GCM values, AES256-SIV keys) with a
  MasterKey backed by the Android Keystore hardware module.
- **Backup:** `data_extraction_rules.xml` excludes the Room DB and encrypted
  shared prefs from cloud backup and device-to-device transfer.
- **Deletion:** Settings → Delete Account cascades: Supabase RPC to hard-delete
  the user row, then `SecureStorageService.clearAll()` + full Room wipe.

## 4. Third-party data flow

| Recipient | Data sent | Purpose | Conditions |
|---|---|---|---|
| User's own Supabase project (Seddly-hosted) | Email, commitment summaries, commitment metadata | Cloud sync across the user's own devices | Only if Pro+ subscription active and user signed in |
| Anthropic (via Supabase Edge Function) | Filtered OCR text snippet (never the raw screenshot) | Claude-powered commitment extraction | Only if Pro / Pro+ subscription active; free tier uses on-device rule-based extraction |
| Google Play Billing | Subscription purchase token | Subscription entitlement verification | Only when the user initiates a purchase |

No SDK shares data with advertising networks. Seddly integrates no advertising
or analytics SDKs.

---

## 5. Submission checklist

Before submitting the Data Safety form:

- [ ] Verify the Privacy Policy URL (`https://seddly.com/privacy`) resolves and
      covers every item above.
- [ ] Confirm `PrivacyInfo.xcprivacy` in the iOS project matches this doc.
- [ ] Regenerate screenshots of the sign-in / delete-account flow for the
      reviewer.
- [ ] If a new SDK is added (Firebase, Mixpanel, etc.), reopen this doc AND
      update the iOS privacy manifest.
