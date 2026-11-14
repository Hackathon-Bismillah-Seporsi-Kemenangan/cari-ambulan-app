import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/auth_models.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_validators.dart';
import '../widgets/auth_page_layout.dart';

/// "Buat akun CariAmbulan" for patients; for drivers two steps, their own
/// data then the ambulance ("Data ambulans").
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({
    super.key,
    required this.role,
    required this.onLogin,
    required this.onChangeRole,
    required this.onBusyChanged,
  });

  final UserRole role;
  final VoidCallback onLogin;
  final VoidCallback onChangeRole;
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

/// The ambulance types on "Jenis kendaraan".
const _vehicleTypes = [
  (name: 'Ambulans Transport', note: 'Untuk pasien dengan kondisi stabil'),
  (name: 'Ambulans Gawat Darurat', note: 'Dilengkapi peralatan gawat darurat'),
  (name: 'Ambulans ICU Bergerak', note: 'Peralatan perawatan intensif'),
];

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _accountForm = GlobalKey<FormState>();
  final _ambulanceForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _license = TextEditingController();
  final _plate = TextEditingController();
  final _password = TextEditingController();
  String _vehicleType = _vehicleTypes[1].name;

  /// The driver's second step, "Data ambulans".
  bool _onAmbulanceStep = false;
  bool _isSubmitting = false;
  bool _obscure = true;
  String? _error;

  bool get _isDriver => widget.role.isDriver;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _license, _plate]) {
      controller.dispose();
    }
    _password.dispose();
    super.dispose();
  }

  void _next() {
    if (!_accountForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _onAmbulanceStep = true;
      _error = null;
    });
  }

  void _back() {
    if (_onAmbulanceStep) {
      setState(() => _onAmbulanceStep = false);
    } else {
      widget.onLogin();
    }
  }

  Future<void> _submit() async {
    final form = _onAmbulanceStep ? _ambulanceForm : _accountForm;
    if (_isSubmitting || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            RegistrationData(
              fullName: _name.text,
              email: _email.text,
              phone: _phone.text,
              password: _password.text,
              // The design asks once; the visibility toggle lets the user
              // check what they typed.
              passwordConfirmation: _password.text,
              role: widget.role,
              licenseNumber: _isDriver ? _license.text : null,
              plateNumber: _isDriver ? _plate.text : null,
              vehicleType: _isDriver ? _vehicleType : null,
            ),
          );
      TextInput.finishAutofillContext();
    } on ApiException catch (e) {
      // The server only checks the account fields, which are on step 1.
      if (mounted) {
        setState(() {
          _error = e.message;
          _onAmbulanceStep = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pendaftaran belum dapat diselesaikan. Jika akun sudah dibuat, silakan masuk.',
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
    return PopScope(
      // Back on "Data ambulans" returns to step 1, not to Masuk.
      canPop: !_onAmbulanceStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSubmitting) _back();
      },
      child: _onAmbulanceStep ? _ambulanceStep() : _accountStep(),
    );
  }

  Widget _accountStep() {
    return AuthPageLayout(
      isDriver: _isDriver,
      step: _isDriver ? 'LANGKAH 1 DARI 2' : null,
      title: _isDriver ? 'Daftar sebagai Driver' : 'Buat akun CariAmbulan',
      onBack: _back,
      isBusy: _isSubmitting,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthErrorBanner(_error!),
          if (!_isDriver) const AuthTermsNote(),
          AuthSubmitButton(
            label: _isDriver ? 'Lanjut' : 'Daftar',
            isBusy: _isSubmitting,
            onPressed: _isDriver ? _next : _submit,
          ),
          const SizedBox(height: 8),
          AuthSwitchLink(
            question: _isDriver ? 'Sudah jadi mitra?' : 'Sudah punya akun?',
            action: 'Masuk',
            onPressed: _isSubmitting ? null : widget.onLogin,
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _accountForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Nama lengkap',
                child: TextFormField(
                  key: const ValueKey('register_name'),
                  controller: _name,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Nama sesuai KTP',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => AuthFormValidators.requiredText(
                    value,
                    'Nama lengkap',
                    maxLength: 200,
                  ),
                ),
              ),
              AuthField(
                label: 'Nomor HP',
                child: TextFormField(
                  key: const ValueKey('register_phone'),
                  controller: _phone,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '0812 3456 7890',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => AuthFormValidators.requiredText(
                    value,
                    'Nomor HP',
                    maxLength: 20,
                  ),
                ),
              ),
              AuthField(
                label: 'Email',
                child: TextFormField(
                  key: const ValueKey('register_email'),
                  controller: _email,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: AuthFormValidators.email,
                ),
              ),
              // The server still needs the SIM at registration.
              if (_isDriver)
                AuthField(
                  label: 'Nomor SIM',
                  child: TextFormField(
                    key: const ValueKey('register_license'),
                    controller: _license,
                    enabled: !_isSubmitting,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nomor SIM B1 Umum',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => AuthFormValidators.requiredText(
                      value,
                      'Nomor SIM',
                      maxLength: 20,
                    ),
                  ),
                ),
              AuthField(
                label: 'Kata sandi',
                child: TextFormField(
                  key: const ValueKey('register_password'),
                  controller: _password,
                  enabled: !_isSubmitting,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isDriver ? _next() : _submit(),
                  decoration: InputDecoration(
                    hintText: 'Minimal 8 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure
                          ? 'Tampilkan kata sandi'
                          : 'Sembunyikan kata sandi',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: AuthFormValidators.newPassword,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ambulanceStep() {
    return AuthPageLayout(
      isDriver: true,
      step: 'LANGKAH 2 DARI 2',
      title: 'Data ambulans',
      subtitle: 'Isi sesuai STNK ambulans yang Anda kemudikan.',
      onBack: _back,
      isBusy: _isSubmitting,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthErrorBanner(_error!),
          const AuthTermsNote(),
          AuthSubmitButton(
            label: 'Daftar',
            isBusy: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
      child: Form(
        key: _ambulanceForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              label: 'Plat nomor',
              child: TextFormField(
                key: const ValueKey('register_plate'),
                controller: _plate,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'B 1234 SGP',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                validator: (value) => AuthFormValidators.requiredText(
                  value,
                  'Plat nomor',
                  maxLength: 15,
                ),
              ),
            ),
            AuthField(
              label: 'Jenis kendaraan',
              child: _VehicleTypePicker(
                value: _vehicleType,
                onChanged: _isSubmitting
                    ? null
                    : (type) => setState(() => _vehicleType = type),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three ambulance types as one bordered list; the chosen one is
/// tinted, as in the design.
class _VehicleTypePicker extends StatelessWidget {
  const _VehicleTypePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return RadioGroup<String>(
      groupValue: value,
      onChanged: (type) {
        if (type != null) onChanged?.call(type);
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            for (final (index, type) in _vehicleTypes.indexed) ...[
              if (index > 0) const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Material(
                color: type.name == value
                    ? AppColors.primaryLight
                    : Colors.white,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(type.name),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type.note,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: type.name,
                          activeColor: accent,
                          enabled: onChanged != null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
