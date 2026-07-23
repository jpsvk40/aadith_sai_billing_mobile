# Mobile (Flutter) — Service Track-Record + Warranty-RMA + Rework — Implementation Plan

**Status: IMPLEMENTED + EMULATOR-TESTED (not yet committed)** · App: `aadith_sai_billing_mobile` (Flutter · Riverpod · go_router · Dio) · Date: 2026-07-22

> Built end-to-end on 2026-07-22. `flutter analyze` clean. Emulator E2E (Pixel_8, API 35): the automated `integration_test/service_rma_rework_test.dart` passes, and the live app was driven through the full RMA round-trip (Send → "Sent to company ✓" RMA-000003 → Mark received REPLACED → "Back from Manufacturer") plus the Customer Service History screen and rework linkage. Emulator setup notes are in the memory. Changes uncommitted on `main`.

Brings the three Service & Warranty features already shipped on the **web** to the mobile app, matching the approved mobile mockup (bottom-sheet flows in the app's Material design). The **backend is already built + tested** — the mobile app is a thin client over the same endpoints, so this is almost entirely additive Dart UI + a couple of repository methods (plus one tiny optional backend endpoint for F1).

| Feature | Backend status | Mobile work |
|---|---|---|
| **F1 · Customer service history** | endpoints exist; +1 thin bundle endpoint recommended | **new screen** (greenfield — no customer-360 exists on mobile) |
| **F2 · Warranty RMA** | done (`POST /:id/rma`, `PATCH /:id/rma/:rmaId/receive`, `GET /:id/rma`, `GET /rma/outstanding`) | model + status + 2 bottom sheets + worklist screen |
| **F3 · Rework** | done (`POST /:id/rework`) | 1 bottom sheet + badges (reuses status/nav plumbing) |

---

## 0. Conventions to follow (verified in-repo)

- **State:** Riverpod. `Provider` for the repo, `FutureProvider(.family)` for reads, `StateNotifier`+`copyWith` for lists. After a mutation: `ref.invalidate(ticketDetailProvider(id))` + reload the list notifiers (the existing `_refresh()` in `ticket_detail_screen.dart`).
- **Nav:** go_router. New screens are flat `GoRoute`s inside the single `ShellRoute` in `lib/router/app_router.dart`. Keep them under `/service/*` so `route_guards.dart` auto-gates them on `warranty_service` (no extra guard code).
- **API:** Dio via `ApiClient`; every endpoint string lives in `lib/core/constants/api_constants.dart` (keep the `/api` prefix); auth token auto-attached by `auth_interceptor.dart`.
- **"Full-page modal" → mobile idiom:** `showModalBottomSheet(isScrollControlled: true)` wrapped in `Padding(bottom: MediaQuery.viewInsets.bottom)` for forms (mirror `_raiseEstimate` / `_recordPayment` / `_handover`). Multi-field/live sheets use `StatefulBuilder` and return via `Navigator.pop(ctx, result)`.
- **Models:** hand-written DTOs with **tolerant** `fromJson` (must survive absent fields — new fields default to null/false/empty).
- **Status UI single source of truth:** `lib/features/service/service_status.dart` (`transitions`, `nextStatuses`, `label`, `color`, `ServiceStatusChip`).
- **Roles:** `authProvider.user` → `canBill` (admin/accounts), `isTechnician`. Gate inline as the detail screen already does.
- **Colors:** `lib/core/theme/app_colors.dart` (`primary #0D6EFD`, success/warning/danger/info); rework purple `0xFF7C3AED` (already used for AI accents). Section idiom = the `_section(title, children)` / `_kv(k,v)` helpers in `ticket_detail_screen.dart`.
- **Local run:** `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001` (Android emulator → local backend).

---

## F3 · Rework (do first — smallest, unlocks the linked-ticket plumbing)

### Model — `lib/data/models/service_ticket_model.dart`
Add to `ServiceTicket` (tolerant parse): `final int? reworkOfTicketId; final bool isRework; final String? reworkReason; final TicketRef? reworkOf; final List<TicketRef> reworks;` where `TicketRef` is a tiny `{id, ticketNumber, status}` DTO. Parse `isRework: json['isRework'] == true`, `reworkOf: json['reworkOf'] != null ? TicketRef.fromJson(...) : null`, `reworks: (json['reworks'] as List?)?.map(TicketRef.fromJson).toList() ?? const []`.

### Repo — `lib/data/repositories/service_repository.dart`
```dart
Future<ServiceTicket> rework(int id, {required String reason, bool isChargeable = false}) async {
  final data = await _client.post(ApiConstants.serviceTicketRework('$id'),
      data: {'reason': reason, 'isChargeable': isChargeable});
  return ServiceTicket.fromJson(data as Map<String, dynamic>);
}
```
Endpoint in `api_constants.dart`: `static String serviceTicketRework(String id) => '/api/service-tickets/$id/rework';`

### UI — `ticket_detail_screen.dart`
- **Reopen action:** on `DELIVERED`/`CLOSED`, add a "Reopen for rework" entry — either in the AppBar `PopupMenuButton` or a small card button. Opens `_reworkSheet()` (bottom sheet, purple accent): a required reason `TextField` + a "Charge for this rework" `Switch` (off by default; only shown when `canBill`). On submit → `_run(() => repo.rework(t.id, reason:…, isChargeable:…))`, then `context.go('/service/tickets/${newTicket.id}')`.
- **Badges:** in `_statusHeader`, if `t.isRework && t.reworkOf != null` show a tappable `↺ Rework of ${t.reworkOf.ticketNumber}` chip (→ that ticket); render `t.reworks` as `Reworked → SVC-y` chips.

**Effort: S (~½ day).**

---

## F2 · Warranty RMA / company replacement

### Model — `service_ticket_model.dart`
New DTO `ServiceTicketRma { id, rmaNumber, vendorId?, companyName?, outboundRef?, sentAt?, expectedReturnAt?, receivedAt?, outcome, replacementSerial?, reclaimAmount?, status, notes? }` (tolerant). Add `final List<ServiceTicketRma> rmas;` to `ServiceTicket` (`(json['rmas'] as List?)?.map(ServiceTicketRma.fromJson).toList() ?? const []`).

### Status FSM — `lib/features/service/service_status.dart`
Add to `transitions` (mirror backend): `DIAGNOSED`/`AWAITING_PARTS`/`IN_PROGRESS` gain `'SENT_TO_COMPANY'`; add `'SENT_TO_COMPANY': ['RECEIVED_FROM_COMPANY','CANCELLED']`, `'RECEIVED_FROM_COMPANY': ['IN_PROGRESS','READY','CANCELLED']`. Add `label()` (`Sent to manufacturer` / `Back from manufacturer`) + `color()` (info / info-dark) cases. Add `const rmaStatuses = ['SENT_TO_COMPANY','RECEIVED_FROM_COMPANY'];` and **filter these out of the plain "Change status" sheet** (`nextStatuses` minus `rmaStatuses`), since they're driven by the RMA actions — exactly how the web filters them.

### Endpoints — `api_constants.dart`
```dart
static String serviceTicketRma(String id) => '/api/service-tickets/$id/rma';
static String serviceTicketRmaReceive(String id, String rmaId) => '/api/service-tickets/$id/rma/$rmaId/receive';
static const String serviceTicketsRmaOutstanding = '/api/service-tickets/rma/outstanding';
```

### Repo — `service_repository.dart`
```dart
Future<ServiceTicket> sendRma(int id, {String? companyName, int? vendorId, String? outboundRef, DateTime? expectedReturnAt, String? notes}) async {
  final data = await _client.post(ApiConstants.serviceTicketRma('$id'), data: {
    if (companyName != null) 'companyName': companyName,
    if (vendorId != null) 'vendorId': vendorId,
    if (outboundRef != null) 'outboundRef': outboundRef,
    if (expectedReturnAt != null) 'expectedReturnAt': expectedReturnAt.toIso8601String(),
    if (notes != null) 'notes': notes,
  });
  return ServiceTicket.fromJson(data as Map<String, dynamic>);
}
Future<ServiceTicket> receiveRma(int id, int rmaId, {required String outcome, String? replacementSerial, double? reclaimAmount, String? notes}) async { … PATCH serviceTicketRmaReceive … }
Future<List<ServiceTicketRma>> rmaOutstanding() async { final d = await _client.get(ApiConstants.serviceTicketsRmaOutstanding); return _asList(d).map(ServiceTicketRma.fromJson).toList(); }
```

### Providers — `service_providers.dart`
`final rmaOutstandingProvider = FutureProvider.autoDispose((ref) => ref.read(serviceRepositoryProvider).rmaOutstanding());`

### UI — `ticket_detail_screen.dart`
- **RMA `_section`** (after Parts/Charges): lists `t.rmas` (rmaNumber, company, sent/expected/received, outcome chip). When status ∈ sendable → a **"Send to company"** button opening `_sendRmaSheet()` (form: company name, docket ref, expected-return `DatePicker`, notes → `repo.sendRma`). For each `SENT` rma → **"Mark received"** opening `_receiveRmaSheet()` (outcome `ChoiceChip`s Replaced/Repaired/Rejected, replacement-serial field shown when Replaced, reclaim ₹, notes → `repo.receiveRma`). Both use `_run()` + `_refresh()`.
- **Steps/timeline** already render the new statuses from `t.events`.

### New screen — `lib/features/service/screens/rma_outstanding_screen.dart`
"Out at company" worklist: `ref.watch(rmaOutstandingProvider)`, cards per RMA with an **overdue** left-border/red chip (`r.overdue`, `r.daysOut`) and a quick "Mark received" → the same `_receiveRmaSheet` flow (navigate into the ticket or inline). Register `GoRoute('/service/rma/outstanding')` in `app_router.dart`; add a quick-link tile in `service_dashboard_screen.dart` (admin) / `service_home_screen.dart`.

**Effort: M (~1.5–2 days).**

---

## F1 · Customer service history (greenfield screen)

No customer-360 exists on mobile, so this is a **new screen**. Two data options:

- **(Recommended) tiny backend bundle endpoint** so mobile needs no `business_trace` module and reuses the tested aggregator:
  `GET /api/service-tickets/customer/:customerId/history` in `backend/src/routes/service-tickets.js` (before `/:id`), gated by the router's existing `requireModule('warranty_service')`, returning `getCustomerServiceHistory(prisma, req.companyId, customerId, {limit:10})` (helper already exists). ~10 lines + an E2E assertion.
- (Alternative) assemble client-side from existing endpoints — `getTickets(customerId:)`, `getItems(customerId:)`, `getContracts()` — and compute the stats in Dart. More app code, no backend change; use only if a backend edit is undesirable.

### Endpoint + repo
`static String serviceCustomerHistory(String id) => '/api/service-tickets/customer/$id/history';`
`Future<CustomerServiceHistory> customerHistory(int customerId) async { … get … return CustomerServiceHistory.fromJson(data); }`
New DTO `CustomerServiceHistory { stats, recentTickets, warrantyItems, contracts }` (mirrors the web JSON: `stats.{totalTickets, openTickets, deliveredTickets, reworkTickets, repeatRepairRate, totalServiceRevenue, serviceOutstanding, lastServiceDate, activeWarrantyItems, activeAmc, warrantyItems, amcContracts}`).

### Provider + screen
`final customerServiceHistoryProvider = FutureProvider.family.autoDispose((ref, int id) => ref.read(serviceRepositoryProvider).customerHistory(id));`
New `lib/features/service/screens/customer_service_history_screen.dart`: customer header + a 2-col KPI-tile grid (Jobs / Rework+rate / Revenue / Outstanding / Warranty units / AMC — reuse the `_kpi`/`_stat` tiles from `service_dashboard_screen.dart`) + a recent-service list (rows tap → `/service/tickets/:id`, rework rows tagged) + registered-units chips. Route `GoRoute('/service/customers/:id')` in `app_router.dart`.
**Entry point:** in the ticket detail's "Customer & Device" section, add a "View service history" `TextButton.icon` → `/service/customers/${t.customer.id}`.

**Effort: S–M (~1–1.5 days).**

---

## Testing

- **Integration tests** (`integration_test/` — the app's real E2E home): extend the service flow to cover diagnose → send-to-company → receive-back → resume → deliver; reopen-for-rework spawns a linked ticket; customer-history screen renders stats. Run against local backend via `--dart-define=API_BASE_URL=http://10.0.2.2:3001`.
- **Manual drive** (per repo memory): Pixel emulator + demo login; verify the two bottom sheets, the worklist overdue flag, and the history tiles. The backend already has 11 passing web E2E tests covering the same endpoints, so mobile testing focuses on the Dart UI + parsing.

---

## Sequencing & effort

| Order | Feature | Files | Effort |
|---|---|---|---|
| 1 | **F3 Rework** | model, service_status, repo, ticket_detail_screen | S (~½d) |
| 2 | **F2 RMA** | model (+RMA DTO), service_status, repo, providers, ticket_detail_screen, new rma_outstanding_screen, router | M (~1.5–2d) |
| 3 | **F1 History** | (+backend bundle endpoint), repo (+DTO), providers, new customer_service_history_screen, router, ticket-detail entry point | S–M (~1–1.5d) |

**Total ~3–4 days** incl. integration tests. Files touched: `api_constants.dart`, `service_repository.dart`, `service_ticket_model.dart`, `service_status.dart`, `service_providers.dart`, `ticket_detail_screen.dart`, `app_router.dart`, + 2 new screens (+ optional 1 backend endpoint).

## Decisions to confirm
1. **F1 data source** — recommended: add the tiny `GET /service-tickets/customer/:id/history` backend endpoint (reuses the tested helper, no `business_trace` dependency) vs. client-side assembly.
2. **RMA-outstanding entry point** — a quick-link tile on the Service dashboard/home (recommended) vs. a new bottom-nav tab (heavier).
3. **Rework reopen placement** — AppBar overflow menu vs. an inline card button on delivered tickets.
4. **Scope now** — all three, or F3+F2 first (ticket-detail-centric) then F1 (new screen) separately.
