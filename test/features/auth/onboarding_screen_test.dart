import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/features/auth/presentation/onboarding_screen.dart';

void main() {
  testWidgets('requires matching passwords and warning acknowledgement', (
    tester,
  ) async {
    String? createdPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCreate: (password) async => createdPassword = password,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('password')), 'first');
    await tester.enterText(
      find.byKey(const Key('password-confirmation')),
      'second',
    );
    await tester.ensureVisible(find.text('Создать дневник'));
    await tester.tap(find.text('Создать дневник'));
    await tester.pump();

    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(createdPassword, isNull);

    await tester.enterText(
      find.byKey(const Key('password-confirmation')),
      'first',
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Создать дневник'));
    await tester.tap(find.text('Создать дневник'));
    await tester.pumpAndSettle();

    expect(createdPassword, 'first');
  });

  testWidgets('shows irreversible password-loss warning', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onCreate: (_) async {})),
    );

    expect(find.textContaining('Восстановления пароля нет'), findsOneWidget);
    expect(find.textContaining('потеряны безвозвратно'), findsOneWidget);
  });
}
