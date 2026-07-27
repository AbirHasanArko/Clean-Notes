# AppsPro / BDApps Integration — Setup & Operations Guide

This document explains how the Clean Notes Flutter app talks to the
**AppsPro / BDApps** subscription platform: account creation on the
dashboard, the secret-key flow, the OTP/verify/unsubscribe API calls,
and how the secret is (and isn't) stored in the client.

It is meant for the Module-6 assignment, but it doubles as a handoff
guide for anyone picking the project up later.

---

## 1. AppsPro dashboard setup (one-time)

You only need to do these steps once per project.

### 1.1 Create an app on the dashboard

1. Sign in to <https://appspro.dev>.
2. From the dashboard, click **Create App** (or the equivalent "New
   application" CTA).
3. Fill in:
   - **App name** — anything; `Clean Notes` is fine.
   - **Platform** — Android / iOS / Web, whatever you ship.
   - **Redirect / callback URL** — leave blank for the SDK flow
     (we don't use OAuth).
4. Once created, AppsPro shows a **dashboard** for the app. From here
   you copy the three credentials we actually use (see §1.2).

### 1.2 The three credentials

| Name                  | Where it appears                       | Used where |
|-----------------------|-----------------------------------------|------------|
| `secretKey` (`sk_…`)  | App → **Settings → Secret key**         | All SDK calls. Treated like a password — see §3. |
| `publishableKey` (`pk_…`) | App → **Settings → Publishable key** | Optional, only for the web SDK / public `app-info`. |
| `urlSlug`             | App → **Settings → URL slug**           | Builds the hosted-checkout URL (`https://appspro.dev/s/<slug>`). |

> **Don't commit real production keys.** The keys in
> `lib/config/appspro_config.dart` are demo credentials for the
> assignment. For a real app, swap them out — but treat the secret
> key like a password (see §3).

### 1.3 Configure the short-code / pricing (optional)

If you want the OTP and subscription to charge the user, set the
short code and pricing in the dashboard:

- **Short code** — the number users SMS to subscribe (e.g. `2626`).
- **Price** — daily / weekly / monthly.
- **Keyword** — the first word of the SMS that triggers a charge.

For the assignment we **don't bill**, but we still let the OTP flow
create a "subscriber record" in BDApps. This is enough to exercise
the API end-to-end without charging anyone.

---

## 2. What the client does, end to end

```
┌────────────────┐  POST /sdk/otp/request      ┌──────────────────┐
│  LoginScreen   │ ──────────────────────────► │                  │
│ (enter phone)  │ ◄──────── reference_no ──── │                  │
└────────────────┘                              │                  │
                                                │  AppsPro / BDApps│
┌────────────────┐  POST /sdk/otp/verify       │                  │
│  LoginScreen   │ ──────────────────────────► │                  │
│ (enter OTP)    │ ◄──── subscriber_id ─────── │                  │
└────────────────┘                              │                  │
       │                                         │                  │
       │ persists Subscriber { id, phone }      │                  │
       ▼                                         │                  │
┌────────────────┐                              │                  │
│ SharedPrefs    │                              │                  │
│ clean_notes…   │                              │                  │
└────────────────┘                              │                  │
                                                │                  │
┌────────────────┐  POST /sdk/unsubscribe       │                  │
│ NotesList →    │ ──────────────────────────► │                  │
│ AppBar logout  │ ◄──── status_code ───────── │                  │
└────────────────┘                              └──────────────────┘
```

The two **read-only** calls are also used:

- `GET /sdk/app-info?publishable_key=…` — public, used (optionally)
  by the login screen to display the app's name / logo.
- `GET /sdk/verify/{subscriber_id}` — re-validates a stored
  subscriber on cold start before letting them into the notes list.

---

## 3. The secret key — how (not) to handle it

### 3.1 What it is

The `sk_…` value in `lib/config/appspro_config.dart` is the app's
**server-side API key**. It is the same key for every install of the
app and grants full access to **read, create, modify, and cancel**
subscriptions on behalf of your app.

### 3.2 Why embedding it in the Flutter app is a code smell

Anything compiled into the APK is **public**:

- A motivated user can `unzip` the APK, extract `libapp.so`, and
  recover the Dart source from snapshot data.
- A 30-second `strings` over the binary reveals every literal,
  including `sk_…`.

For a real production app this is unacceptable — anyone with the
key can churn your subscriber base, reset billing, or DOS the SDK.
The dashboard credentials also tie back to your billing account.

### 3.3 What we do in this project (demo / assignment)

We embed the secret directly so the assignment runs without extra
infrastructure:

```dart
// lib/config/appspro_config.dart
static const String secretKey =
    'sk_dec251b804d78ea8d48267e28c5e1d779924827d33125cdf';
```

There is a `SECURITY` comment block at the top of that file that
explains the trade-off in plain English. Read it.

### 3.4 What to do for a real build

Add a small backend (Cloud Function, Express endpoint, whatever) that:

1. Holds the `sk_…` in an environment variable / secret manager.
2. Exposes only the **minimum** surface area to the mobile client —
   for example:
   - `POST /subscription/request-otp` → forwards to
     `/sdk/otp/request`.
   - `POST /subscription/verify-otp` → forwards to `/sdk/otp/verify`.
   - `POST /subscription/cancel` → forwards to `/sdk/unsubscribe`.
3. Authenticates the caller (Firebase ID token from the client) so
   a leaked proxy URL can't be abused.

The Flutter code changes minimally — replace the URLs in
`appspro_config.dart` with your proxy URLs, drop the `secretKey`
constant entirely.

---

## 4. Endpoints we call

All endpoints live under `baseUrl = https://api.appspro.dev/api/v1`
and require `Authorization: Bearer <secretKey>` (except `app-info`
and OTP request which only need the phone number).

### 4.1 Request an OTP — `POST /sdk/otp/request`

**Body**:
```json
{ "phone": "01XXXXXXXXX" }
```
(`8801XXXXXXXXX` and `+8801XXXXXXXXX` are also accepted.)

**Success (200)**:
```json
{ "reference_no": "abc123", "status_code": "0000" }
```

**Failure**:
```json
{ "status_detail": "...", "status_code": "E...." }
```

The client stores `reference_no` and prompts the user for the OTP.

### 4.2 Verify an OTP — `POST /sdk/otp/verify`

**Body**:
```json
{ "reference_no": "abc123", "otp": "123456" }
```

**Success (200)**:
```json
{
  "subscription_status": "REGISTERED",
  "subscriber_id": "tel:8801712345678",
  "status_code": "0000"
}
```

The client stores `subscriber_id` as the BDApps identifier of the
user. This is what we re-validate on cold start and what we pass
back to unsubscribe.

### 4.3 Re-validate on cold start — `GET /sdk/verify/{subscriber_id}`

Returns `{ "valid": true|false, ... }`. The client calls this in
`SubscriptionGate._bootstrap` before showing the notes screen. If
the network is down we fall back to the cached "valid" assumption
so the user isn't kicked out just because of bad signal.

### 4.4 Cancel a subscription — `POST /sdk/unsubscribe`

**Body**:
```json
{
  "phone": "8801XXXXXXXXX",
  "subscriber_id": "tel:8801XXXXXXXXX"
}
```

> The `phone` field is **required** and must be in international
> form **without the leading `+`** (`8801XXXXXXXXX`). Sending the
> local form (`01XXXXXXXXX`) returns the ambiguous error
> `200 / status_code E1951 / "Format of the address is invalid Or
> User Already UnRegistered"`.

**Success (200)**:
```json
{ "status_code": "0000" }
```

**Failure**:
```json
{
  "status_detail": "Format of the address is invalid Or User Already UnRegistered",
  "status_code": "E1951"
}
```

AppsPro intentionally hides whether the phone was malformed or the
user simply wasn't registered, so `E1951` means **either** "this
account doesn't exist on BDApps" **or** "the format is wrong".
See §6 for how we handle that.

### 4.5 (Optional) App metadata — `GET /sdk/app-info?publishable_key=…`

Public, no auth. Returns the app name, icon, theme color etc. so
the login screen can mirror the dashboard branding.

---

## 5. Where each piece lives in the code

```
lib/
├── config/
│   └── appspro_config.dart          ← baseUrl, secretKey, URL helpers
├── models/
│   └── subscriber.dart              ← { subscriberId, phone, verifiedAt }
├── services/
│   └── subscription_service.dart    ← requestOtp, verifyOtp,
│                                       verifySubscriber, unsubscribe
└── screens/
    ├── login_screen.dart            ← Step 1 (phone) + Step 2 (OTP)
    ├── subscription_success_screen.dart  ← "You're subscribed!" splash
    ├── subscription_gate.dart       ← Cold-start routing logic
    └── notes_list_screen.dart       ← Has the AppBar logout button
```

`SubscriptionService` is the **only** file that talks to AppsPro.
Nothing else in the app constructs URLs or reads the secret key.

---

## 6. Unsubscribe — why it can fail and how we cope

The symptom you'll most often see is the snackbar:

```
Could not cancel BDApps subscription: SubscriptionException(E1951):
Format of the address is invalid Or User Already UnRegistered.
```

Three real reasons:

1. **Format wrong.** You sent `+880…` or `01…` instead of
   `880…` (no `+`). AppsPro returns `E1951` either way because it
   doesn't tell you which is wrong. The client normalises to
   `880XXXXXXXXXX` in `SubscriptionService._toInternationalPhoneNoPlus`.

2. **The user was never actually registered on BDApps.** The
   dashboard-side record was never provisioned as a billable
   subscription (e.g. a free tier that doesn't bill), so the SDK
   has nothing to cancel. `E1951` is the same response.

3. **The stored `subscriber_id` is empty.** `verifyOtp` accepts
   the response as success if `subscription_status` is
   `REGISTERED` even when `subscriber_id` is missing. We then
   have a local "you're subscribed" record but no BDApps id.
   Cancel will always fail.

### 6.1 What the client does

The unsubscribe code path is in two places.

**`SubscriptionService.unsubscribe(subscriber)`** (the API call):

- Normalises phone to `880XXXXXXXXXX`.
- POSTs `{ phone, subscriber_id }` to `/sdk/unsubscribe`.
- **Throws** `SubscriptionException` if `status_code` is anything
  other than `0000`. We used to swallow this silently — that was a
  bug, since the user appeared "logged out" while still being
  registered on BDApps.

**`NotesListScreen._handleLogout`** (the UI):

- Shows the "Unsubscribe & log out?" confirmation dialog.
- Calls `SubscriptionService.unsubscribe(stored)`.
- On failure, shows a snackbar with the actual AppsPro error, then
  **still completes the local logout** so the user isn't stranded.
- Clears local prefs (`SharedPreferences.remove(_prefsKey)`) and
  asks the gate to re-bootstrap, which sends the user back to the
  login screen.

The local-clearing-on-failure trade-off is deliberate:

- If we waited for BDApps to confirm cancellation, a flaky network
  would leave the user stuck in the app.
- If we always cleared without surfacing the error, the user
  wouldn't know that BDApps still had their subscription on file
  (and might keep billing them).

We pick "let them out, tell them clearly what failed".

---

## 7. Local state — what gets persisted and where

Only one value is persisted across launches, in `SharedPreferences`
under the key `clean_notes.subscriber.v1`:

```json
{
  "subscriberId": "tel:8801712345678",
  "phone":        "01712345678",
  "verifiedAt":   "2026-07-27T11:30:00.000Z"
}
```

Read it on the emulator with:

```powershell
adb -s emulator-5554 shell run-as com.ostad.notes.notes_management_app cat shared_prefs/FlutterSharedPreferences.xml
```

A successful OTP verify saves it; a logout (or a fresh install)
clears it.

The **anonymous Firebase UID** is separate — managed by
`AuthService` and persisted by `firebase_auth`'s own storage. That
UID is what identifies the user in **Firestore** (for notes); the
`subscriberId` here identifies them in **BDApps** (for
subscription).

---

## 8. Manual end-to-end test checklist

After every change to the integration, run this checklist on a real
emulator with the live `secretKey` in `appspro_config.dart`:

1. **Cold start, no prior state** → login screen renders.
2. **Enter phone, request OTP** → snackbar *"OTP sent to …"*.
3. **Enter OTP, verify** → success screen with masked phone.
4. **Tap "Continue to notes"** → notes list renders, can add /
   edit / delete a note.
5. **Kill and reopen app** → notes list renders directly (gate
   re-validated subscriber).
6. **Add a note from another account** → original account does
   **not** see the new note (per-owner Firestore rules).
7. **Tap logout (top-right of notes list)** → "Unsubscribe & log
   out?" dialog.
8. **Confirm** → snackbar with success (`0000`) or, if BDApps
   rejects, the actual error message. Either way, returns to the
   login screen.
9. **Kill and reopen app** → login screen (no cached subscriber).

If any step fails, paste the `flutter run` log output.

---

## 9. Where to look in the codebase

| Symptom                                       | File / function to inspect |
|-----------------------------------------------|----------------------------|
| Wrong API key, 401                            | `lib/config/appspro_config.dart` |
| OTP never sent                                | `SubscriptionService.requestOtp` |
| "OTP verification failed"                     | `SubscriptionService.verifyOtp` |
| User sees login every cold start              | `SubscriptionGate._bootstrap`, `SubscriptionService.verifySubscriber` |
| Unsubscribe returns `E1951`                   | `SubscriptionService.unsubscribe`, `SubscriptionService._toInternationalPhoneNoPlus` |
| Continue button does nothing                  | `SubscriptionGate._onVerified`, `SubscriptionSuccessScreen.onContinue` |
| Notes leaking across users                    | `firestore.rules`, `NotesService._uid`, `Note.ownerId` |