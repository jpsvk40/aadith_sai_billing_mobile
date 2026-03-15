import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    final envUrl = dotenv.maybeGet('API_BASE_URL');
    return (envUrl != null && envUrl.isNotEmpty)
        ? envUrl
        : 'https://aadith-sai-billing-cloud-4g5n.onrender.com';
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
}
