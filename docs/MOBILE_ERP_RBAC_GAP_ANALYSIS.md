# Mobile ERP — RBAC Gap Analysis & Role→Module Map

_Authoritative reference for building out the Aadith Sai Business Cloud mobile app (Flutter) toward
the full web ERP. Generated 2026-07-01 from a three-way audit of the backend RBAC, the web frontend,
and the current mobile app._

## 1. The shape of the gap
- **Web** = full ERP: ~145 routes / ~130 pages across **24 functional areas** in 3 "worlds"
  (Trading, Service, Construction) + shared billing/back-office/finance.
- **Mobile** = ~8 areas, branches for only **4 personas** (admin, sales_rep, collection_rep,
  technician). Everyone else (manager, accounts, accountant, estimator, site_admin, ho_user,
  dispatch, employee/ESS) falls through to the generic admin home.
- **Key enabler:** the login/session payload already carries **`effectiveModules`** (role modules ∩
  company enabled modules), **`normalizedRole`**, **`tier`**, **`appAccess`**, and a
  `{view,create,approve,post}` capability grid. The mobile home can be **fully data-driven** — no new
  backend RBAC needed; we consume what's there (`auth.js` sets `req.user.effectiveModules` etc.).

## 2. Roles (backend `config/roleAccess.js`)
18 roles. Mobile-relevant ones bolded.
- **super_admin / super_user** — platform god mode; bypass module + company scope (web-only).
- **admin** — company owner; inherits ALL enabled company modules; only role for company config.
- **manager** — broad ops + finance manager (fixed wide module list; a POST role).
- **sales_rep** — field sales; customers/products/orders/custom_misc/invoices/reports/crm.
- **collection_rep** — field collections; collections/outstanding/payments/invoices/customers.
- **accounts** — clerk; invoices/payments/collections/gst/vendor_purchases/payroll/finance; POSTs to GL.
- **accountant** — GL-focused; finance_gl/finance_accounts/reports/invoices/payments/vendor_purchases; POSTs.
- **technician** — warranty_service only; `assignedTo=me`; AI off by default. (mobile: done)
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
limited to admin/accounts/accountant/manager/super.

## 4. Web area → mobile status & priority
Priority = belongs on a phone (field / monitor / approve), not heavy back-office (stays web).

| Web area | Mobile today | Who needs it | Priority |
|---|---|---|---|
| Dashboard/Home, Orders, Invoices, Payments, Collections, Vendor Purchases (+scan), Service, AI, Alerts | ✅ | per role | done |
| **Approvals inbox** (cross-cutting) | ⚠️ only Payments-pending | admin, mgr, ho_user, accounts | **P0** |
| **Reports** (billing) | ❌ stubbed | admin, mgr, accounts | **P0** |
| **Customers** create/edit | ⚠️ list only | admin, mgr, sales_rep | **P1** |
| **CRM / Leads / Quotations** | ❌ | sales_rep, admin, mgr | **P1** |
| **GST & Compliance** (returns/e-invoice/filing) | ❌ | admin, accounts, accountant | **P1** |
| **Vendor payments / outstanding / credit notes** | ⚠️ endpoints only | admin, mgr, accounts | **P1** |
| **Inventory / stock** view | ❌ pickers only | admin, mgr, site_admin | **P1** |
| **Notification Inbox** (unified) | ⚠️ simple alerts | all | **P1** |
| **Expenses / advances / petty cash** | ❌ | admin, mgr, accounts | **P2** |
| **GL / accounting** read (ledgers/TB/P&L/day-book) | ❌ | admin, accountant, accounts | **P2 read-only** |
| **Payroll / HR / ESS** | ❌ | admin(approve), employee | **P2** |
| **Construction** (projects/machinery/tender/correspondence) | ⚠️ site-logistics stub | estimator, site_admin, ho_user | **P2** |
| Bank recon / Owner equity / Fixed assets / Year-end / Admin setup / Users / Module toggles / Bulk import / CA / Super-admin | ❌ | admin/ca/super | **Web-only** |

## 5. Role → modules needed on mobile (bold = current gap)
| Role | appAccess | Modules on mobile | Persona home today |
|---|---|---|---|
| owner/admin | ✅ | orders, invoices, payments, collections, vendor_purchases, **approvals**, **reports**, **inventory(view)**, **gst(status)**, **crm**, warranty_service, alerts, ai, **finance_gl(read)** | ✅ generic |
| manager | ✅ | ~admin minus company-config | ❌→admin |
| sales_rep | ✅ | orders, customers(**CRUD**), products(view), custom_misc, invoices(view), **crm/quotations**, reports, commissions | ✅ rep |
| collection_rep | ✅ | collections, payments, invoices, customers(view), **outstanding** | ✅ rep |
| accounts | ✅ | invoices, payments, collections, **outstanding**, **gst**, vendor_purchases, **gst_filing_assistant**, **approvals**, **finance_accounts** | ❌→admin |
| accountant | ✅ | **finance_gl(read)**, **finance_accounts**, reports, invoices, payments, vendor_purchases, **approvals** | ❌→admin |
| technician | ✅ | warranty_service | ✅ done |
| estimator | ✅ | **projects/estimates**, customers, alerts | ❌→admin |
| site_admin | ✅ | orders, **inventory**, vendor_purchases, dispatch, **machinery**, **projects**, payroll(view); site-scoped L1 approve | ❌→admin |
| ho_user | ✅ | broad **view + approvals** across sites | ❌→admin |
| dispatch | ✅ | **dispatch queue**, transports, orders, invoices | ❌→admin |
| employee | ✅ | **ess: payslips, attendance, leave** | ❌ absent |
| production/packing | ❌ | — (no app login) | excluded |
| ca | web | read-only auditor | web-only |

## 6. Company Owner (admin) — mobile requirements ("owner cockpit")
The owner uses mobile to **monitor, approve, and spot-check** — not for data entry. Priority build
order for the admin persona:

| # | Owner need | What it shows | Mobile status |
|---|---|---|---|
| A | **Business pulse** | Revenue, Collected, Outstanding, Cash, Net P&L, today's activity | ✅ exists (home) |
| B | **Action queue (Approvals)** | Payments/discounts/POs/credit-notes awaiting owner | ⚠️ only payment-pending → **build unified Approvals** |
| C | **Money map** | Receivables + aging · Payables (vendor dues) · Cash & Bank | ⚠️ partial (outstanding, cash-flow) → add payables |
| D | **Sales & ops** | Orders by status, recent activity, top customers, rep activity | ✅ mostly (orders) → add rep/top-customer |
| E | **Reports (owner-grade)** | Sales, Outstanding, GST liability, P&L, Purchases | ❌ **stubbed → build** |
| F | **Exceptions & compliance** | Overdue invoices, low stock, GST due date, AMC/warranty expiring | ⚠️ partial (alerts) → add GST/stock |
| G | **Ask AI + quick actions** | Ask-business; scan bill, record payment, new order | ✅ exists |

**Design principle:** one data-driven home engine keyed off `effectiveModules` + `normalizedRole` +
`tier`; render tiles/sections per module the user actually has — extends the billing-vs-service
adaptation already in `dashboard_screen.dart`. Owner (admin) = superset (inherits all company modules),
so the admin home is the natural first full build; other personas are subsets of the same engine.
