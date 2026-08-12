final class ExternalActivityController {
  int _activeCount = 0;

  bool get isActive => _activeCount > 0;

  void begin() {
    _activeCount++;
  }

  void end() {
    if (_activeCount == 0) return;
    _activeCount--;
  }

  Future<T> run<T>(Future<T> Function() action) async {
    begin();
    try {
      return await action();
    } finally {
      end();
    }
  }
}
