import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'magic_login_screen.dart';

/// Connexion (design_handoff_mobile 4e): the medallion and the logotype on the navy-to-blue
/// gradient, then the identifiant / mot de passe card, "Mot de passe oublié ?" opening the magic
/// link flow (tour 6), and the biometric mention in the footer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();

    try {
      await auth.login(
          _usernameController.text.trim(), _passwordController.text,
          rememberMe: _rememberMe);
      if (mounted) await _maybeOfferBiometrics(auth);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Impossible de contacter le serveur.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Never named "Face ID" or "Touch ID" - the wording stays generic whatever the device offers
  /// (handoff, principe 8).
  Future<void> _maybeOfferBiometrics(AuthService auth) async {
    if (!_rememberMe || auth.biometricEnabled || !await auth.canUseBiometrics) {
      return;
    }
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connexion biométrique',
            style: AppFont.spectral(size: 17, color: AppColors.navy)),
        content: Text(
          "Activez la connexion biométrique pour ouvrir l'app sans mot de passe la prochaine fois.",
          style: AppFont.sans(size: 13, color: AppColors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Plus tard',
                style: AppFont.sans(size: 13, color: AppColors.faint)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Activer',
                style: AppFont.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong)),
          ),
        ],
      ),
    );

    if (accepted ?? false) {
      await auth.setBiometricEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: BrandHero(
        footer: const _BiometricMention(),
        child: Column(
          children: [
            if (auth.hasPendingBiometricUnlock)
              _buildBiometricUnlock(auth)
            else
              _buildForm(),
            const SizedBox(height: 16),
            Text(
              "Besoin d'aide ? 05 55 45 81 00",
              style: AppFont.sans(size: 11.5, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return BrandCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              _ErrorBox(message: _errorMessage!),
              const SizedBox(height: 15),
            ],
            _Field(
              label: 'Identifiant',
              child: TextFormField(
                controller: _usernameController,
                decoration: _inputDecoration(),
                style: AppFont.sans(size: 14.5, color: AppColors.ink),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Identifiant requis'
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            _Field(
              label: 'Mot de passe',
              child: TextFormField(
                controller: _passwordController,
                decoration: _inputDecoration(
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AppIcon(
                        _obscurePassword ? AppIcons.eye : AppIcons.eyeOff,
                        size: 17,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                ),
                style: AppFont.sans(size: 14.5, color: AppColors.ink),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Mot de passe requis'
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Checkbox(checked: _rememberMe),
                      const SizedBox(width: 8),
                      Text('Rester connecté',
                          style:
                              AppFont.sans(size: 13, color: AppColors.text)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openMagicLink,
                  child: Text(
                    'Mot de passe oublié ?',
                    style: AppFont.sans(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.brand),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  /// "Mot de passe oublié ?" never resets a password (principe 7): it opens the passwordless
  /// login by mailed link (6a).
  void _openMagicLink() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const MagicLoginScreen(),
    ));
  }

  Widget _buildBiometricUnlock(AuthService auth) {
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.fingerprint,
                  size: 24, color: AppColors.brandStrong, strokeWidth: 1.8),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Session verrouillée',
            textAlign: TextAlign.center,
            style: AppFont.spectral(size: 17, color: AppColors.navy),
          ),
          const SizedBox(height: 13),
          if (_errorMessage != null) ...[
            _ErrorBox(message: _errorMessage!),
            const SizedBox(height: 13),
          ],
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => _unlock(auth),
            child: const Text('Déverrouiller'),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isSubmitting ? null : () => auth.logout(),
            child: Text(
              'Se connecter avec identifiant / mot de passe',
              textAlign: TextAlign.center,
              style: AppFont.sans(
                  size: 13, weight: FontWeight.w600, color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlock(AuthService auth) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final unlocked = await auth.unlockWithBiometrics();

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (!unlocked) {
          _errorMessage = "Échec de l'authentification biométrique.";
        }
      });
    }
  }

  InputDecoration _inputDecoration({Widget? suffix}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: suffix,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.brand),
        errorStyle: AppFont.sans(size: 11.5, color: AppColors.lateInk),
      );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: AppFont.sans(
                size: 13, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: checked ? AppColors.brand : AppColors.surface,
        border: Border.all(color: checked ? AppColors.brand : AppColors.border),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: checked
          ? const AppIcon(AppIcons.check,
              size: 11, color: Colors.white, strokeWidth: 3)
          : null,
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lateBg,
        border: Border.all(color: AppColors.lateBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message,
          style: AppFont.sans(size: 12.5, color: AppColors.lateInk)),
    );
  }
}

/// Footer of 4e - says biometric unlock exists without naming any vendor's.
class _BiometricMention extends StatelessWidget {
  const _BiometricMention();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppIcon(AppIcons.fingerprint,
            size: 14, color: AppColors.faint, strokeWidth: 1.8),
        const SizedBox(width: 6),
        Text('Connexion biométrique',
            style: AppFont.sans(size: 12, color: AppColors.faint)),
      ],
    );
  }
}
