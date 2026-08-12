import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nyxd/app/app.dart';
import 'package:nyxd/core/security/external_activity_scope.dart';
import 'package:nyxd/core/vault/vault_paths.dart';
import 'package:nyxd/core/vault/vault_service.dart';
import 'package:nyxd/features/auth/presentation/vault_gate.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'onboarding, lock and unlock flow works on Android',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/integration-auth-flow');
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      final vault = VaultService(paths: VaultPaths(directory));
      addTearDown(() {
        vault.dispose();
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });

      final externalActivity = ExternalActivityController();
      await tester.pumpWidget(
        NyxDApp(
          home: VaultGate(
            vault: vault,
            inactivityTimeout: const Duration(seconds: 40),
            externalActivityController: externalActivity,
          ),
        ),
      );
      expect(find.text('Создайте мастер-пароль'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('password')),
        'test password',
      );
      await tester.enterText(
        find.byKey(const Key('password-confirmation')),
        'test password',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Создать дневник'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Все заметки'), findsOneWidget);
      await tester.tap(find.byTooltip('Новая заметка'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('entry-title')),
        'Тестовая заметка',
      );
      await tester.enterText(find.byKey(const Key('entry-editor')), 'Текст');
      await tester.tap(find.text('Добавить метку…'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('tag-input')), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Тестовая заметка'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('#test'), findsOneWidget);
      await tester.tap(find.text('Заблокировать'));
      await tester.pumpAndSettle();
      expect(find.text('Откройте дневник'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('unlock-password')),
        'wrong password',
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Неверный пароль'), findsOneWidget);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('unlock-password')))
            .enabled,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('unlock-password')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('unlock-password')),
        'test password',
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('unlock-password')),
      );
      expect(passwordField.controller!.text, 'test password');
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(vault.status, VaultStatus.unlocked);
      expect(find.text('Тестовая заметка'), findsOneWidget);

      externalActivity.begin();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(vault.status, VaultStatus.unlocked);
      externalActivity.end();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(vault.status, VaultStatus.locked);
      expect(find.text('Откройте дневник'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('unlock-password')),
        'test password',
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(vault.status, VaultStatus.unlocked);

      await tester.pump(const Duration(seconds: 41));
      await tester.pump();
      expect(vault.status, VaultStatus.locked);
      expect(find.text('Откройте дневник'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
