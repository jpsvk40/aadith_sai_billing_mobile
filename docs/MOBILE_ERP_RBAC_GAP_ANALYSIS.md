# Mobile ERP — RBAC Gap Analysis & Role→Module Map

_Authoritative reference for building out the Aadith Sai Business Cloud mobile app (Flutter) toward
the full web ERP. Originally generated 2026-07-01 from a three-way audit of the backend RBAC, the web
frontend, and the mobile app._

**Updated 2026-07-03** to reflect shipped work: unified **Approvals inbox** ✅, **Reports hub** ✅, the
new **`operator`** role + **machinery field persona** ✅, and **site-logistics proof-photo capture** ✅.
See §7 for the current "what's still left" list.

> **Next up — Shared Spine (Phase 1):** the P1/P2 back-office items (customers, GST, payables, inventory,
> expenses, GL, payroll) are common to all three verticals and owned by the finance/office roles. Strategy
> + role/vertical grids: [`MOBILE_VERTICAL_RBAC_PLAN.md`](./MOBILE_VERTICAL_RBAC_PLAN.md). Actionable build
> + emulator E2E plan: [`SHARED_SPINE_BUILD_PLAN.md`](./SHARED_SPINE_BUILD_PLAN.md).

## 1. The shape of the gap
- **Web** = full ERP: ~145 routes / ~130 pages across **24 functional areas** in 3 "worlds"
  (Trading, Service, Construction) + shared billing/back-office/finance.
- **Mobile** = tailored persona homes for **5 personas** (admin/role-aware dashboard, sales_rep,
  collection_rep, **technician**, **operator**). manager, accounts, accountant, estimator, site_admin,
  ho_user, dispatch, employee still land on the generic role-aware `/dashboard` (they get the correct
  **module tabs**, but no bespoke home).
- **Key enabler:** the login/session payload already carries **`effectiveModules`** (role modules ∩
  company enabled modules), **`normalizedRole`**, **`tier`**, **`appAccess`**, and a
  `{view,create,approve,post}` capability grid. The mobile home is **data-driven** — no new backend RBAC
  needed; we consume what's there (`auth.js` sets `req.user.effectiveModules` etc.).

## 2. Roles (backend `config/roleAccess.js`)
19 roles. Mobile-relevant ones bolded.
- **super_admin / super_user** — platform god mode; bypass module + company scope (web-only).
- **admin** — company owner; inherits ALL enabled company modules; only role for company config.
- **manager** — broad ops + finance manager (fixed wide module list; a POST role).
- **sales_rep** — field sales; customers/products/orders/custom_misc/invoices/reports/crm.
- **collection_rep** — field collections; collections/outstanding/payments/invoices/customers.
- **accounts** — clerk; invoices/payments/collections/gst/vendor_purchases/payroll/finance; POSTs to GL.
- **accountant** — GL-focused; finance_gl/finance_accounts/reports/invoices/payments/vendor_purchases; POSTs.
- **technician** — warranty_service only; `assignedTo=me`; AI off by default. **(mobile: DONE)**
- **operator** — _(NEW 2026-07-03)_ machinery + alerts only; USER tier (view + create, no approve/post);
  own machines via `Machine.operatorUserId`; costs hidden. **(mobile: DONE)**
- **estimator** — projects/customers/alerts.
- **site_admin** — one site end-to-end up to L1 approval; site-scoped; no GL post.
- **ho_user** — head-office cross-site reviewer/approver; broad VIEW + approvals; never posts.
- **dispatch** — dispatch/transports/orders/invoices.
- **employee** — ESS only (`/api/ess`, self-scoped: payslips/attendance/leave).
- **ca** — external auditor; read-only view of a client's books (web-only).
- **production / packing** — `appAccess:false` → NOT meant to have an app login. Exclude from mobile.

## 3. Modules (35 keys; 5 derived)
customers, products, inventory*, orders, production, packing, dispatch, invoices, payments, alerts,
reports, settings, representatives, bulk_upload, custom_misc, vendor_purchases, gst, collections*,
outstanding*, transports*, payroll, finance_accounts, business_trace, invoice_scanner,
gst_filing_assistant, year_close_assistant, inventory_intelligence, sales_intelligence,
warranty_service, projects, machinery, tender, correspondence, finance_gl, crm.

`*` derived/auto-added: products→inventory; reports→outstanding; representatives|payments|reports→
collections; payments|reports|collections→vendor_purchases; dispatch→transports.

**Two-layer gating:** a module route is reachable only if BOTH the company has it enabled (or derived)
AND the user's role includes it (`effectiveModules` = role modules ∩ company modules). `admin`/`ca`
inherit all company modules; super roles bypass. Sensitive admin/super endpoints add a hard
`authorize(role)` allow-list. Optional capability grid `{view,create,approve,post}` — `post` (GL)
limited to admin/accounts/accountant/manager/super. Mobile enforces the same two-layer gate client-side
via `route_guards.dart` (`requiredModuleForLocation` + `hasModule`).

## 4. Web area → mobile status & priority
Priority = belongs on a phone (field / monitor / approve), not heavy back-office (stays web).
Status legend: ✅ done · ⚠️ partial · ❌ not started.

| Web area | Mobile status | Who needs it | Priority |
|---|---|---|---|
| Dashboard/Home, Orders, Invoices, Payments, Collections, Vendor Purchases (+scan), Service, AI, Alerts | ✅ | per role | done |
| **Approvals inbox** (cross-cutting) | ✅ **DONE** — unified (payments, POs, orders; approve/reject + reason) | admin, mgr, ho_user, accounts | ~~P0~~ done |
| **Reports** (billing) | ✅ **DONE** — reports hub over `/api/reports/*` (outstanding, overdue, sales-by-customer, …) | admin, mgr, accounts | ~~P0~~ done |
| **Service & Warranty** (technician + AMC) | ✅ **DONE** — My-Day home, tickets, today, calendar, AMC contracts, reports, warranty lookup | technician, service mgr | done |
| **Construction — Machinery** | ✅ **DONE** — operator field persona: my machines, logbook, breakdown + AI diagnosis; supervisor transfer-receive | operator, site_admin, mgr | done |
| **Construction — Site logistics** | ✅ **DONE** — site surveys + deliveries with **proof-photo** capture (create + confirm-at-site) | site_admin, estimator | done |
| **Construction — Projects / Tenders / Correspondence** | ⚠️ read-only lists + letters (no estimate/BOQ/DPR/tender-workflow entry) | estimator, site_admin, ho_user | **P2** |
| **Customers** create/edit | ⚠️ list only | admin, mgr, sales_rep | **P1** |
| **CRM / Leads / Quotations** | ❌ | sales_rep, admin, mgr | **P1** |
| **GST & Compliance** (returns/e-invoice/filing) | ❌ | admin, accounts, accountant | **P1** |
| **Vendor payments / outstanding / credit notes** | ⚠️ purchase create+list only; no outstanding/credit-notes | admin, mgr, accounts | **P1** |
| **Inventory / stock** view | ❌ pickers only | admin, mgr, site_admin | **P1** |
| **Notification Inbox** (unified cross-module) | ⚠️ alerts list only | all | **P1** |
| **Expenses / advances / petty cash** | ❌ | admin, mgr, accounts | **P2** |
| **GL / accounting** read (ledgers/TB/P&L/day-book) | ❌ | admin, accountant, accounts | **P2 read-only** |
| **Payroll / HR / ESS** | ❌ (employee persona absent) | admin(approve), employee | **P2** |
| Bank recon / Owner equity / Fixed assets / Year-end / Admin setup / Users / Module toggles / Bulk import / CA / Super-admin | ❌ | admin/ca/super | **Web-only** |

## 5. Role → modules needed on mobile (bold = current gap)
| Role | appAccess | Modules on mobile | Persona home today |
|---|---|---|---|
| owner/admin | ✅ | orders, invoices, payments, collections, vendor_purchases, approvals ✅, reports ✅, **inventory(view)**, **gst(status)**, **crm**, warranty_service, alerts, ai, **finance_gl(read)** | ✅ role-aware dashboard |
| manager | ✅ | ~admin minus company-config | ⚠️ generic dashboard (module tabs only) |
| sales_rep | ✅ | orders, customers(**CRUD**), products(view), custom_misc, invoices(view), **crm/quotations**, reports, commissions | ✅ rep |
| collection_rep | ✅ | collections, payments, invoices, customers(view), **outstanding** | ✅ rep |
| accounts | ✅ | invoices, payments, collections, **outstanding**, **gst**, vendor_purchases, **gst_filing_assistant**, approvals ✅, **finance_accounts** | ⚠️ generic dashboard |
| accountant | ✅ | **finance_gl(read)**, **finance_accounts**, reports, invoices, payments, vendor_purchases, approvals ✅ | ⚠️ generic dashboard |
| technician | ✅ | warranty_service | ✅ **DONE** (`/service/home`) |
| operator | ✅ | machinery, alerts | ✅ **DONE** (`/machinery/home`) |
| estimator | ✅ | **projects/estimates**, customers, alerts | ⚠️ generic + ERP tabs |
| site_admin | ✅ | orders, **inventory**, vendor_purchases, dispatch, machinery ✅, projects (⚠️ site-logistics ✅), payroll(view); site-scoped L1 approve | ⚠️ generic + ERP tabs |
| ho_user | ✅ | broad **view + approvals** across sites | ⚠️ generic dashboard |
| dispatch | ✅ | **dispatch queue**, transports, orders, invoices | ⚠️ generic dashboard |
| employee | ✅ | **ess: payslips, attendance, leave** | ❌ absent |
| production/packing | ❌ | — (no app login) | excluded |
| ca | web | read-only auditor | web-only |

## 6. Company Owner (admin) — mobile requirements ("owner cockpit")
The owner uses mobile to **monitor, approve, and spot-check** — not for data entry.

| # | Owner need | What it shows | Mobile status |
|---|---|---|---|
| A | **Business pulse** | Revenue, Collected, Outstanding, Cash, Net P&L, today's activity | ✅ home |
| B | **Action queue (Approvals)** | Payments/discounts/POs/credit-notes awaiting owner | ✅ **DONE** — unified Approvals |
| C | **Money map** | Receivables + aging · Payables (vendor dues) · Cash & Bank | ⚠️ partial (outstanding, cash-flow) → add payables |
| D | **Sales & ops** | Orders by status, recent activity, top customers, rep activity | ✅ mostly (orders) → add rep/top-customer |
| E | **Reports (owner-grade)** | Sales, Outstanding, GST liability, P&L, Purchases | ✅ **DONE** — reports hub (GST-liability/P&L tiles still to add) |
| F | **Exceptions & compliance** | Overdue invoices, low stock, GST due date, AMC/warranty expiring | ⚠️ partial (alerts, overdue) → add GST/stock |
| G | **Ask AI + quick actions** | Ask-business; scan bill, record payment, new order | ✅ exists |

**Design principle:** one data-driven home engine keyed off `effectiveModules` + `normalizedRole` +
`tier`; render tiles/sections per module the user actually has — extends the billing-vs-service
adaptation in `dashboard_screen.dart`. Technician + operator are the two field personas that get a
dedicated non-dashboard home; all office/monitor roles share the dashboard engine.

## 7. What's still left (as of 2026-07-03)

### ✅ Shipped since 2026-07-01
- **Unified Approvals inbox** (payments + purchase-orders + orders; approve/reject with reason) — closes old **P0**.
- **Reports hub** over `/api/reports/*` (outstanding, overdue, sales-by-customer, …) — closes old **P0**.
- **`operator` role** (new) + **machinery field persona**: my-machines home, machine detail
  (meter/docs/jobs/logs), <30 s daily usage log, breakdown report with on-device **AI diagnosis**;
  supervisor **machine-transfer receive**; deep-link module gating fixed.
- **Site-logistics proof-photo**: camera/gallery capture on delivery **Confirm at site** + delivery/survey
  create forms (fixed a theme render bug where full-width `OutlinedButton`s in a `Row` painted nothing).
- **Service & Warranty** technician suite complete (My-Day, tickets, today, calendar, AMC contracts, reports).

### ▶ Still to build — prioritised
**P1 (next):**
1. **Customers create/edit** — currently list-only. Needed by sales_rep, admin, mgr.
2. **CRM / Leads / Quotations** — no mobile surface yet (module + web exist). sales_rep, admin, mgr.
3. **GST & Compliance** — returns / e-invoice / filing status. admin, accounts, accountant.
4. **Vendor payments / outstanding / credit notes** — have purchase create+list; add payables outstanding
   + vendor credit notes. admin, mgr, accounts.
5. **Inventory / stock view** — read-only stock levels (pickers exist, no browse). admin, mgr, site_admin.
6. **Unified Notification Inbox** — fold cross-module notifications into one inbox (alerts list exists).

**P2 (later):**
7. **Expenses / advances / petty cash** entry + approve. admin, mgr, accounts.
8. **GL / accounting read** — ledgers, trial balance, P&L, day-book (read-only). admin, accountant, accounts.
9. **Payroll / HR / ESS** — employee self-service (payslips, attendance, leave) — **employee persona is
   entirely absent** today; plus admin payroll approvals.
10. **Construction depth** — projects estimates/BOQ/DPR entry, tender workflow/approvals, correspondence
    compose (today: read-only lists + letters + machinery + site-logistics).

**Persona homes still generic** (land on `/dashboard` with correct module tabs, but no tailored cockpit):
manager, accounts, accountant, estimator, ho_user, dispatch. **employee** has no persona at all.

**Explicitly web-only** (not planned for mobile): bank recon, owner equity, fixed assets, year-end close,
admin setup / users / module toggles, bulk import, CA workspace, super-admin.
