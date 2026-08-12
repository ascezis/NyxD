import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/vault/vault_exceptions.dart';
import 'package:nyxd/features/auth/presentation/unlock_screen.dart';

void main() {
  testWidgets('shows a clear error for a wrong password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          onUnlock: (_) async => throw const WrongPasswordException(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('unlock-password')),
      'wrong password',
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный пароль'), findsOneWidget);
  });

  testWidgets('submits the entered password', (tester) async {
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          onUnlock: (password) async => submittedPassword = password,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('unlock-password')),
      'correct password',
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(submittedPassword, 'correct password');
  });
}
