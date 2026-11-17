import 'package:flutter_test/flutter_test.dart';
import 'package:flag_explorer_example/main.dart';
import 'package:flag_explorer/flag_explorer.dart';

void main() {
  testWidgets('Verify FlagExplorerExampleApp renders FlagExplorerView', (WidgetTester tester) async {
    await tester.pumpWidget(const FlagExplorerExampleApp());
    expect(find.byType(FlagExplorerView), findsOneWidget);
  });
}
