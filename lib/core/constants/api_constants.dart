import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    // 1) compile-time override for local dev: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    // 2) .env (if bundled), else the deployed default
    try {
      final envUrl = dotenv.maybeGet('API_BASE_URL');
      return (envUrl != null && envUrl.isNotEmpty)
          ? envUrl
          : 'https://www.aadithsaibillingcloud.com';
    } catch (_) {
      return 'https://www.aadithsaibillingcloud.com';
    }
  }

  /// Public web-portal origin — used to build customer-facing links (e.g. the
  /// `/track/{token}` repair-tracking page, which lives on the web app, not the API).
  static String get webBaseUrl {
    const fromDefine = String.fromEnvironment('WEB_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    try {
      final envUrl = dotenv.maybeGet('WEB_BASE_URL');
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    } catch (_) {}
    return 'https://www.aadithsaibillingcloud.com';
  }

  // Auth
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';

  // Dashboard
  static const String dashboard = '/api/reports/dashboard';
  static const String dashboardEnhanced = '/api/reports/dashboard-enhanced';

  // Orders
  static const String orders = '/api/orders';
  static String orderDetail(String id) => '/api/orders/$id';

  // Invoices
  static const String invoices = '/api/invoices';
  static String invoiceDetail(String id) => '/api/invoices/$id';

  // Payments
  static const String payments = '/api/payments';

  // Vendor purchases (Admin/Owner — purchase entry on mobile)
  static const String vendorPurchases = '/api/vendor-purchases';
  static const String vendorPurchasePriceHint = '/api/vendor-purchases/price-hint';
  static String vendorPurchaseDetail(String id) => '/api/vendor-purchases/$id';
  static const String vendorPayments = '/api/vendor-payments';
  static const String vendorCreditNotes = '/api/vendor-credit-notes';
  static const String vendors = '/api/vendors';

  // AI scanner (multipart field 'file')
  static const String scanVendorBill = '/api/ai/scan-vendor-bill';
  static const String scanCreditNote = '/api/ai/scan-credit-note';

  // "Ask your business" AI assistant (owner/admin, paid add-on)
  static const String aiAssistantStatus = '/api/ai-assistant/status';
  static const String aiAssistantBrief = '/api/ai-assistant/brief';
  static const String aiAssistantAsk = '/api/ai-assistant/ask';
  static const String aiAssistantTranscribe = '/api/ai-assistant/transcribe';

  // Mobile home (role-aware overview: financials + activity feed)
  static const String mobileHome = '/api/reports/mobile-home';

  // Customer Outstanding / Receivables
  static const String customerOutstanding = '/api/reports/customer-outstanding';

  // Push notifications — device token registration (FCM) + per-type preferences
  static const String deviceRegister = '/api/devices/register';
  static const String deviceUnregister = '/api/devices/unregister';
  static const String devicePreferences = '/api/devices/preferences';

  // Command Center (ERP executive dashboard — same data as the web Command Center)
  static const String moneyBand = '/api/dashboard/money-band';
  static const String actionCenter = '/api/dashboard/action-center';
  static const String actionCenterMine = '/api/dashboard/action-center?mine=1';
  static const String myWork = '/api/dashboard/my-work';
  // Module summaries powering the Executive / Operations / Finance lenses
  static const String projectsSummary = '/api/projects/dashboard-summary';
  static const String machinerySummary = '/api/machinery/dashboard-summary';
  static const String tendersSummary = '/api/tenders/dashboard-summary';

  // Collections
  static const String collections = '/api/collections';
  static const String collectionReps = '/api/collections/collection-reps';
  static const String recordPayment = '/api/collections/payment';
  static String collectionStatementPdf(String customerId) => '/api/collections/customer-statement/$customerId/pdf';
  static String collectionStatementWhatsapp(String customerId) => '/api/collections/customer-statement/$customerId/whatsapp';
  static String collectionDetail(String id) => '/api/collections/$id';
  static String collectionPayment(String id) => '/api/collections/$id/payment';
  static String collectionCorrection(String id) =>
      '/api/collections/$id/correction';

  // Report print/share (server-rendered table PDF + WhatsApp)
  static const String reportRenderPdf = '/api/reports/render-pdf';
  static const String reportWhatsapp = '/api/reports/whatsapp';

  // Commissions
  static const String commissions = '/api/rep-commissions';
  static const String commissionSummary = '/api/rep-commissions/summary';

  // Alerts
  static const String alerts = '/api/alerts';
  static String markAlertRead(String id) => '/api/alerts/$id/read';

  // Approvals (owner action queue — cross-cutting approval requests)
  static const String approvalRequests = '/api/approvals/requests';
  static const String approvalSummary = '/api/approvals/summary';
  static String approvalRequest(String id) => '/api/approvals/requests/$id';
  static String approvalApprove(String id) => '/api/approvals/requests/$id/approve';
  static String approvalReject(String id) => '/api/approvals/requests/$id/reject';
  static String approvalHold(String id) => '/api/approvals/requests/$id/hold';
  static String approvalResume(String id) => '/api/approvals/requests/$id/resume';

  // Customers
  static const String customers = '/api/customers';
  static String customerDetail(String id) => '/api/customers/$id';

  // Products
  static const String products = '/api/products';

  // Projects (lite list — for Site-Logistics pickers)
  static const String projects = '/api/projects';
  // ERP module lists (read-only tabs)
  static const String machinery = '/api/machinery';
  static const String tenders = '/api/tenders';

  // ─── Machinery field persona (operator / site_admin) ───
  static String machineDetail(String id) => '/api/machinery/$id';
  static String machineLogs(String id) => '/api/machinery/$id/logs';
  static String machineLogUpdate(String logId) => '/api/machinery/logs/$logId';
  static String machineJobs(String id) => '/api/machinery/$id/jobs';
  static String machineJobUpdate(String jobId) => '/api/machinery/jobs/$jobId';
  static String machineJobApprove(String jobId) => '/api/machinery/jobs/$jobId/approve';
  static const String machineryAiDiagnose = '/api/machinery/ai-diagnose';
  static const String machineryTransfers = '/api/machinery/transfers';
  static String machineryTransferReceive(String id) => '/api/machinery/transfers/$id/receive';

  // ─── Service & Warranty (warranty_service module) ───
  // Tickets
  static const String serviceTickets = '/api/service-tickets';
  static String serviceTicket(String id) => '/api/service-tickets/$id';
  static String serviceTicketStatus(String id) => '/api/service-tickets/$id/status';
  static String serviceTicketAssign(String id) => '/api/service-tickets/$id/assign';
  static String serviceTicketParts(String id) => '/api/service-tickets/$id/parts';
  static String serviceTicketPart(String id, String partId) => '/api/service-tickets/$id/parts/$partId';
  static String serviceTicketPayment(String id) => '/api/service-tickets/$id/payment';
  static String serviceTicketEstimate(String id) => '/api/service-tickets/$id/estimate';
  static String serviceTicketEstimateApprove(String id) => '/api/service-tickets/$id/estimate/approve';
  static String serviceTicketEstimateReject(String id) => '/api/service-tickets/$id/estimate/reject';
  static String serviceTicketJobSheet(String id) => '/api/service-tickets/$id/job-sheet';
  static String serviceTicketReport(String id) => '/api/service-tickets/$id/report';
  static String serviceTicketShare(String id) => '/api/service-tickets/$id/share';
  static String serviceTicketInvoice(String id) => '/api/service-tickets/$id/invoice';
  static String serviceTicketAttachments(String id) => '/api/service-tickets/$id/attachments';
  // Items / warranty
  static const String serviceItems = '/api/service-items';
  static const String serviceItemLookup = '/api/service-items/lookup';
  static const String servicePartsCatalog = '/api/service-items/parts-catalog';
  static const String serviceTechnicians = '/api/service-tickets/technicians';
  static const String serviceAiTriage = '/api/service-tickets/ai-triage';
  static String serviceItem(String id) => '/api/service-items/$id';
  // AMC contracts
  static const String serviceContracts = '/api/service-contracts';
  static const String serviceDueVisits = '/api/service-contracts/due-visits';
  static String serviceContract(String id) => '/api/service-contracts/$id';
  static String serviceContractVisits(String id) => '/api/service-contracts/$id/visits';
  static String serviceContractVisit(String id, String visitId) => '/api/service-contracts/$id/visits/$visitId';
  static String serviceContractRenew(String id) => '/api/service-contracts/$id/renew';
  // Calendar (cross-module feed: AMC visits/renewals, invoice due, etc.)
  static const String calendar = '/api/calendar';
  static const String calendarReschedule = '/api/calendar/reschedule';
  // Reports
  static const String serviceDashboard = '/api/service-reports/dashboard';
  static const String serviceWarrantyRegister = '/api/service-reports/warranty-register';
  static const String serviceExpiring = '/api/service-reports/expiring';
  static const String serviceOpenAging = '/api/service-reports/open-tickets-aging';
  static const String serviceTechProductivity = '/api/service-reports/technician-productivity';
  static const String serviceRevenue = '/api/service-reports/service-revenue';
  static const String servicePartsUsage = '/api/service-reports/parts-usage';

  // ─── Correspondence (Letters) ───
  static const String letters = '/api/correspondence/letters';
  static const String lettersDue = '/api/correspondence/letters/due';
  static const String correspondenceSummary = '/api/correspondence/dashboard-summary';
  static String letter(String id) => '/api/correspondence/letters/$id';
  static String letterStatus(String id) => '/api/correspondence/letters/$id/status';
  static String letterApprove(String id) => '/api/correspondence/letters/$id/approve';

  // ─── Dispatch (dispatch persona) ───
  static const String dispatch = '/api/dispatch';
  static String dispatchDelivered(String id) => '/api/dispatch/$id/delivered';

  // ─── Shared Back-Office Spine (finance persona: admin/manager/accounts/accountant) ───
  static const String gstSummary = '/api/gst/summary';
  static const String vendorOutstanding = '/api/vendor-reports/outstanding';
  static const String officeExpenses = '/api/office-expenses';
  static const String officeExpenseCategories = '/api/office-expenses/categories';
  static const String advanceFloats = '/api/advance-floats';
  static String advanceFloatClose(String id) => '/api/advance-floats/$id/close';
  static const String inventoryStockValuation = '/api/inventory-reports/stock-valuation';
  static const String inventoryStockSummary = '/api/inventory-reports/stock-summary';
  // Inventory depth (read + transfer receive)
  static const String inventoryItems = '/api/inventory-items';
  static const String inventoryLocations = '/api/inventory-locations';
  static const String inventoryTransfers = '/api/inventory-transfers';
  static String inventoryTransferReceive(String id) => '/api/inventory-transfers/$id/receive';
  static const String inventoryTransactions = '/api/inventory-transactions';
  // GL (read-only on mobile)
  static const String glAccounts = '/api/gl/accounts';
  static const String glTrialBalance = '/api/gl/trial-balance';
  static const String glProfitLoss = '/api/gl/profit-loss';
  static const String glBalanceSheet = '/api/gl/balance-sheet';
  static const String glDayBook = '/api/gl/day-book';
  // Payroll (view / approve)
  static const String payrollRuns = '/api/payroll/runs';
  static const String payrollAdvances = '/api/payroll/advances';
  // ESS (employee self-service)
  static const String essPayslips = '/api/ess/payslips';
  static const String essLeaveBalance = '/api/ess/leave-balance';
  static const String essLeave = '/api/ess/leave';

  // Site Logistics
  static const String siteSurveys = '/api/project-sites/surveys';
  static String siteSurveySubmit(String id) => '/api/project-sites/surveys/$id/submit';
  static String siteSurveyApprove(String id) => '/api/project-sites/surveys/$id/approve';
  static const String siteDeliveries = '/api/project-sites/deliveries';
  static String siteDeliveryConfirm(String id) => '/api/project-sites/deliveries/$id/confirm';
  static const String siteUpload = '/api/project-sites/upload';
}
