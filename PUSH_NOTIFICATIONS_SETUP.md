# Push Notifications (FCM) — Setup & Go-Live

Every in-app alert (all 19 types: payment overdue, delivery due/overdue, credit-limit
breach, vendor payment overdue, commission due, large order, stock shortage, order
cancelled/return, letter reply overdue, tender deadline, instrument expiring, legal
hearing, payment received, etc.) now **fans out to push notifications**.

The code — backend + mobile — is fully built and wired. What remains is a one-time
**Firebase project** setup, because delivering push requires credentials only the app
owner can create. Until those are added, push is a safe no-op (the app works normally;
the backend logs `[push] (disabled) would deliver "…" to N device(s)`).

## Architecture (already implemented)

**Backend** (`Aadith-Sai-Cloud-Billing/backend`)
- `PushToken` table (migration `20260702120000_add_push_tokens`) — one row per device.
- `POST /api/devices/register` / `POST /api/devices/unregister` — token lifecycle.
- `src/helpers/push.js` — lazy Firebase Admin init; `sendAlertPush()` fans a new alert to
  the target users' active tokens (personal alert → that user; company-wide → all
  admins/managers). Prunes dead tokens. No-op + log if not configured.
- Wired into `createAlertIfNew()` (alerts.js) and `createPaymentAlert()` (paymentWorkflow.js),
  so **every** alert type triggers a push.

**Mobile** (`aadith_sai_billing_mobile`)
- `firebase_core`, `firebase_messaging`, `flutter_local_notifications` in `pubspec.yaml`.
- `lib/core/services/push_service.dart` — init, permission, token registration, foreground
  display, background handler. Registers the token on login/session-restore, unregisters on logout.
- Startup init is fire-and-forget and guarded — if Firebase isn't configured it degrades silently.

## To go live (one-time)

### 1. Create the Firebase project
- console.firebase.google.com → Add project (e.g. "Aadith Sai Billing").
- Add an **Android app**: package `com.aadithsai.aadith_sai_billing_mobile` → download
  `google-services.json` → place at `android/app/google-services.json`.
- Add an **iOS app**: bundle id `com.aadithsai.aadith_sai_billing_mobile` → download
  `GoogleService-Info.plist` → add to `ios/Runner/` (via Xcode so it's bundled).

### 2. Apply the Android Google-services Gradle plugin
- `android/settings.gradle.kts` plugins block: add
  `id("com.google.gms.google-services") version "4.4.2" apply false`
- `android/app/build.gradle.kts` plugins block: add `id("com.google.gms.google-services")`
- (Core-library desugaring is already enabled — nothing to do there.)

### 3. iOS push capability
- In Xcode: Signing & Capabilities → add **Push Notifications** + **Background Modes → Remote notifications**.
- Apple Developer → create an **APNs Auth Key (.p8)** → upload it in Firebase → Project
  Settings → Cloud Messaging → Apple app configuration.

### 4. Backend credentials (FCM sending)
- Firebase → Project Settings → **Service accounts** → *Generate new private key* → JSON.
- Set ONE of these env vars on the backend (Render + local `.env`):
  - `FIREBASE_SERVICE_ACCOUNT` = the full JSON (single line), **or**
  - `FIREBASE_SERVICE_ACCOUNT_PATH` = path to the JSON file.
- Restart the backend. On boot it logs `[push] Firebase Admin initialised — push notifications enabled.`

### 5. (Recommended) generate firebase_options.dart
- `dart pub global activate flutterfire_cli && flutterfire configure` — wires both platforms
  and creates `lib/firebase_options.dart`. Then change `Firebase.initializeApp()` in
  `push_service.dart` to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

## Verify
1. Log in on a device → backend gets a real token (`prisma.pushToken` row, not `FAKE_*`).
2. Trigger an alert (e.g. record a payment, or `POST /api/alerts/generate`).
3. Backend log shows `[push] ... to N device(s)` **without** "(disabled)"; the device shows a notification.

## Notes
- Recipients mirror in-app alert visibility (personal vs admins/managers) — no spam to reps.
- Tokens the FCM backend reports invalid are auto-deactivated.
- The `PushToken` migration must be applied to **production** before go-live
  (`prisma migrate deploy`, or the idempotent SQL in the migration folder).
