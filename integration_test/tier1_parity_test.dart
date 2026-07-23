// Tier-1 parity smoke test — boots the real app against the LOCAL backend, logs in
// as the Mobile Parity QA admin, and deep-links to each new screen to confirm it
// renders with real data + routing + providers wired.
//
//   adb -s emulator-5554 shell pm grant com.aadithsai.aadith_sai_billing_mobile android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/tier1_parity_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3001
//
// Seed first: node --experimental-require-module backend/scripts/seed-mobile-parity.cjs
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'service_e2e_helpers.dart';

const qaEmail = 'mobileqa@example.com';

/// Deep-link via go_router (reliable vs tapping through deep nav). All new screens
/// live inside the ShellRoute, so the BottomNavigationBar element stays a valid context.
Future<void> goTo(WidgetTester tester, String location) async {
  final ctx = tester.element(find.byType(BottomNavigationBar).first);
  ctx.go(location);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tier 1 parity — Quotations / Vendor pay / Stock entry render', (tester) async {
    await launchAndLogin(tester, qaEmail);

    // 1) Quotations list → New Quotation create form
    await goTo(tester, '/quotations');
    expect(await pumpUntilFound(tester, find.text('Quotations')), true, reason: 'Quotations list did not render');
    expect(await pumpUntilFound(tester, find.text('New Quotation')), true, reason: 'New Quotation FAB missing');
    await tester.tap(find.text('New Quotation'));
    // 'Line Items' + the 'Or contact name' label prove the create form rendered.
    // (The submit button is below the fold in a ListView, so it isn't built yet — don't assert it.)
    expect(await pumpUntilFound(tester, find.text('Line Items')), true, reason: 'Quotation create form (Line Items) missing');
    expect(find.text('Or contact name').evaluate().isNotEmpty, true, reason: 'Quotation create fields missing');

    // 2) Vendor pay screen (vendor picker prompt)
    await goTo(tester, '/finance/payables/pay');
    expect(await pumpUntilFound(tester, find.text('Pay Vendor')), true, reason: 'Pay Vendor screen missing');
    expect(await pumpUntilFound(tester, find.text('Select vendor')), true, reason: 'Vendor picker prompt missing');

    // 3) Vendor payments list
    await goTo(tester, '/finance/payables/payments');
    expect(await pumpUntilFound(tester, find.text('Vendor Payments')), true, reason: 'Vendor payments list missing');

    // 4) Stock entry create form
    await goTo(tester, '/finance/inventory/entries');
    expect(await pumpUntilFound(tester, find.text('New Stock Entry')), true, reason: 'Stock entry screen missing');
    expect(await pumpUntilFound(tester, find.text('Entry type')), true, reason: 'Stock entry fields missing');
  });
}
