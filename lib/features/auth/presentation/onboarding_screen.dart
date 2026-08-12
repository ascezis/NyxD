import 'package:flutter/material.dart';
import 'package:nyxd/app/brand/brand_mark.dart';

typedef CreateVaultCallback = Future<void> Function(String password);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCreate});

  final CreateVaultCallback onCreate;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  String? _error;
  bool _acceptedWarning = false;
  bool _obscurePassword = true;
  bool _working = false;

  @override
  void dispose() {
    _passwordController
      ..clear()
      ..dispose();
    _confirmationController
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Введите мастер-пароль');
      return;
    }
    if (password != _confirmationController.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    if (!_acceptedWarning) {
      setState(() => _error = 'Подтвердите предупреждение');
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.onCreate(password);
      _passwordController.clear();
      _confirmationController.clear();
    } on Object {
      if (mounted) {
        setState(() => _error = 'Не удалось создать хранилище');
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BrandMark(size: 112)),
              const SizedBox(height: 24),
              Text(
                'Создайте мастер-пароль',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Он будет нужен каждый раз, когда вы открываете дневник.',
              ),
              const SizedBox(height: 32),
              TextField(
                key: const Key('password'),
                controller: _passwordController,
                enabled: !_working,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 16),
              TextField(
                key: const Key('password-confirmation'),
                controller: _confirmationController,
                enabled: !_working,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Повторите пароль',
                ),
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Восстановления пароля нет. Если вы забудете его, заметки '
                    'будут потеряны безвозвратно.',
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedWarning,
                onChanged: _working
                    ? null
                    : (value) =>
                          setState(() => _acceptedWarning = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Я понимаю и сохраню пароль в надёжном месте',
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _working ? null : _submit,
                child: Text(
                  _working ? 'Создаём хранилище…' : 'Создать дневник',
                ),
              ),
              if (_working) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Настраиваем защиту под это устройство…'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
