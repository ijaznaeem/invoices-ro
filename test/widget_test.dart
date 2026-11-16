import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/main.dart';
import 'package:invoices_ro/state/app_state.dart';
import 'package:invoices_ro/state/app_state_scope.dart';

void main() {
  testWidgets('Home shell renders main navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: MaterialApp(
          home: HomeShell(
            onToggleTheme: () {},
            themeMode: ThemeMode.light,
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsNWidgets(2));
    expect(find.text('Recurring'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
  });
}
