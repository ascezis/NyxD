import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/app/app.dart';

void main() {
  testWidgets('application shell renders', (tester) async {
    await tester.pumpWidget(
      const NyxDApp(home: Scaffold(body: Text('NyxD test shell'))),
    );

    expect(find.text('NyxD test shell'), findsOneWidget);
  });
}
