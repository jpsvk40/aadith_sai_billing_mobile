// Filter/Sort parity smoke test — boots the real app against the LOCAL backend,
// logs in as the Mobile Parity QA admin, deep-links to each list screen that got
// the new shared filter/sort controls, opens the Filters sheet, and dismisses it.
//
//   adb -s emulator-5554 shell pm grant com.aadithsai.aadith_sai_billing_mobile android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/filter_sort_smoke_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3001
//
// Seed first: node --experimental-require-module backend/scripts/seed-mobile-parity.cjs
//
// Note: taps use .hitTestable() so we only ever tap the on-screen button — during a
// go_router route transition the outgoing screen's identical "Filters" button lingers
// in the tree for a frame, and tapping that stale one opens nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'service_e2e_helpers.dart';

const qaEmail = 'mobileqa@example.com';

Future<void> goTo(WidgetTester tester, String location) async {
  final ctx = tester.element(find.byType(BottomNavigationBar).first);
  ctx.go(location);
  // Let the route transition fully settle so the outgoing screen's widgets are gone.
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 700));
}

Future<bool> pumpUntilGone(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 12)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return true;
  }
  return false;
}

/// Deep-link to [route], confirm the shared "Filters" + "Sort" controls rendered,
/// open the bottom sheet, confirm it built (its Apply button), then dismiss it.
Future<void> checkFilterSheet(WidgetTester tester, String route, String label,
    {bool expectFinancialYear = false}) async {
  await goTo(tester, route);

  final filtersBtn = find.text('Filters').hitTestable();
  expect(await pumpUntilFound(tester, filtersBtn), true,
      reason: '$label ($route): Filters button did not render');
  expect(find.text('Sort').hitTestable().evaluate().isNotEmpty, true,
      reason: '$label ($route): Sort control did not render');

  await tester.tap(filtersBtn.first);
  final sheetOpen = await pumpUntilFound(tester, find.text('Apply'));
  if (expectFinancialYear) {
    // The sheet section label is uppercased; the dropdown hint is "All Years".
    expect(await pumpUntilFound(tester, find.text('FINANCIAL YEAR'), timeout: const Duration(seconds: 20)), true,
        reason: '$label ($route): Financial Year filter did not render in the sheet');
  }
  if (!sheetOpen) {
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .where((d) => d != null && d.trim().isNotEmpty)
        .toList();
    debugPrint('DIAG[$route] on-screen texts: $texts');
  }
  expect(sheetOpen, true, reason: '$label ($route): filter sheet (Apply) did not open');

  // Dismiss by tapping the modal barrier above the sheet (opens at ~62% height).
  await tester.tapAt(const Offset(200, 40));
  await tester.pump(const Duration(milliseconds: 400));
  expect(await pumpUntilGone(tester, find.text('Apply')), true,
      reason: '$label ($route): filter sheet did not dismiss');
  expect(await pumpUntilFound(tester, find.text('Filters').hitTestable()), true,
      reason: '$label ($route): did not return to the list after closing filters');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Filter/Sort controls render + open on the core billing lists', (tester) async {
    await launchAndLogin(tester, qaEmail);

    // Core billing lists. The date-scoped lists also carry the Financial Year filter.
    await checkFilterSheet(tester, '/orders', 'Orders', expectFinancialYear: true);
    await checkFilterSheet(tester, '/invoices', 'Invoices', expectFinancialYear: true);
    await checkFilterSheet(tester, '/purchases', 'Purchases', expectFinancialYear: true);
    await checkFilterSheet(tester, '/payments', 'Payments', expectFinancialYear: true);
    await checkFilterSheet(tester, '/customers', 'Customers');
    await checkFilterSheet(tester, '/products', 'Products');
    await checkFilterSheet(tester, '/credit-notes', 'Customer Credit Notes');
    await checkFilterSheet(tester, '/vendor-credit-notes', 'Vendor Credit Notes');
    // ERP + service lists (co16 has these modules per the tier-2 seed).
    await checkFilterSheet(tester, '/tenders', 'Tenders');
    await checkFilterSheet(tester, '/projects', 'Projects');
    await checkFilterSheet(tester, '/machinery', 'Machinery');
    await checkFilterSheet(tester, '/service/tickets', 'Service Tickets');
    // New parity modules the QA user (vendor_purchases/gst/inventory/machinery) can reach.
    await checkFilterSheet(tester, '/vendors', 'Vendors');
    await checkFilterSheet(tester, '/procurement', 'Procurement');
    await checkFilterSheet(tester, '/gst-bills', 'GST Bills');
    await checkFilterSheet(tester, '/finance/inventory/entries/history', 'Stock Entries history');
    await checkFilterSheet(tester, '/machinery/logbook', 'Machinery Logbook');
    // NOTE: /finance/expenses is gated by the `finance_accounts` module, which the
    // mobileqa persona lacks — its FilterSortButtons wiring is verified by analyze +
    // build + inspection instead.
  });
}
