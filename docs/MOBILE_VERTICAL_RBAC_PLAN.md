# Mobile — 3-Vertical RBAC Plan & Shared-Spine Strategy

_Companion to `MOBILE_ERP_RBAC_GAP_ANALYSIS.md`. Written 2026-07-03._
_Answers: the P1/P2 back-office features are common to Billing/Trading, Service and Construction —
so who owns those screens, and do we build them once or three times?_

## 0. TL;DR
- **A vertical is a company-level module bundle, NOT a role.** `effectiveModules = role.modules ∩
  company.enabledModules` (already in the login payload). The "3 worlds" only decide which *operational*
  modules a company turns on.
- **The shared back-office ("spine") is owned by the same roles in every vertical** — `admin` (inherits
  all), `manager`, `accounts`, `accountant`. We build each spine screen **once**, gate it by module∩role,
  and it serves Trading, Service and Construction companies identically.
- **Highest-leverage next build = the Shared Spine** (Phase 1). One build unlocks the `accounts` and
  `accountant` personas (today both fall through to the generic dashboard) *and* completes the
  admin/manager cockpit — across all three verticals at once. Detailed build + E2E plan:
  `SHARED_SPINE_BUILD_PLAN.md`.

## 1. Grid A — Module → Vertical (shared vs vertical-specific)
| Layer | Modules | In which vertical |
|---|---|---|
| **SHARED SPINE** (back-office + finance) | customers, invoices, payments, collections, outstanding, vendor_purchases, gst, gst_filing_assistant, finance_accounts, finance_gl, payroll, reports, alerts, inventory (+products), crm, settings, bulk_upload, business_trace, invoice_scanner, year_close_assistant | **All 3** |
| **TRADING pack** | orders, production, packing, dispatch, transports, custom_misc, representatives, sales_intelligence, inventory_intelligence | Trading |
| **SERVICE pack** | warranty_service (tickets, AMC, warranty) | Service |
| **CONSTRUCTION pack** | projects, machinery, tender, correspondence | Construction |

The P1/P2 "common" items — customers, GST, payables, inventory, expenses, GL, payroll — are **all in the
SHARED SPINE**; that is exactly why they felt common. (CRM = spine-sales; construction depth = the
Construction pack.)

## 2. Grid B — Shared-spine feature → owning role (vertical-agnostic)
● = create/act · ○ = view/approve · blank = not applicable. Same in Trading, Service *and* Construction
companies — only the *data scope* narrows for site/HO roles.

| Shared feature | Module | admin | manager | accounts | accountant | sales_rep | site_admin | ho_user | employee |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Customers CRUD | customers | ● | ● | ○ | | ● | | ○ | |
| GST & compliance | gst / gst_compliance | ● | ○ | ● | ● | | | | |
| Payables / outstanding / credit notes | vendor_purchases, outstanding | ● | ● | ● | ○ | | ○ | ○ | |
| Inventory view | inventory | ○ | ○ | | | ○ | ○ | ○ | |
| Expenses / advances / petty cash | finance_accounts (office-expenses) | ● | ● | ● | ○ | | ○ | | |
| GL read (ledger/TB/P&L/day-book) | finance_gl (gl) | ○ | ○ | ● | ● | | | | |
| Payroll (approve) | payroll | ○ | ○ | ● | | | ○ | | |
| ESS (self: payslips/attendance/leave) | ess | | | | | | | | ● |

**Primary owner of the spine = the finance/office cluster: admin + manager + accounts + accountant.**
Build the spine once → the `accounts` and `accountant` personas come alive for every vertical
simultaneously; `admin`/`manager` cockpits get their missing tiles.

## 3. The configuration model (how it's wired — no per-vertical code)
```
Company (vertical) = enabled module bundle              ← configured per company
        │
        ▼
effectiveModules = role.modules ∩ company.modules       ← already in session payload
   (admin/manager/ca inherit ALL company modules; super bypasses)
        │
        ▼
ONE data-driven home engine renders, per user:
   SHARED SPINE tiles     → admin / manager / accounts / accountant
 + VERTICAL PACK tiles     → orders | tickets | projects — whichever modules are on
 + PERSONA HOME            → rep / technician / operator get a bespoke landing
```
There are **no `if (vertical == …)` branches** in the app. The module set *is* the vertical. A Service
company that also enabled billing+GST shows its `accounts` user the identical GST screen a Trading
company's `accounts` user sees. Two gates always apply: **company enabled it** AND **role includes it**
(`route_guards.dart` mirrors this client-side).

## 4. Phased roadmap
| Phase | Scope | Unlocks | Status |
|---|---|---|---|
| **1 — Shared Spine** | customers CRUD, GST, payables/credit-notes, inventory view, expenses, GL read, payroll; finance persona home | `accounts` + `accountant` personas + admin/manager cockpit, **for all 3 verticals** | **NEXT** → `SHARED_SPINE_BUILD_PLAN.md` |
| **2 — Vertical operational packs** | Trading: dispatch queue · Service: service-manager view · Construction: estimator/site_admin projects+tender depth | remaining field/ops personas | rep ✅ technician ✅ operator ✅; rest pending |
| **3 — Cross-cutting** | unified Notification Inbox (all) · CRM/Quotations (sales) · ESS → new `employee` persona | inbox, sales funnel, ESS | pending |

**Why Phase 1 first:** every vertical has finance, so one spine build lights up the most roles across the
most companies. Phases 2–3 are additive packs on the same data-driven engine.
