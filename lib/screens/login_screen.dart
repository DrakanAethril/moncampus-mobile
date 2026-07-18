import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _maybeOfferBiometrics(AuthService auth) async {
    if (!_rememberMe || auth.biometricEnabled || !await auth.canUseBiometrics) {
      return;
    }
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connexion biométrique'),
        content: const Text(
            'Utiliser Face ID / empreinte pour déverrouiller MonCampus la prochaine fois ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Non merci')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Activer')),
        ],
      ),
    );

    if (accepted ?? false) {
      await auth.setBiometricEnabled(true);
    }
  }

  void _showForgotPasswordHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié ?'),
        content: const Text(
            "Contactez le secrétariat de l'établissement au 05 55 45 81 00 pour réinitialiser votre mot de passe."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navy,
              AppColors.brand,
              AppColors.bg,
              AppColors.bg
            ],
            stops: [0, 0.42, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 44),
                _buildBrand(),
                const SizedBox(height: 30),
                if (auth.hasPendingBiometricUnlock)
                  _buildBiometricUnlock(auth)
                else
                  _buildForm(),
                const SizedBox(height: 16),
                const Text(
                  "Besoin d'aide ? 05 55 45 81 00",
                  style: TextStyle(fontSize: 11.5, color: AppColors.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/icons/moncampus/ic_launcher_144.png',
              width: 76, height: 76),
        ),
        const SizedBox(height: 12),
        const Text(
          'Institution Beaupeyrat',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        const SizedBox(height: 3),
        const Text(
          'DEPUIS 1634',
          style: TextStyle(
              color: Color(0xFFBCD4E6), fontSize: 11.5, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withOpacity(0.14),
              blurRadius: 34,
              offset: const Offset(0, 14))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.redTx)),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Identifiant'),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Identifiant requis'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Mot de passe requis'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? true),
                        activeColor: AppColors.brand,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Rester connecté',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.text)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showForgotPasswordHelp,
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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

  Widget _buildBiometricUnlock(AuthService auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.fingerprint, size: 46, color: AppColors.brand),
          const SizedBox(height: 12),
          Text(
            'Session verrouillée pour ${_usernameOrGeneric()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: AppColors.ink),
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null) ...[
            Text(_errorMessage!,
                style: const TextStyle(color: AppColors.redTx, fontSize: 12.5)),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _unlock(auth),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Connexion biométrique'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isSubmitting ? null : () => auth.logout(),
            child: const Text('Se connecter avec identifiant / mot de passe',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  String _usernameOrGeneric() => _usernameController.text.trim().isNotEmpty
      ? _usernameController.text.trim()
      : 'votre compte';

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
}
