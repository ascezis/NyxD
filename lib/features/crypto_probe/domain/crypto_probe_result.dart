final class CryptoProbeResult {
  const CryptoProbeResult({
    required this.derivationDuration,
    required this.correctPasswordAccepted,
    required this.wrongPasswordRejected,
    required this.databasePath,
  });

  final Duration derivationDuration;
  final bool correctPasswordAccepted;
  final bool wrongPasswordRejected;
  final String databasePath;

  bool get succeeded => correctPasswordAccepted && wrongPasswordRejected;
}
