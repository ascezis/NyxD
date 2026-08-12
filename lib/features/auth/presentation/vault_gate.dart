import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nyxd/app/theme/theme_controller.dart';
import 'package:nyxd/core/security/external_activity_scope.dart';
import 'package:nyxd/core/vault/vault_paths.dart';
import 'package:nyxd/core/vault/vault_service.dart';
import 'package:nyxd/features/auth/presentation/onboarding_screen.dart';
import 'package:nyxd/features/auth/presentation/unlock_screen.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/home/presentation/home_screen.dart';
import 'package:path_provider/path_provider.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({
    super.key,
    this.vault,
    this.inactivityTimeout,
    this.externalActivityController,
    this.settings,
  });

  final VaultService? vault;
  final Duration? inactivityTimeout;
  final ExternalActivityController? externalActivityController;
  final ThemeController? settings;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  VaultService? _vault;
  Object? _initializationError;
  Timer? _inactivityTimer;
  ThemeController? _settings;
  int? _lastTimeoutSeconds;
  late final ExternalActivityController _externalActivity;

  Duration get _inactivityTimeout =>
      widget.inactivityTimeout ??
      Duration(seconds: _settings?.inactivityTimeoutSeconds ?? 40);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _externalActivity =
        widget.externalActivityController ?? ExternalActivityController();
    _vault = widget.vault;
    if (_vault == null) {
      _initialize();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = widget.settings;
    if (settings == null) return;
    if (!identical(settings, _settings)) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = settings..addListener(_onSettingsChanged);
      _lastTimeoutSeconds = settings.inactivityTimeoutSeconds;
    }
  }

  void _onSettingsChanged() {
    final seconds = _settings?.inactivityTimeoutSeconds;
    if (seconds == _lastTimeoutSeconds) return;
    _lastTimeoutSeconds = seconds;
    if (widget.inactivityTimeout == null &&
        _vault?.status == VaultStatus.unlocked) {
      _markActivity();
    }
  }

  Future<void> _initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      if (mounted) {
        setState(() => _vault = VaultService(paths: VaultPaths(directory)));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _initializationError = error);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings?.removeListener(_onSettingsChanged);
    _inactivityTimer?.cancel();
    _vault?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_externalActivity.isActive) {
      if (state == AppLifecycleState.resumed) {
        _markActivity();
      } else {
        _inactivityTimer?.cancel();
        _inactivityTimer = null;
      }
      return;
    }
    if (state != AppLifecycleState.resumed &&
        _vault?.status == VaultStatus.unlocked) {
      _lockVault();
    }
  }

  void _markActivity() {
    if (_vault?.status != VaultStatus.unlocked) {
      return;
    }
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _lockVault);
  }

  Future<void> _createVault(String password) async {
    await _vault!.createVault(password);
    _markActivity();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _unlockVault(String password) async {
    await _vault!.unlockVault(password);
    _markActivity();
    if (mounted) {
      setState(() {});
    }
  }

  void _lockVault() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _vault!.lockVault();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError case final error?) {
      return _InitializationError(error: error);
    }

    final vault = _vault;
    if (vault == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return switch (vault.status) {
      VaultStatus.uninitialized => OnboardingScreen(onCreate: _createVault),
      VaultStatus.locked => UnlockScreen(onUnlock: _unlockVault),
      VaultStatus.unlocked => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _markActivity(),
        onPointerMove: (_) => _markActivity(),
        child: HomeScreen(
          repository: EntryRepository(vault.database),
          vault: vault,
          externalActivity: _externalActivity,
          settings: _settings,
          onActivity: _markActivity,
          onLock: _lockVault,
          onRestored: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    };
  }
}

class _InitializationError extends StatelessWidget {
  const _InitializationError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Не удалось открыть локальное хранилище.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
