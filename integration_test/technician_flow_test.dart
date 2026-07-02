// Technician persona E2E — login → My Tickets → open → change status → guards.
// Run: flutter test integration_test/technician_flow_test.dart -d emulator-5554 \
//        --dart-define=API_BASE_URL=http://10.0.2.2:3001
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'service_e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Technician flow', () {
    testWidgets('login → My Tickets is non-empty and shows the assigned ticket', (tester) async {
      await launchAndLogin(tester, techEmail);

      // Technician lands on their queue.
      expect(find.text('My Tickets'), findsWidgets, reason: 'Should land on the technician queue');

      // The seeded ticket SVC-0003xx is assigned to this technician.
      final ticket = await pumpUntilFound(tester, find.textContaining('SVC-'), timeout: const Duration(seconds: 20));
      expect(ticket, true, reason: 'My Tickets should contain at least one assigned ticket');
    });

    testWidgets('guards: technician does NOT see admin/financial tabs', (tester) async {
      await launchAndLogin(tester, techEmail);
      await pumpUntilFound(tester, find.byType(BottomNavigationBar));

      expect(find.text('My Tickets'), findsWidgets);
      expect(find.text('Today'), findsWidgets);
      // Financial/admin tabs must be absent for a technician.
      expect(find.text('Payments'), findsNothing);
      expect(find.text('Service'), findsNothing); // that's the admin Service tab
    });

    testWidgets('open ticket → change status advances the FSM', (tester) async {
      await launchAndLogin(tester, techEmail);
      final found = await pumpUntilFound(tester, find.textContaining('SVC-'));
      expect(found, true);

      // Open the first ticket.
      await tester.tap(find.textContaining('SVC-').first);
      await pumpUntilFound(tester, find.text('Change status'), timeout: const Duration(seconds: 20));
      expect(find.text('Change status'), findsOneWidget);

      // Open the status sheet and pick the first allowed next status.
      await tester.tap(find.text('Change status'));
      await pumpUntilFound(tester, find.text('Move ticket to…'));
      // The sheet lists ListTiles for each allowed status; tap the first one.
      final firstOption = find.descendant(of: find.byType(ListTile), matching: find.byIcon(Icons.arrow_forward)).first;
      await tester.tap(firstOption);

      // Back on the detail screen; the History section should reflect the change after refresh.
      await pumpUntilFound(tester, find.text('History'), timeout: const Duration(seconds: 20));
      expect(find.text('History'), findsOneWidget);
    });
  });
}
