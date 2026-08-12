import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/security/external_activity_scope.dart';

void main() {
  test(
    'trusted external activity is active only while operation runs',
    () async {
      final controller = ExternalActivityController();

      expect(controller.isActive, isFalse);
      await controller.run(() async {
        expect(controller.isActive, isTrue);
      });
      expect(controller.isActive, isFalse);
    },
  );

  test('trusted state is cleared when operation throws', () async {
    final controller = ExternalActivityController();

    await expectLater(
      controller.run<void>(() async => throw StateError('picker failed')),
      throwsStateError,
    );
    expect(controller.isActive, isFalse);
  });
}
