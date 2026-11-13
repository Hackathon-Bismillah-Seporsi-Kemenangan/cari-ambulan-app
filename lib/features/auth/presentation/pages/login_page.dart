import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/network/api_client.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_validators.dart';
import '../widgets/auth_page_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    required this.role,
    required this.onRegister,
    required this.onChangeRole,
    required this.onBusyChanged,
  });

  final UserRole role;
  final VoidCallback onRegister;
  final VoidCallback onChangeRole;
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSubmitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      TextInput.finishAutofillContext();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sesi login belum dapat disimpan. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role.isDriver;
    return AuthPageLayout(
      isDriver: isDriver,
      title: isDriver ? 'Masuk sebagai Driver' : 'Masuk ke SigapMed',
      subtitle: isDriver
          ? 'Masuk dengan email yang Anda daftarkan di SigapMed.'
          : 'Masuk dengan email dan kata sandi Anda.',
      onBack: widget.onChangeRole,
      isBusy: _isSubmitting,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthErrorBanner(_error!),
          AuthSubmitButton(
            label: 'Masuk',
            isBusy: _isSubmitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          AuthSwitchLink(
            question: isDriver ? 'Belum jadi mitra?' : 'Belum punya akun?',
            action: isDriver ? 'Daftar sebagai driver' : 'Daftar',
            onPressed: _isSubmitting ? null : widget.onRegister,
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email',
                child: TextFormField(
                  key: const ValueKey('login_email'),
                  controller: _email,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: AuthFormValidators.email,
                ),
              ),
              AuthField(
                label: 'Kata sandi',
                child: TextFormField(
                  key: const ValueKey('login_password'),
                  controller: _password,
                  enabled: !_isSubmitting,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Kata sandi Anda',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: _ObscureToggle(
                      obscure: _obscure,
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Kata sandi wajib diisi'
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObscureToggle extends StatelessWidget {
  const _ObscureToggle({required this.obscure, required this.onPressed});

  final bool obscure;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}
