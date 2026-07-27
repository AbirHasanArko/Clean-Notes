# Clean Notes - Release Notes

**App:** Clean Notes  
**Package:** `com.ostad.notes.notes_management_app`  
**Version:** `1.0.0+1`  
**Release Date:** 27 July 2026

---

## Platform

* **Android** (phones and tablets)
* **Minimum supported OS:** Android 5.0 (Lollipop, API 21)
* **Target OS:** Android 14 (API 34)
* **Architecture:** `arm64-v8a`, `armeabi-v7a`, `x86_64`
* *iOS, web, macOS, Windows, Linux:* Not built or supported in this release.

---

## Tech Stack

* **Framework:** Flutter 3.x (Dart 3.12+)
* **Language:** Dart
* **UI:** Material 3
* **Backend:** Firebase
  * `firebase_core` (4.x)
  * `cloud_firestore` (6.x)
  * `firebase_auth` (6.5.4, anonymous sign-in)
* **Billing:** AppsPro / BDApps REST SDK
  * Base URL: `https://api.appspro.dev/api/v1`
* **Networking:** `package:http` (direct HTTPS)
* **Local state:** `SharedPreferences` (subscriber record only)
* **Build:** Gradle (Kotlin DSL), AGP, JDK 17
* **Signing:** Release keystore (not included in source)

---

## What is New in This Build

* **Per-user data isolation:** Each subscriber's notes are now stored under their own user space in Cloud Firestore. Two accounts on the same device cannot see each other's notes.
* **Subscription gate:** Powered by AppsPro / BDApps. The notes list only opens after a successful subscription flow on the local carrier billing platform.

---

## Fixes in This Build

* **Success Screen Navigation:** "Continue to notes" button on the success screen now correctly returns to the main notes list instead of leaving the user on an empty screen.
* **Authentication Fallback:** App no longer blanks out on devices that do not support Firebase Anonymous Authentication. The bootstrap is wrapped in a safe fallback that still allows the app to start.
* **Unsubscribe Error Handling:** Unsubscribe now reports the real AppsPro response instead of silently swallowing errors. Local logout always completes, even if the unsubscribe call to BDApps fails.
* **Android Builds:** Kotlin incremental build flag added so subsequent Android release builds succeed consistently.

---

## Known Limitations

* **Ambiguous Error Codes:** The AppsPro unsubscribe API returns an ambiguous error code (`E1951`) for both "phone format wrong" and "user already unregistered". See [APPSPRO_INTEGRATION.md](file:///d:/Documents/Clean-Notes/APPSPRO_INTEGRATION.md) in the project repository for a full explanation.
* **Embedded Key:** The subscription secret key is embedded in the client app for demo purposes. This is not suitable for a production release; a backend proxy should be used instead. See section 3 of [APPSPRO_INTEGRATION.md](file:///d:/Documents/Clean-Notes/APPSPRO_INTEGRATION.md).

---

## Technical Notes

* Flutter 3.x, Dart 3.12+
* Firebase: `firebase_core`, `cloud_firestore`, `firebase_auth` (anonymous)
* Subscription platform: AppsPro / BDApps REST SDK
* Local storage: `SharedPreferences` (subscriber record only)

---

# Clean Notes - App Description

Clean Notes is a simple, fast notes app for Android. You write a note, save it, and it is waiting for you the next time you open the app. Notes are synced to the cloud so they survive a reinstall and follow you between phones once you sign in.

## Subscription and Pricing

Clean Notes is provided as a paid service through the Bangladeshi carrier billing platform (AppsPro / BDApps).

* **Subscription charge:** BDT 2/= per day (two Bangladeshi Taka per day).

### How the charge works:
* The BDT 2/= daily fee is added to your mobile phone bill by your operator. There is no separate card payment or in-app purchase.
* The charge starts on the day you subscribe and continues every day until you unsubscribe.
* You will see the daily charge on your operator's monthly bill as part of your value-added services.

## How to Subscribe

1. Install and open **Clean Notes**.
2. Enter your Bangladeshi mobile number on the welcome screen.
3. Wait for the one-time password (OTP) to arrive by SMS.
4. Enter the OTP to confirm you own the number.
5. You now have full access to the app. The BDT 2/= per day charge has started.

## How to Unsubscribe

1. Open **Clean Notes**.
2. Tap the **Logout / Unsubscribe** button at the bottom of the notes list.
3. Confirm when asked.
4. The app will call BDApps to cancel your subscription and then clear your notes from this device.

> [!NOTE]
> * After unsubscribing, you can keep using the app until you close it, but the next time you open it you will be asked to subscribe again.
> * It may take up to 24 hours for the unsubscribe to fully reflect on your operator bill. If the BDT 2/= daily charge still appears after 24 hours, contact your mobile operator with your phone number.

## Data and Privacy

* Your notes are stored in Cloud Firestore under your subscriber identity. No other user can see them, even on the same device.
* Logging out and unsubscribing removes your notes from this device. The cloud copy remains associated with your subscriber account and is not deleted.
* The app does not store your phone number anywhere outside the subscription flow. Anonymous Firebase Authentication is used only to isolate per-user storage in the database.
* The app requires internet access to sync notes. Without a network connection, notes will only be available locally on this device.

## Requirements

* An Android phone or tablet running Android 5.0 (Lollipop) or newer. The app is built for Android only; iOS, web, and desktop are not supported in this release.
* A working SIM card in the device with a Bangladeshi mobile number that can receive SMS (used for the subscription OTP).
* Internet connection (Wi-Fi or mobile data).
* The app runs on phones and tablets; it is built for the standard `arm64-v8a`, `armeabi-v7a`, and `x86_64` Android architectures.

---

## Support

* **For subscription or billing questions:** Contact your mobile operator and ask about "AppsPro" or "BDApps" value-added services on your account.
* **For app issues or feature requests:** See [APPSPRO_INTEGRATION.md](file:///d:/Documents/Clean-Notes/APPSPRO_INTEGRATION.md) in the project repository for technical details about the AppsPro integration.
