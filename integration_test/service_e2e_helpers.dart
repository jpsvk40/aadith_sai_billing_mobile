// Shared helpers for the Service & Warranty integration tests.
//
// These drive the REAL app widget tree against the LOCAL TEST backend. Launch with:
//   flutter test integration_test/ -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:3001
// (Re-seed the backend before each run: node --experimental-require-module backend/scripts/seed-service-e2e.js)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aadith_sai_billing_mobile/main.dart';

const adminEmail = 'service-e2e-admin@example.com';
const techEmail = 'service-e2e-tech@example.com';
const password = 'Test@1234';

/// Pump repeatedly (up to [timeout]) until [finder] matches at least one widget.
/// pumpAndSettle is unsafe here: the app shows perpetual progress spinners during
/// network calls, which never "settle".
Future<bool> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Boot the real app and sign in as [email]. Returns once a post-login screen is up.
///
/// NOTE: pre-grant the notification permission so the first-launch system dialog doesn't cover the
/// widget tree (system dialogs aren't findable by the tester):
///   adb -s <device> shell pm grant com.aadithsai.aadith_sai_billing_mobile android.permission.POST_NOTIFICATIONS
Future<void> launchAndLogin(WidgetTester tester, String email) async {
  await tester.pumpWidget(const ProviderScope(child: BootstrapApp()));

  // Wait for bootstrap (dotenv/Hive/cache) → splash → login screen. On a cold/slow emulator the
  // startup Future can time out ("Startup failed" + a Retry button) — tap Retry and wait again.
  var loginUp = await pumpUntilFound(tester, find.text('Sign In'), timeout: const Duration(seconds: 60));
  if (!loginUp && find.text('Retry').evaluate().isNotEmpty) {
    await tester.tap(find.text('Retry'));
    loginUp = await pumpUntilFound(tester, find.text('Sign In'), timeout: const Duration(seconds: 60));
  }
  final emailField = find.byType(TextFormField);
  expect(loginUp, true, reason: 'Login screen did not appear');

  await tester.enterText(emailField.at(0), email);
  await tester.enterText(emailField.at(1), password);
  await tester.pump(const Duration(milliseconds: 200));

  await tester.tap(find.text('Sign In'));
  // Auth round-trip + go_router redirect to the persona home.
  await pumpUntilFound(tester, find.byType(BottomNavigationBar), timeout: const Duration(seconds: 40));
}

/// Tap a bottom-nav tab by its visible label (e.g. 'Service', 'My Tickets', 'Today').
Future<void> tapTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab.first);
    await tester.pump(const Duration(milliseconds: 600));
  }
}
