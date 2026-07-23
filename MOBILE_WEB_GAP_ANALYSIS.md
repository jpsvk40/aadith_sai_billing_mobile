# Mobile ⇄ Web — Gap Analysis & Implementation Plan

**App:** `aadith_sai_billing_mobile` (Flutter) vs the web ERP `Aadith-Sai-Cloud-Billing/frontend` · **Date:** 2026-07-22

Purpose: a complete map of what the **web** ERP does vs what the **mobile** app does today, the missing pieces on mobile, and a prioritized plan — so we can decide what to build.

## How to read this

**Status** — 🟢 Full (create/edit/workflow on mobile) · 🟡 Partial (view-only, or a subset) · 🔴 Missing (no mobile screen).

**Who gets it (RBAC)** — every option is governed by **company enabled modules ∩ the role's default module access** (`backend/src/config/roleAccess.js` `ROLE_DEFAULTS`; mirrored on mobile via `AuthUser.effectiveModules` + `route_guards.requiredModuleForLocation`). Role shorthand used below and in the matrix artifact:

| Tag | Role | Default access (highlights) |
|---|---|---|
| **Own** | Owner / Admin | **everything the company enables** (inherits all modules) |
| **Mgr** | Manager | ops + finance + AI advisors (customers, inventory, orders, invoices, payments, collections, vendor, payroll, service, projects, machinery, tender, GL, trace, advisors) |
| **Acc** | Accounts / Accountant | invoices, payments, collections, outstanding, GST, vendor_purchases, GL, invoice_scanner, gst_filing/year_close assistant |
| **Sales** | Sales rep | customers, products, orders, invoices, CRM, business_trace |
| **Coll** | Collection rep | collections, outstanding, payments, invoices, customers |
| **Disp** | Dispatch | dispatch, transports, orders, invoices |
| **Tech** | Technician | warranty_service only |
| **Op** | Machine operator | machinery, alerts (view+create, commercial fields hidden) |
| **Est** | Estimator | projects, customers, alerts |
| **Godown / Retail / Mill** | Garments/retail personas | inventory/stocktake · POS/loyalty · production (garments-edition only) |
| **Emp** | Employee | ESS self-service only (no modules) |
| **CA** | External auditor | view-only over the client company's books |
| **Super** | Super-admin | platform/tenant administration |

> Tier/verb nuance: `ho_user` & `site_admin` get broad **view/approve** but never **post to GL**; `ca` is view-only; `canBill` (record payment / pricing) = Owner + Accounts. New mobile features inherit the **same module gate as the web**, so "who gets the option" is automatic — no new RBAC needed unless we split a new module key.

**Mobile fit** — how much this belongs on a phone:
- **P1 — field-critical**: someone genuinely needs this on the go (approvals, quick create, lookups, collections, service).
- **P2 — useful on mobile**: nice to have mobile, but desktop is the primary home.
- **P3 — desktop-appropriate**: dense editors, bulk import/export, config, multi-column reconciliation — leave on web unless there's a specific ask.

> **Bottom line:** The mobile app already covers the **field-ops + core billing** surface well (orders, invoices, customers, purchases + AI scan, payments, collections/receivables, service & warranty at full parity, read-only GL/GST/inventory, machinery/projects/tenders field screens, AI assistant). The gaps cluster in **back-office write paths** (GL vouchers, GST filing, banking/recon), **masters/config** (products, pricing, vendors, users/RBAC, settings), and a few **field-worthy creates** that are currently missing (quotations, vendor payments, credit notes, stock adjustments).

---

## 0. Also in this pass — Purchase AI scanner fix (the reported bug)

**Symptom:** the mobile Purchase AI scanner didn't show line items like the web UI. **Root cause (most likely):** the mobile downscaled/compressed the photo before upload (`imageQuality: 85, maxWidth: 2400`) while the web uploads the full-resolution file — degrading the dense line-items table so the vision model read the header/totals but dropped item rows. **Fix applied** (`lib/features/purchases/purchase_bill_scan.dart`): raised to `imageQuality: 95, maxWidth: 4000` (backend allows 10 MB). Parsing (`ScannedBill`/`ScannedItem.fromJson` → `json['items']`) and rendering (`purchase_create_screen.dart` line cards) were verified equivalent to the web. *Couldn't be reproduced locally (repo sample images aren't clean vendor bills; `muthu.etraj@gmail.com` is a prod-only account) — verify with a real bill on that account. If items still drop, the fallback fix is a scanned-items review sheet + prominent per-line description (see F below).*

---

## 1. Domain-by-domain gap

### A. Sales — Orders, Invoices, POS
| Web capability | Mobile | Fit |
|---|---|---|
| Orders list / create / edit / detail | 🟢 Full | P1 |
| Invoices list / detail (view + share PDF) | 🟡 View/share only | P1 |
| **e-Invoice (IRN) + e-Way bill generation** | 🔴 Missing | P2 |
| **Customer credit note creation** | 🔴 (read-only in reports) | P2 |
| Production queue / Packing queue | 🔴 Missing (Dispatch exists) | P3 |
| Custom/Misc (non-catalog) orders | 🔴 Missing | P3 |
| Sample delivery notes | 🔴 Missing | P3 |
| **POS terminal** (counter billing) | 🔴 Missing | P2 (retail cos) |
| Promotions / Loyalty | 🔴 Missing | P3 |

### B. Customers / CRM
| Web capability | Mobile | Fit |
|---|---|---|
| Customer master list / create / edit | 🟢 Full | P1 |
| **CRM Leads pipeline** | 🔴 Missing | P2 |
| **Quotations** (create → convert) | 🔴 Missing | **P1** |
| Customer special pricing | 🔴 Missing | P3 |
| Customer credit notes | 🔴 Missing | P2 |
| Calendar / activities | 🔴 Missing | P2 |
| Notification inbox | 🟡 Alerts feed exists | P2 |

### C. Purchases / Vendors / Procurement
| Web capability | Mobile | Fit |
|---|---|---|
| Purchase bill list / create / detail | 🟢 Full | P1 |
| **AI bill scanner** (prefill) | 🟢 Full *(scanner fix above)* | P1 |
| Payables / vendor dues | 🟡 View-only | P1 |
| **Vendor master create/edit** | 🟡 create-on-scan only; no standalone CRUD | P2 |
| **Vendor payments** (record / list) | 🔴 Missing | **P1** |
| Vendor bulk payment | 🔴 Missing | P3 |
| Vendor outstanding / ageing report | 🟡 via reports | P2 |
| Vendor credit / debit notes | 🔴 Missing | P2 |
| Procurement: requisitions / RFQ / PO | 🔴 Missing | P2 |
| Purchase↔Tally reconciliation | 🔴 Missing | P3 |
| Office expenses / advance floats | 🟢 Full | P1 |

### D. Inventory · Catalog · Pricing
| Web capability | Mobile | Fit |
|---|---|---|
| Stock report / valuation / items / locations / transfers / movements | 🟡 View (transfers create?) | P2 |
| **Stock entries / adjustments (create)** | 🔴 Missing | **P1** |
| Stock-take / replenishment | 🔴 Missing | P2 (barcode-friendly) |
| **Product master create/edit** | 🔴 Missing (items browse-only) | P2 |
| Item matrix / matrix catalog | 🔴 Missing | P3 |
| Price lists / price tiers / trade schemes / weight pricing | 🔴 Missing | P3 |
| SKU / barcode labels | 🔴 Missing | P3 |
| Departments master | 🔴 Missing | P3 |

### E. Collections / Receivables
| Web capability | Mobile | Fit |
|---|---|---|
| Receivables hub / outstanding / statement | 🟢 Full | P1 |
| Collections book / detail / capture payment | 🟢 Full | P1 |
| Rep commission | 🟢 Full | P1 |
| Customer-outstanding print + **bulk receipt** | 🟡 statement only; no bulk receipt | P2 |

### F. Payments
| Web capability | Mobile | Fit |
|---|---|---|
| Record payment against invoice | 🟢 Full | P1 |
| Payment-gateway/account settings | 🔴 Missing | P3 |
| Printable receipt voucher | 🟡 partial | P2 |

### G. Finance / General Ledger  *(mobile is intentionally read-only today)*
| Web capability | Mobile | Fit |
|---|---|---|
| Trial Balance / P&L / Balance Sheet / Day Book | 🟡 View-only | P2 |
| **Voucher / journal entry** | 🔴 Missing | P3 (accountant desktop) |
| Chart of accounts, ledger statement, books-health | 🔴 Missing | P3 |
| GL insights (AI), daily brief | 🔴 Missing | P2 (AI, mobile-friendly) |
| Branch P&L, project P&L, budget, cash forecast | 🔴 Missing | P2 (dashboards) |
| Instruments (BG/FD/LC), fixed assets, advances | 🔴 (advances exists) | P3 |
| Year-end close, opening balances, stock-val close, financial years | 🔴 Missing | P3 |

### H. GST & Compliance
| Web capability | Mobile | Fit |
|---|---|---|
| GST liability summary | 🟡 View-only | P2 |
| GSTR review / Tally review / B2CS / GST bills | 🔴 Missing | P3 |
| e-Invoice / e-Way credentials + generation | 🔴 Missing | P2 |
| **AI GST filing assistant (2B recon / ITC)** | 🔴 Missing | P2 |

### H2. Banking / Reconciliation
| Web capability | Mobile | Fit |
|---|---|---|
| Bank Reconciliation 2.0 (import + match) | 🔴 Missing | P3 |
| Scanned-dispatch recon, Tally daybook import | 🔴 Missing | P3 |

### I. AI Tools & Advisors
| Web capability | Mobile | Fit |
|---|---|---|
| Ask-your-business assistant (text + voice) | 🟢 Full | P1 |
| Vendor-bill / credit-note scanner | 🟢 Full | P1 |
| Service AI triage | 🟢 Full | P1 |
| **Business Trace / Customer Trace** | 🟡 partly via assistant | P2 |
| Sales advisor / Inventory advisor | 🔴 Missing | P2 |
| Sales invoice scanner (OCR) | 🔴 Missing | P2 |
| Year-close assistant, GL insights, daily brief, AI-tools summary | 🔴 Missing | P2 |
| AI usage / consent governance (admin) | 🟡 consent gate exists | P3 |

### J. Service & Warranty — **🟢 FULL PARITY** (tickets, items, AMC, reports, RMA, rework, customer history, AI triage). *No gap.*

### K. HR / Payroll
| Web capability | Mobile | Fit |
|---|---|---|
| ESS (payslips, leave requests) | 🟡 ESS home exists | P1 |
| Payroll run view / run detail | 🟡 View-only | P2 |
| Payroll processing (run/approve), HR masters, leave admin, employee records | 🔴 Missing | P3 |

### L. Field verticals (Construction / Plant)
| Web capability | Mobile | Fit |
|---|---|---|
| Dispatch queue | 🟢 Full | P1 |
| Machinery: list / detail / log / breakdown / operator home | 🟢 Field ops | P1 |
| Machinery: add-edit, logbook, hire, transfers, depreciation, reports | 🔴 Missing | P2 |
| Projects: list / detail / site survey / delivery | 🟢 Field ops | P1 |
| Projects: create/edit, **estimate/BOQ editor**, catalog systems | 🔴 Missing | P2 |
| Tenders: list / detail | 🟢 View | P2 |
| Tenders: create/edit, instruments (EMD/BG), reports, dossier | 🔴 Missing | P3 |
| Correspondence: letters list / detail | 🟢 View | P2 |
| Correspondence: legal case detail | 🔴 Missing | P3 |
| Transport master | 🔴 Missing | P3 |

### M. Manufacturing / Production — 🔴 **entirely absent** (mill orders, job-work, style-BOM, piece-rate). Fit: **P3** (shop-floor/desktop), except a possible job-work status lookup (P2).

### N. Admin · Settings · Masters · Multi-entity
| Web capability | Mobile | Fit |
|---|---|---|
| Approvals inbox | 🟢 Full | P1 |
| Approval rules config | 🔴 Missing | P3 |
| Legal entities (multi-GSTIN) | 🔴 Missing | P3 |
| **User / role / RBAC administration** | 🔴 Missing | P2 |
| User activity / audit logs | 🔴 Missing | P3 |
| Company settings (huge multi-tab) | 🔴 Missing (only push prefs) | P3 |
| Company modules toggle | 🔴 Missing | P3 |
| Representatives / sites masters | 🔴 Missing | P2/P3 |
| Bulk upload, duplicate-merge / name hygiene, backup, training, financial years | 🔴 Missing | P3 |
| CA review workspace / access | 🔴 Missing | P3 |
| WhatsApp own-number / inbox | 🔴 Missing | P2 |
| Super-admin platform (tenants) | 🔴 Missing | P3 |

---

## 2. The mobile-worthy gaps (what actually deserves building)

Filtering out the P3 desktop/back-office items, the **field- and owner-critical gaps** are:

**Tier 1 — highest value on a phone (P1):**
1. **Quotations** — create a quote on-site and convert to an order/invoice. (CRM leads can ride alongside.)
2. **Vendor payments** — record a payment to a vendor / pay a bill (payables is view-only today).
3. **Stock adjustments / entries** — quick stock in/out/adjust from the warehouse floor.
4. **Invoice actions parity** — from an invoice: record payment (have it), plus **e-invoice / e-way generate** and **credit note** where enabled.

**Tier 2 — useful mobile (P2):**
5. **Customer & vendor credit/debit notes** (create).
6. **Business Trace / Customer Trace** as a first-class screen (owner insight on the go) + **Sales/Inventory advisors**.
7. **Bulk receipt** on the receivables statement (collect one lump sum across a customer's bills).
8. **Product master create/edit** + **stock-take (barcode)** for retail/inventory cos.
9. **GST filing assistant / e-invoice** surface for owners who file on mobile.
10. **User/RBAC lite** (invite a user, toggle role/modules) for owners.
11. **Machinery/Projects/Tenders create+edit** to complete those field verticals (currently view/log only).

**Tier 3 — leave on web** (dense editors, bulk import, GL vouchers, reconciliation, full settings, manufacturing, super-admin) unless a specific customer asks.

---

## 3. Implementation plan (phased)

Each item follows the established mobile pattern: `api_constants` endpoint → `*_repository` method → model DTO (tolerant `fromJson`) → Riverpod provider → screen/sheet → `GoRoute` (module-gated under the right prefix) → entry point on the relevant hub/list. Backend endpoints already exist for almost all of these (same server the web uses) — mobile work is Dart UI + repo wiring.

### Phase 1 — Field-critical creates (≈1.5–2 wks)
- **Quotations** — `quotations` list + create screen (line items reuse the order/purchase line widgets), convert-to-order action. Gate `crm`. *(largest item)*
- **Vendor payments** — "Pay" action on Payables + a record-vendor-payment sheet; vendor-payment list. Gate `vendor_purchases`.
- **Stock adjustment** — a create sheet on the Inventory hub (item, location, qty in/out, reason). Gate `inventory`.
- **Invoice → e-invoice / e-way / credit note** buttons on `InvoiceDetailScreen` (call existing endpoints; show status). Gate as per company.
- Ship the **scanner fix** (done) + optional scanned-items review sheet.

### Phase 2 — Owner insight + masters (≈2–3 wks)
- **Business Trace / Customer Trace** screen (reuse the web `/business-trace/customer/:id` payload — mobile already renders similar tiles in the new Customer Service History).
- **Sales advisor / Inventory advisor** read screens (AI recommendations).
- **Bulk receipt** on the receivables statement.
- **Credit notes** (customer + vendor) create.
- **Product master** create/edit + **stock-take** (camera/barcode) screen.
- **Machinery / Projects / Tenders**: add the missing create/edit forms so those verticals are self-sufficient on mobile.

### Phase 3 — Compliance & admin-lite (as demanded)
- **GST filing assistant / e-invoice** mobile surface.
- **User/RBAC-lite** (invite, role, module toggle) for owners.
- **Representatives / sites** masters, **WhatsApp inbox**.
- Read dashboards for **branch/project P&L, budget, cash forecast, GL insights, daily brief**.

### Explicitly NOT planned for mobile (web-only by design)
GL voucher/journal entry, chart of accounts, bank reconciliation, Tally imports, year-end/opening-balance/period-close, manufacturing (mill/jobwork/BOM/piece-rate), full company settings, bulk upload, duplicate-merge, backup, audit logs, super-admin platform, CA workspace, item-matrix/price-tier/scheme editors, SKU label batch printing. These are dense desktop workflows; surface **read-only summaries or approvals** on mobile instead where useful.

---

## 4. Decision points for you
1. **Confirm Tier-1 scope** (Quotations, Vendor payments, Stock adjust, Invoice e-invoice/e-way/credit-note) as Phase 1 — or reprioritize.
2. **POS on mobile?** Only worth it for retail/counter customers — is that a target segment?
3. **How far into masters/config** should mobile go (product master, users/RBAC, settings)? This is the biggest "how much is a phone an admin tool" question.
4. **Verify the scanner fix** on `muthu.etraj@gmail.com` with a real bill; if line items still drop, I'll add the scanned-items review sheet as the fallback.
