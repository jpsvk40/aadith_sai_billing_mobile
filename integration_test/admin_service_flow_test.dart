// Admin/Owner Service persona E2E — login → Service dashboard → create ticket → assign.
// Run: flutter test integration_test/admin_service_flow_test.dart -d emulator-5554 \
//        --dart-define=API_BASE_URL=http://10.0.2.2:3001
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'service_e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Service flow', () {
    testWidgets('Service tab → dashboard KPIs render', (tester) async {
      await launchAndLogin(tester, adminEmail);

      await tapTab(tester, 'Service');
      // Dashboard KPI tiles.
      final ok = await pumpUntilFound(tester, find.text('Open'), timeout: const Duration(seconds: 25));
      expect(ok, true, reason: 'Service dashboard KPIs should render');
      expect(find.text('New Ticket'), findsOneWidget);
    });

    testWidgets('create a ticket → assign a technician', (tester) async {
      await launchAndLogin(tester, adminEmail);
      await tapTab(tester, 'Service');
      await pumpUntilFound(tester, find.text('New Ticket'), timeout: const Duration(seconds: 25));

      // Open the create form.
      await tester.tap(find.text('New Ticket'));
      await pumpUntilFound(tester, find.text('Select customer *'), timeout: const Duration(seconds: 15));

      // Pick the first customer.
      await tester.tap(find.text('Select customer *'));
      await pumpUntilFound(tester, find.text('Select customer'), timeout: const Duration(seconds: 15));
      final firstCustomer = await pumpUntilFound(tester, find.byIcon(Icons.person_outline), timeout: const Duration(seconds: 15));
      expect(firstCustomer, true, reason: 'Customer picker should list customers');
      await tester.tap(find.byIcon(Icons.person_outline).last);
      await tester.pump(const Duration(milliseconds: 500));

      // Fill the reported problem and submit.
      await tester.enterText(find.widgetWithText(TextFormField, 'Reported problem *'), 'E2E created ticket');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Create ticket'));

      // Lands on the new ticket's detail → admin section visible.
      final created = await pumpUntilFound(tester, find.text('Assignment & Estimate'), timeout: const Duration(seconds: 25));
      expect(created, true, reason: 'Should navigate to the created ticket detail');

      // Assign a technician.
      await tester.tap(find.text('Assign'));
      final picker = await pumpUntilFound(tester, find.text('Assign technician'), timeout: const Duration(seconds: 15));
      expect(picker, true, reason: 'Technician picker should open');
      await tester.tap(find.byIcon(Icons.engineering_outlined).first);

      // Technician name now shown in the assignment row.
      final assigned = await pumpUntilFound(tester, find.textContaining('Technician'), timeout: const Duration(seconds: 20));
      expect(assigned, true);
    });
  });
}
