// Tier-2 parity smoke test — boots the real app against the LOCAL backend, logs in
// as the Mobile Parity QA admin (company 16 has every Tier-2 module enabled), and
// deep-links to each new screen to confirm it renders (routing + module gate + providers).
//
//   adb -s emulator-5554 shell pm grant com.aadithsai.aadith_sai_billing_mobile android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/tier2_parity_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3001
//
// Seed first: node --experimental-require-module backend/scripts/seed-mobile-parity.cjs
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'service_e2e_helpers.dart';

const qaEmail = 'mobileqa@example.com';

Future<void> goTo(WidgetTester tester, String location) async {
  final ctx = tester.element(find.byType(BottomNavigationBar).first);
  ctx.go(location);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Navigate to [route] and assert its AppBar [title] appears (proves the route
/// resolved past the module gate and the screen mounted without throwing).
Future<void> expectScreen(WidgetTester tester, String route, String title) async {
  await goTo(tester, route);
  final ok = await pumpUntilFound(tester, find.text(title), timeout: const Duration(seconds: 25));
  expect(ok, true, reason: 'Screen "$title" ($route) did not render');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tier 2 parity — all new screens render', (tester) async {
    await launchAndLogin(tester, qaEmail);

    // Credit notes (customer → invoices, vendor → vendor_purchases)
    await expectScreen(tester, '/credit-notes', 'Credit Notes');
    await expectScreen(tester, '/credit-notes/create', 'New Credit Note');
    await expectScreen(tester, '/vendor-credit-notes', 'Vendor Credit Notes');

    // Machinery / Projects / Tenders create (gate machinery/projects/tender)
    await expectScreen(tester, '/machinery/create', 'New Machine');
    await expectScreen(tester, '/projects/create', 'New Project');
    await expectScreen(tester, '/tenders/create', 'New Tender');

    // User / RBAC-lite (admin only)
    await expectScreen(tester, '/settings/users', 'Users');

    // Product master + Stock-take
    await expectScreen(tester, '/products', 'Products');
    await expectScreen(tester, '/products/new', 'New Product');
    await expectScreen(tester, '/inventory/stocktake', 'Stock-take');

    // GST registers + returns review (gate gst)
    await expectScreen(tester, '/finance/gst/einvoice', 'e-Invoice Register');
    await expectScreen(tester, '/finance/gst/eway', 'e-Way Bill Register');
    await expectScreen(tester, '/finance/gst/returns', 'GST Returns Review');

    // AI & Insights (business_trace / sales_intelligence / inventory_intelligence)
    await expectScreen(tester, '/insights/customer-trace', 'Customer Trace');
    await expectScreen(tester, '/insights/sales-advisor', 'Sales Advisor');
    await expectScreen(tester, '/insights/inventory-advisor', 'Inventory Advisor');
  });
}
