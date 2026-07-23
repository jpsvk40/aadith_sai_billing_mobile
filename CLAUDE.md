# Aadith Sai Business Cloud — Mobile (Flutter) — Claude Code Guide

Auto-loaded every session. **These instructions override default behavior.**

The Flutter mobile client for the Aadith billing/ERP platform. It is a **thin, fully-online client** over
the Node/Express backend in the sibling repo `../Aadith-Sai-Cloud-Billing` — same JWT auth, same tenants,
same roles. The app adapts its home + nav to the logged-in company's **enabled modules** (billing vs
service vs construction verticals).

## Stack

| Concern | Choice |
|---|---|
| Framework | Flutter |
| State | **Riverpod only** (`flutter_riverpod`) — no bloc/getx; providers colocated per feature |
| Routing | **go_router** — one `appRouterProvider` (built once, `refreshListenable` bridged from `authProvider`) + a single `ShellRoute` → `AppBottomNavBar` |
| Networking | **Dio** — one `ApiClient` (`lib/data/network/api_client.dart`) + `AuthInterceptor` (Bearer JWT, 401→logout) |
| Local | Hive initialized but **effectively unused** — treat the app as online-only |
| Push | FCM + `flutter_local_notifications` (`lib/core/services/push_service.dart`); no-op without Firebase config |
| Release | **Codemagic** (`codemagic.yaml`); **no EAS** (that's Expo); no Flutter flavors — env via `--dart-define`/`.env` |

## Architecture — feature-first over a shared spine

```
lib/
  main.dart · app.dart      bootstrap: dotenv → Hive.initFlutter → PushService.init → runApp(ProviderScope)
  core/
    constants/api_constants.dart   base-URL resolver + EVERY endpoint string (the API contract)
    services/push_service.dart     FCM
    theme/  utils/  errors/
  data/
    network/  api_client.dart (Dio) · auth_interceptor.dart
    models/   ~26 hand-written DTOs with manual fromJson (auth_user_model.dart, order, invoice, …)
    repositories/  per-domain repos calling ApiClient
    local/    Hive (unused)
  features/   23 folders (auth, dashboard, alerts, approvals, assistant, orders, customers, invoices,
              payments, purchases, receivables, collections, commissions, finance, erp, dispatch,
              service, site_logistics, correspondence, reports, settings, profile, shared)
              each ≈ screens/ + providers/ (+ occasional models/registry)
  router/     app_router.dart (GoRouter + ShellRoute) · route_guards.dart
  widgets/    navigation/bottom_nav_bar.dart · navigation/floating_assistant_button.dart
```

## Non-negotiables

- **Base URL defaults to PROD.** Resolution: `String.fromEnvironment('API_BASE_URL')` → dotenv → hardcoded
  `https://www.aadithsaibillingcloud.com`. `.env` is NOT bundled, so a plain run hits prod. **Always test
  non-prod work with `--dart-define=API_BASE_URL=http://10.0.2.2:3001`** (emulator → local backend).
- **Session/RBAC**: `AuthUser` (`lib/data/models/auth_user_model.dart`) carries `effectiveModules`,
  `normalizedRole`, `appAccess`, `aiAssistantAccess` + role getters + `hasModule/hasAnyModule/hasSpine`.
  There is **no `tier` and no capability grid** on mobile — gate UI by module/role only. `production`/`packing`
  are `appAccess:false` (no app login).
- **Navigation is persona-driven**: `route_guards.dart` (`requiredModuleForLocation`, `canAccessLocation`,
  `postLoginHome`, `redirectForAuthState`) + `AppBottomNavBar` compute per-persona tab sets. Deep links are
  module-gated. See the `mobile-persona-nav` skill.
- **API contract**: the backend (`../Aadith-Sai-Cloud-Billing`) is the source of truth. There is no codegen.
  When an endpoint/field/shape changes on the backend, update `api_constants.dart` + the matching
  `lib/data/models/*.dart` `fromJson`. **Keep the `/api` prefix on paths** (a missing prefix caused a past
  404 bug). See the `mobile-api-contract` skill.
- **UI errors**: surface via `lib/core/errors/`; never crash on a null/absent JSON field — DTOs must tolerate it.
- **Single git branch = `main`** (no `development` here). Never push mid-session unless asked; mobile ships via Codemagic.

## Build / test

```bash
flutter pub get
flutter analyze
flutter test                                   # widget/unit
flutter test integration_test                  # only Service module has real E2E coverage today
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001   # emulator → local backend
```

## Agent routing

Describe the work; Claude routes to the right specialist in `.claude/agents/`. Use `dispatcher` for
anything spanning several, or when unsure. Backend/API questions cross the repo boundary — the
`additionalDirectories` setting lets you read `../Aadith-Sai-Cloud-Billing`.

| Working on… | Agent |
|---|---|
| Anything / unsure / multi-area | `dispatcher` |
| Dio client, api_constants, session model, router/ShellRoute, theme, push — the shared foundation | `mobile-core-platform` |
| Role→module→nav gating, personas, `postLoginHome`, bottom-nav tab sets | `mobile-persona-rbac` |
| Orders, customers, invoices, payments, purchases (AI scan), receivables, collections, commissions | `mobile-billing-sales` |
| Finance spine: GST, payables, GL, expenses, inventory, payroll, advances, ESS | `mobile-finance-spine` |
| Machinery/operator, projects, tenders, dispatch, site logistics, correspondence | `mobile-erp-field` |
| Service & warranty: technician home, tickets, warranty lookup, AMC | `mobile-service` |
| AI assistant, reports hub/registry (PDF+WhatsApp), alerts, approvals inbox | `mobile-assistant-reports` |
| Codemagic, iOS signing/Podfile, Android Gradle, version bump, TestFlight/App Store | `mobile-release-ci` |
| Reviewing changed Dart | `reviewer` |
| Widget/integration tests | `tester` |
```
