import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nyxd/core/vault/vault_exceptions.dart';
import 'package:nyxd/core/vault/vault_paths.dart';
import 'package:nyxd/core/vault/vault_service.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'vault create, lock and unlock lifecycle works on Android',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/integration-vault');
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      final vault = VaultService(paths: VaultPaths(directory));

      try {
        expect(vault.status, VaultStatus.uninitialized);

        await vault.createVault('correct password');
        expect(vault.status, VaultStatus.unlocked);
        expect(vault.paths.database.existsSync(), isTrue);
        expect(vault.paths.metadata.existsSync(), isTrue);

        var entries = EntryRepository(vault.database);
        final created = entries.create('Android encrypted note #test');
        expect(entries.getById(created.id).content, created.content);

        final backup = vault.createBackup();
        entries.create('Этой заметки в копии нет');
        await expectLater(
          vault.restoreBackup(backup, 'wrong password'),
          throwsA(anything),
        );
        expect(vault.status, VaultStatus.unlocked);
        expect(EntryRepository(vault.database).listActive(), hasLength(2));

        await vault.restoreBackup(backup, 'correct password');
        entries = EntryRepository(vault.database);
        expect(entries.listActive().single.content, created.content);

        vault.lockVault();
        expect(vault.status, VaultStatus.locked);

        await expectLater(
          vault.unlockVault('wrong password'),
          throwsA(isA<WrongPasswordException>()),
        );
        expect(vault.status, VaultStatus.locked);

        await vault.unlockVault('correct password');
        expect(vault.status, VaultStatus.unlocked);
        entries = EntryRepository(vault.database);
        expect(entries.listActive().single.content, created.content);
      } finally {
        vault.dispose();
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
