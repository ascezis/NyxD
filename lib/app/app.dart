import 'package:flutter/material.dart';
import 'package:nyxd/app/theme/app_theme.dart';
import 'package:nyxd/app/theme/theme_controller.dart';
import 'package:nyxd/features/auth/presentation/vault_gate.dart';

class NyxDApp extends StatefulWidget {
  const NyxDApp({super.key, this.home});

  final Widget? home;

  @override
  State<NyxDApp> createState() => _NyxDAppState();
}

class _NyxDAppState extends State<NyxDApp> {
  late final ThemeController _themeController;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _vaultGateKey = GlobalKey<VaultGateState>();

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController()..load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'NyxD',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeController.themeMode,
        builder: (context, child) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _vaultGateKey.currentState?.markActivity(),
            onPointerMove: (_) => _vaultGateKey.currentState?.markActivity(),
            onPointerUp: (_) => _vaultGateKey.currentState?.markActivity(),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home:
            widget.home ??
            VaultGate(
              key: _vaultGateKey,
              navigatorKey: _navigatorKey,
              settings: _themeController,
            ),
      ),
    );
  }
}
