# Phase 1 — Shared Back-Office Spine: Build & E2E Plan

_Strategy & rationale: `MOBILE_VERTICAL_RBAC_PLAN.md`. This is the actionable build + local-emulator
E2E plan for the shared finance/back-office spine. Written 2026-07-03._

## 1. Goal
Build the shared back-office surfaces **once**, gated by `effectiveModules ∩ role`, so they light up for
`admin` / `manager` / `accounts` / `accountant` in **any** vertical (Trading, Service, Construction).
Outcome: the `accounts` and `accountant` roles get a real finance persona (today they fall through to the
generic dashboard), and the admin/manager cockpit gains its missing tiles.

**Read-first principle:** GL and GST ship **read-only** on mobile; Customers/Expenses get create; Payroll
is approve-only; ESS is employee self-service. No new backend RBAC — we consume `effectiveModules` + the
`{view,create,approve,post}` grid already in the session payload.

## 2. Scope — 7 spine surfaces + finance home
| # | Surface | Module gate | Backend routes | Mobile action | Roles (● act / ○ view) |
|---|---|---|---|---|---|
| S1 | **Customers CRUD** | `customers` | `/api/customers` | extend existing list → add create/edit form | admin●, manager●, sales_rep●, accounts○, ho_user○ |
| S2 | **GST & compliance** | `gst` | `/api/gst`, `/api/gst-compliance`, `/api/gst-recon` | GST liability + return/filing status (read) | admin●, accounts●, accountant●, manager○ |
| S3 | **Payables / vendor dues / credit notes** | `vendor_purchases`, `outstanding` | `/api/vendors`, `/api/vendor-payments`, `/api/vendor-ledger`, `/api/vendor-credit-notes`, `/api/customer-credit-notes` | vendor dues list + ledger + credit notes (read) | admin●, manager●, accounts●, accountant○, site_admin○ |
| S4 | **Inventory / stock view** | `inventory` | `/api/inventory-items`, `/api/inventory-reports` | stock levels list (read) | admin○, manager○, sales_rep○, site_admin○ |
| S5 | **Expenses / advances / petty cash** | `finance_accounts` | `/api/office-expenses` | list + add expense | admin●, manager●, accounts●, accountant○ |
| S6 | **GL read** (ledger/TB/P&L/day-book) | `finance_gl` | `/api/gl` | ledger statement, trial balance, P&L, day-book (read) | accounts●, accountant●, admin○, manager○ |
| S7 | **Payroll / ESS** | `payroll` / `ess` | `/api/payroll`, `/api/hr`, `/api/ess` | payroll summary + approve; ESS self (payslips/attendance/leave) | payroll: admin○/accounts●; ESS: employee● |

## 3. App structure (new `lib/features/finance/`)
- **Finance hub** `finance_hub_screen.dart` — a tile grid (like `reports_hub`) that renders **only the
  spine surfaces the user's `effectiveModules` allow**. Single entry point; data-driven, no vertical code.
- **Screens:** `gst_screen.dart`, `payables_screen.dart`, `inventory_stock_screen.dart`,
  `expenses_screen.dart` (+ `expense_entry_screen.dart`), `gl_screen.dart` (tabs: Ledger / TB / P&L /
  Day-book), `payroll_screen.dart`, `ess_screen.dart`. Customers create/edit extends the existing
  `lib/features/customers/`.
- **Data:** `finance_repository.dart` (+ models) per surface; `finance_providers.dart`
  (`FutureProvider.autoDispose`), reusing `ApiClient`.
- **Constants:** add the routes above to `api_constants.dart`.
- **Routing:** register `/finance`, `/finance/gst`, `/finance/payables`, `/finance/stock`,
  `/finance/expenses`, `/finance/gl`, `/finance/payroll`, `/ess`. Add each to
  `route_guards.requiredModuleForLocation` (module-gate deep links).
- **Persona home / nav:** in `bottom_nav_bar._getTabsForUser`, finance roles (`accounts`/`accountant`)
  and admins get a **Finance** tab → `/finance` hub; `employee` gets an **ESS** tab → `/ess` (new persona,
  no financial tabs). `postLoginHome`: `employee` → `/ess`; finance roles stay on `/dashboard` but the hub
  is one tap away. Dashboard quick-access also surfaces spine tiles, each module-gated.

## 4. Gating rules (must hold)
1. A surface renders **iff** `user.hasModule(<gate>)` — hub hides tiles the user lacks; deep links bounce
   to `/unauthorized` via `route_guards`.
2. `admin`/`manager` inherit all company modules → see every spine surface the **company** enabled.
3. Company-level gate still applies: a company that didn't enable `gst`/`finance_gl` shows **no** GST/GL
   surface even to its admin.
4. GL + GST are **read-only** — no write/post actions rendered. Payroll = approve-only. Respect the
   `{view,create,approve,post}` grid where present.

## 5. E2E test plan (local emulator)
**Backend:** local on `http://localhost:3001` (health 200). **App:** release APK built with
`--dart-define=API_BASE_URL=http://10.0.2.2:3001`. adb at `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`.
_adb `input text` scrambles on a loaded emulator — type in ≤5-char chunks; screencap hang → reboot._

### Credentials
| Purpose | Login | Company / vertical |
|---|---|---|
| **Admin smoke (all spine visible)** | `muthu.etraj@gmail.com` / `Admin123` | co 3 — Trading + **full spine** (customers, invoices, payments, collections, outstanding, vendor_purchases, gst, finance_accounts, finance_gl, payroll, inventory, reports) |
| Role-boundary users | seed `scripts/seed-spine-e2e.cjs` on **co 3**: `spine-accounts@` / `spine-accountant@` / `spine-manager@` / `spine-sales@` / `spine-employee@` `example.com`, all `Test@1234` | co 3 (spine-complete) |
| Company-gate negative | `erp-e2e-admin@example.com` / `Test@1234` | co 13 — ERP, **no finance/gst modules** |

> Seeding role users into co 3 is a **data insert on the shared Neon DB** — notify + run against TEST
> branch first, per standing rule. muthu (admin) needs no seed.

### Positive cases
| # | Login | Expect |
|---|---|---|
| P1 | muthu (admin, co 3) | Finance hub shows **all 7** surfaces; create a customer; GST liability loads; vendor dues list; stock list; add an expense; open Ledger/TB/P&L/Day-book (read); payroll summary |
| P2 | spine-accounts | Finance tab present; GST, Payables, Expenses, GL, Payroll, Customers(view) visible & load; can add expense |
| P3 | spine-accountant | GL (ledger/TB/P&L/day-book) + Expenses + Payables(view) + Reports visible; GL read-only |
| P4 | spine-manager | Finance surfaces visible (broad); customer create works |
| P5 | spine-sales | Customers **CRUD** visible; **GST/GL/Payables/Expenses/Payroll absent** from hub & nav |
| P6 | spine-employee | **ESS only** (payslips/attendance/leave); no finance tab, no dashboard finance tiles |

### Negative cases
| # | Login | Action | Expect |
|---|---|---|---|
| N1 | spine-sales | deep-link `/finance/gst` | bounce → `/unauthorized` |
| N2 | spine-sales | deep-link `/finance/gl` | bounce → `/unauthorized` |
| N3 | spine-employee | deep-link `/finance/payables` or `/customers` | bounce → `/unauthorized` |
| N4 | spine-accountant | look for payroll approve | payroll tab **absent** (no `payroll` module); `/finance/payroll` → unauthorized |
| N5 | erp-e2e-admin (co 13) | open Finance hub | **no** GST/GL/Payables/Expenses/Payroll (company didn't enable them) — proves company-gate |
| N6 | muthu | create customer with blank name | inline validation / 400 handled, no crash |
| N7 | muthu / accounts | GL + GST screens | **no** write/post buttons (read-only holds) |

### Emulator run loop
1. `flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3001`
2. `adb install -r build/app/outputs/flutter-apk/app-release.apk` (clears session — re-login each cred)
3. For each credential: login → walk its positive rows → attempt its negative deep-links → screenshot.
4. Backend boundaries also curl-verified (module∩role) as a fast pre-check before UI.

## 6. Build order (within Phase 1)
1. Scaffolding: `finance/` feature, `finance_hub_screen`, api_constants, routes + guards, nav/home wiring
   (empty screens) — verify gating with muthu + spine-sales first (cheap, proves the model).
2. S1 Customers CRUD (extends existing) → S5 Expenses (create pattern) → S3 Payables → S4 Inventory →
   S2 GST → S6 GL (read tabs) → S7 Payroll + ESS.
3. `flutter analyze` clean after each; E2E matrix after S-group completes.

## 7. Definition of done
- All 7 surfaces render **only** for entitled module∩role; deep-link guard bounces the rest.
- muthu smoke passes P1; role users pass P2–P6; N1–N7 hold.
- GL/GST read-only; no per-vertical branches (same code path in Trading/Service/Construction).
- `flutter analyze` clean; screenshots per credential; then commit + push (`main` → Codemagic).
