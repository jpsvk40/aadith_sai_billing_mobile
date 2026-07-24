// Super Admin (platform) smoke test — boots the real app against the LOCAL backend,
// signs in as the seeded platform super_admin, and walks the four platform tabs
// (Overview / Companies / Queue / Platform) plus a company detail + a lifecycle-action
// confirm dialog (cancelled, so the test is non-destructive).
//
//   adb -s emulator-5554 shell pm grant com.aadithsai.aadith_sai_billing_mobile android.permission.POST_NOTIFICATIONS
//   flutter test integration_test/superadmin_smoke_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3001
//
// Seed first: node --experimental-require-module backend/scripts/seed-superadmin-platform.cjs
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aadith_sai_billing_mobile/main.dart';
import 'service_e2e_helpers.dart';

const superEmail = 'superadmin@aadithsai.test';
const superPassword = 'Super@1234';

void _dumpVisibleText(String tag) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((d) => d != null && d.trim().isNotEmpty)
      .toList();
  debugPrint('DIAG[$tag] on-screen texts: $texts');
}

Future<void> launchAndLoginSuper(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: BootstrapApp()));
  // Cold, freshly-booted emulator under test instrumentation can take well over a
  // minute to finish bootstrap → splash → login. Wait generously and tap Retry if the
  // startup Future timed out.
  var loginUp = await pumpUntilFound(tester, find.text('Sign In'), timeout: const Duration(seconds: 150));
  for (var i = 0; i < 2 && !loginUp; i++) {
    if (find.text('Retry').evaluate().isNotEmpty) {
      await tester.tap(find.text('Retry'));
    }
    loginUp = await pumpUntilFound(tester, find.text('Sign In'), timeout: const Duration(seconds: 90));
  }
  if (!loginUp) _dumpVisibleText('no-login');
  expect(loginUp, true, reason: 'Login screen did not appear');
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), superEmail);
  await tester.enterText(fields.at(1), superPassword);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('Sign In'));
  // Auth round-trip + redirect into the SuperAdminShell (its own bottom nav).
  await pumpUntilFound(tester, find.byType(BottomNavigationBar), timeout: const Duration(seconds: 40));
}

/// Tap a platform bottom-nav tab by its label and let the route settle.
Future<void> tapPlatformTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Super Admin platform shell: tabs + company detail + action dialog', (tester) async {
    await launchAndLoginSuper(tester);

    // ── Landed on the Control Tower (platform shell, not a tenant home) ──
    expect(find.text('Overview').evaluate().isNotEmpty, true, reason: 'Platform nav (Overview) not present');
    expect(find.text('Companies').evaluate().isNotEmpty, true, reason: 'Platform nav (Companies) not present');
    expect(find.text('Queue').evaluate().isNotEmpty, true, reason: 'Platform nav (Queue) not present');
    // Control Tower content loaded from /reports/platform-dashboard.
    expect(await pumpUntilFound(tester, find.textContaining('Platform at a glance'), timeout: const Duration(seconds: 25)),
        true, reason: 'Control Tower KPIs did not render');

    // ── Companies tab: seeded tenants render ──
    await tapPlatformTab(tester, 'Companies');
    expect(await pumpUntilFound(tester, find.textContaining('Zenith'), timeout: const Duration(seconds: 25)),
        true, reason: 'Companies list did not render seeded tenants');

    // ── Queue tab ──
    await tapPlatformTab(tester, 'Queue');
    expect(await pumpUntilFound(tester, find.textContaining('Action Queue'), timeout: const Duration(seconds: 20)),
        true, reason: 'Action Queue did not render');

    // ── Platform settings tab ──
    await tapPlatformTab(tester, 'Platform');
    expect(await pumpUntilFound(tester, find.textContaining('Sign out'), timeout: const Duration(seconds: 20)),
        true, reason: 'Platform settings did not render');

    // ── Company detail via a direct deep-link (robust vs. list scroll position) ──
    // Grab the router from a live element and push the detail route for a seeded co.
    final ctx = tester.element(find.byType(BottomNavigationBar).first);
    ctx.go('/superadmin/companies');
    await tester.pump(const Duration(milliseconds: 500));
    // Tap the first seeded company we can see to open its detail. Use the plain finder
    // for the wait (a `.first` finder throws "No element" when it matches nothing) and
    // only take `.first` once we know it exists.
    final target = find.textContaining('Zenith');
    expect(await pumpUntilFound(tester, target), true, reason: 'No company row to open');
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));
    final detailUp = await pumpUntilFound(tester, find.textContaining('Primary admin'), timeout: const Duration(seconds: 25));
    if (!detailUp) _dumpVisibleText('detail');
    expect(detailUp, true, reason: 'Company detail did not render');

    // ── Lifecycle action wiring: open a confirm dialog, then cancel (non-destructive) ──
    final resetTile = find.textContaining('Reset password');
    if (resetTile.evaluate().isNotEmpty) {
      await tester.tap(resetTile.first);
      await tester.pump(const Duration(milliseconds: 500));
      final dialogUp = find.byType(AlertDialog).evaluate().isNotEmpty || find.text('Cancel').evaluate().isNotEmpty;
      expect(dialogUp, true, reason: 'Lifecycle action did not open a confirm dialog');
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel').last);
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
  });
}
