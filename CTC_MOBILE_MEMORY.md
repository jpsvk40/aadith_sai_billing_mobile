# CTC Mobile — Working Memory

> Context memory for the Calcutta Tube Centre (pipes-distributor) mobile build on this app.
> Full implementation plan lives with the other CTC plans: `D:\Software Development\CalcuttaTube_Erp\CTC_MOBILE_PLAN.md`.
> Backend build for CTC is 3 tracks on `D:\Software Development\Aadith-Sai-Cloud-Billing` — A = dual-UOM/per-kg weight pricing, B = size-matrix catalog (ProductVariant), C = price tiers + trade schemes. Track C backend is BUILD-COMPLETE (jest 430/430) but the A/B/C tree is uncommitted/undeployed.

## Verdict
- **No new modules, no new tab.** Everything rides existing modules: `orders`, `customers`, `vendor_purchases`, `reports`, and existing personas (`sales_rep`, operator/counter, `site_admin`/godown).
- The one new piece of plumbing: **CompanyFeature-flag exposure**. The app gates only by `AuthUser.effectiveModules` today and has NO concept of feature flags. Backend must add `effectiveFeatures: string[]` to `/api/auth/login` + `/api/auth/me`; app gets `AuthUser.hasFeature()`. Flags off ⇒ byte-identical to today. The four flags: `dual_uom`, `matrix_catalog`, `price_tiers`, `trade_schemes`.

## 🔴 G0 — the correctness gap (why Track C goes first)
`features/orders/screens/order_create_screen.dart` is **tier-blind**. Per-line rate defaults from `GET /api/customers/:id/product-pricing` (negotiated `effectiveRate`) else `Product.sellingPrice`, and any role can edit the rate. Once Track C is live, a Dealer-tier customer with no negotiated price gets **list price** on every mobile counter order (server records it as an above-tier override). Slabs are qty-dependent so a static price map can't patch it. Fix = per-line `GET /api/price-tiers/resolve` (built; takes customerId/productId/variantId/quantity).

## Key mobile facts (as-built, 2026-07-07)
- Stack: Flutter 3.x, Riverpod, go_router, dio. `ApiConstants.baseUrl` from `--dart-define=API_BASE_URL` → `.env` → hardcoded prod fallback. Validate CTC work with `--dart-define=API_BASE_URL=<staging>` (prod fallback = stale behavior).
- `Product` model = `id, name, sellingPrice, taxPercent, unit, hsnCode` — **no SKU, no variants, no weight fields**. Bulk `GET /api/products`, client-side name filter only (no token search, no SKU).
- Order line `_OrderLineItem` → `{productId, quantity, rate, discountType, discountValue, taxPercent}`. Rate is a free editable field (override already possible, ungated). No UOM dropdown, no weight, no source chip.
- Read model `OrderItem` already parses + renders `variantLabel` (`json['variant']['label']`) read-only in `order_detail_screen.dart` — so once lines send `variantId`, the label surfaces for free.
- `customer_form_screen` is edit-only; **no dealer card** (no outstanding/credit/tier surface anywhere). `Customer` model exposes `discountPercent`, `gstMode`, addresses — no balance.
- `purchase_create_screen.dart` already has a **per-variant allocation pathway** (`variantAllocations`, from Bero BOPP width tracking) — the natural host for Track A's kg-GRN.
- **Assistant needs ZERO mobile change**: the 4 Track C tools (dealerRate/schemeProgress/tierCompare/overrideLog) are backend-driven; `ask_business_screen.dart` + `report_registry.dart`/`assistant_nav.dart` (mirrors backend NAV_ROUTES) already work.
- Roles exist and are persona-scoped: `sales_rep`, `collection_rep`, operator, `site_admin`, accounts, dispatch, technician — each with its own home/tabs (`route_guards.dart` `postLoginHome()`, `bottom_nav_bar.dart`).
- Fully online (no offline queue; Hive initialized but unused). Share: server-rendered PDF bytes → `Share.shareXFiles` + WhatsApp POST endpoints (invoices, statements, receipts, reports). **Order print is still "coming soon"** — not CTC-scoped.
- CI = Codemagic (`codemagic.yaml`): `android-release` (APK) + `ios-testflight`. No Flutter flavors; env via `--dart-define`/`.env`. Integration tests under `integration_test/` (service E2E pattern to extend).

## Phase plan (order C → B → A; ~3 wks solo AFTER integrated backend is deployed + demo-seeded)
- **Phase 0 (~1d, backend, additive):** `effectiveFeatures` on auth payloads; expose `rateBasis`/`netWeightKgPerUnit`/`weightTolerancePct` on `/api/products`; verify token-search + `/price-tiers/resolve` response shapes; optional `GET /api/customers/:id/dealer-card` aggregate.
- **Phase 1 — Track C (~4-6d):** per-line resolve + source chip (`DEALER tier · Category`, `Slab 2 applied`, amber on override), permission-gated below-tier override (block operator, allow admin/manager; server audit-logs `PRICE_OVERRIDE_BELOW_TIER` regardless); dealer card (tier badge + credit-vs-outstanding bar + scheme progress cards); owner Schemes tile; 2 snapshots.
- **Phase 2 — Track B (~3-4d):** server token search in picker when `matrix_catalog` on (chips + per-godown stock), `variantId` on lines, search-result model with SKU; 1 snapshot.
- **Phase 3 — Track A (~4-5d, BLOCKED on A landing its Prisma model fields):** dual-UOM line widget (pcs↔kg↔₹, `weightKg`/`ratePerKg`, variance badge vs `weightTolerancePct`, invariant mirrors `uomEngine.js`); GRN kg-mode on purchases; 2 snapshots.
- **Phase 4 (~2-3d):** credit-limit chip/block at customer pick (demo-video moment); integration tests vs seeded staging; Codemagic build; 5 training snapshots + master-video mobile segments.

## Hard prerequisite
Integrated A+B+C tree committed → migrated → deployed to staging → demo-seeded (`seed-pipes-demo.cjs` + `seed-pipes-tiers-schemes.cjs`). None of the mobile UI can be validated until then.
