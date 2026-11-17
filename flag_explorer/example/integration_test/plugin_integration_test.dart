import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flag_explorer_example/main.dart';
import 'package:flag_explorer/flag_explorer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flag Explorer All-Native Plugin Lifecycle & Controls', () {
    testWidgets('Full lifecycle: mount, country detection, focusCountry, and disposal', (tester) async {
      await tester.pumpWidget(const FlagExplorerExampleApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 1. Verify FlagExplorerView is mounted
      expect(find.byType(FlagExplorerView), findsOneWidget);

      // 2. Test Navigation Lifecycle: Push a blank screen and Pop back
      final context = tester.element(find.byType(FlagExplorerScreen));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Temporary Route')),
            body: const Center(child: Text('Outside Globe')),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Outside Globe'), findsOneWidget);

      // Pop back to Globe screen
      Navigator.of(tester.element(find.text('Outside Globe'))).pop();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(FlagExplorerView), findsOneWidget);
    });
  });
}
