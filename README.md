# Aadith Sai Billing Mobile

Flutter mobile app for Aadith Sai Cloud Billing.

## Current Status

- Android release APK builds successfully
- Android emulator deployment is verified
- iOS/TestFlight is prepared for Codemagic cloud builds
- `flutter analyze` passes
- `flutter test` passes

## App Identifiers

- Android application ID: `com.aadithsai.aadith_sai_billing_mobile`
- iOS bundle ID: `com.aadithsai.aadithSaiBillingMobile`

If you use Codemagic + TestFlight, create the App Store Connect app with the same iOS bundle ID.

## Local Setup

1. Install Flutter
2. Create a local `.env` file from `.env.example`
3. Run:

```bash
flutter pub get
flutter run
```

## Environment

Create `.env`:

```env
API_BASE_URL=https://your-backend-url
APP_NAME=Aadith Sai Billing
```

## Android Internal Testing

Build release APK:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Codemagic + TestFlight

This project includes `codemagic.yaml` for:

- Android release APK build
- iOS IPA build
- App Store Connect / TestFlight publishing

### Codemagic prerequisites

Add these secrets in Codemagic before running the iOS workflow:

- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`

Optional but recommended in a Codemagic variable group:

- `CM_CERTIFICATE_PRIVATE_KEY`
- `CM_DISTRIBUTION_CERTIFICATE`
- `CM_PROVISIONING_PROFILE`

You can also use Codemagic automatic signing in the UI instead of manually providing signing files.

### Important Apple note

Apple does not allow app records to be created through Codemagic. Create the app once in App Store Connect first, then Codemagic can upload builds to TestFlight.

## Push To GitHub

Initialize local git and commit:

```bash
git init
git add .
git commit -m "Initial Flutter mobile app setup"
```

After you create an empty GitHub repository, push with:

```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

## Codemagic Workflow File

The repository root contains:

```text
codemagic.yaml
```

Once the repo is on GitHub:

1. Log in to Codemagic
2. Add the repository
3. Connect Apple Developer / App Store Connect credentials
4. Run the `ios-testflight` workflow

