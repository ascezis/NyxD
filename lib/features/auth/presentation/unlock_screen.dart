import 'package:flutter/material.dart';
import 'package:nyxd/app/brand/brand_mark.dart';
import 'package:nyxd/core/vault/vault_exceptions.dart';

typedef UnlockVaultCallback = Future<void> Function(String password);

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlock});

  final UnlockVaultCallback onUnlock;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passwordController = TextEditingController();

  String? _error;
  bool _obscurePassword = true;
  bool _working = false;

  @override
  void dispose() {
    _passwordController
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Введите мастер-пароль');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.onUnlock(_passwordController.text);
      _passwordController.clear();
    } on WrongPasswordException {
      if (mounted) {
        setState(() => _error = 'Неверный пароль');
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Не удалось открыть хранилище');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: BrandMark(size: 132)),
              const SizedBox(height: 28),
              Text(
                'Откройте дневник',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              TextField(
                key: const Key('unlock-password'),
                controller: _passwordController,
                autofocus: true,
                enabled: !_working,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Мастер-пароль',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _working ? null : _submit,
                child: Text(_working ? 'Открываем…' : 'Открыть'),
              ),
              if (_working) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
