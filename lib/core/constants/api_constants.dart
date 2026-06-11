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
  static String vendorPurchaseDetail(String id) => '/api/vendor-purchases/$id';
  static const String vendorPayments = '/api/vendor-payments';
  static const String vendorCreditNotes = '/api/vendor-credit-notes';
  static const String vendors = '/api/vendors';

  // AI scanner (multipart field 'file')
  static const String scanVendorBill = '/api/ai/scan-vendor-bill';
  static const String scanCreditNote = '/api/ai/scan-credit-note';

  // "Ask your business" AI assistant (owner/admin, paid add-on)
  static const String aiAssistantStatus = '/api/ai-assistant/status';
  static const String aiAssistantAsk = '/api/ai-assistant/ask';
  static const String aiAssistantTranscribe = '/api/ai-assistant/transcribe';

  // Mobile home (role-aware overview: financials + activity feed)
  static const String mobileHome = '/api/reports/mobile-home';

  // Collections
  static const String collections = '/api/collections';
  static String collectionDetail(String id) => '/api/collections/$id';
  static String collectionPayment(String id) => '/api/collections/$id/payment';
  static String collectionCorrection(String id) =>
      '/api/collections/$id/correction';

  // Commissions
  static const String commissions = '/api/rep-commissions';
  static const String commissionSummary = '/api/rep-commissions/summary';

  // Alerts
  static const String alerts = '/api/alerts';
  static String markAlertRead(String id) => '/api/alerts/$id/read';

  // Customers
  static const String customers = '/api/customers';
  static String customerDetail(String id) => '/api/customers/$id';

  // Products
  static const String products = '/api/products';

  // Projects (lite list — for Site-Logistics pickers)
  static const String projects = '/api/projects';

  // Site Logistics
  static const String siteSurveys = '/api/project-sites/surveys';
  static String siteSurveySubmit(String id) => '/api/project-sites/surveys/$id/submit';
  static String siteSurveyApprove(String id) => '/api/project-sites/surveys/$id/approve';
  static const String siteDeliveries = '/api/project-sites/deliveries';
  static String siteDeliveryConfirm(String id) => '/api/project-sites/deliveries/$id/confirm';
  static const String siteUpload = '/api/project-sites/upload';
}
