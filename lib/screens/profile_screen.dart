import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Mon profil (design 3g/3j/3k) - identity, contact-email 3-state machine, password change.
/// Reachable from the header avatar (see AppHeader) or the "Plus" tab. No messaging preferences
/// here (README: "pas de préférences de messagerie sur mobile" - those stay on the web).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();

  final _newEmailController = TextEditingController();
  final _replacementEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showReplacementField = false;
  bool _emailBusy = false;
  bool _passwordBusy = false;
  String? _emailError;
  String? _passwordError;
  String? _passwordSuccess;

  @override
  void dispose() {
    _newEmailController.dispose();
    _replacementEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail(String? value) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _emailBusy = true;
      _emailError = null;
    });

    try {
      await _profileService.updateContactEmail(token, value);
      if (mounted) await context.read<AuthService>().refreshCurrentUser();
      if (mounted) {
        setState(() {
          _newEmailController.clear();
          _replacementEmailController.clear();
          _showReplacementField = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _emailError = e.toString());
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _emailBusy = true;
      _emailError = null;
    });

    try {
      await _profileService.resendContactEmailConfirmation(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lien de validation renvoyé.')));
      }
    } catch (e) {
      if (mounted) setState(() => _emailError = e.toString());
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _changePassword() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() =>
          _passwordError = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _passwordBusy = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      await _profileService.changePassword(
        token,
        newPassword: _newPasswordController.text,
        newPasswordConfirmation: _confirmPasswordController.text,
      );
      if (mounted) {
        setState(() {
          _passwordSuccess =
              'Votre demande a été enregistrée. Le nouveau mot de passe sera actif sous peu.';
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _passwordError = e.toString());
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              user: user,
              onAvatarTap: () {},
              child: AppHeaderTitleRow(
                  title: 'Mon profil',
                  onBack: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildIdentityCard(user),
                  const SizedBox(height: 12),
                  _buildEmailCard(user),
                  const SizedBox(height: 12),
                  _buildPasswordCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildIdentityCard(AppUser? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(user?.initials ?? '?',
                style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.greetingName ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    children: [
                      const TextSpan(text: 'Identifiant : '),
                      TextSpan(
                        text: user?.username ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard(AppUser? user) {
    if (user == null) return const SizedBox.shrink();

    if (user.contactEmail == null) return _buildEmailMissing();
    if (!user.contactEmailVerified) return _buildEmailPending(user);

    return _buildEmailVerified(user);
  }

  Widget _buildEmailMissing() {
    return _card(children: [
      const Text('Adresse e-mail de contact',
          style: TextStyle(
              fontFamily: 'Spectral',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink)),
      const SizedBox(height: 10),
      _note(
        "Aucune adresse définie. Ajoutez une adresse personnelle pour recevoir les notifications et récupérer votre mot de passe.",
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _newEmailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(hintText: 'votre.adresse@exemple.fr'),
      ),
      if (_emailError != null) ...[
        const SizedBox(height: 8),
        Text(_emailError!,
            style: const TextStyle(color: AppColors.redTx, fontSize: 12)),
      ],
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _emailBusy
              ? null
              : () => _submitEmail(_newEmailController.text.trim()),
          child: _emailBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Ajouter cette adresse'),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Un lien de validation vous sera envoyé (valable 24 h).',
          style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
    ]);
  }

  Widget _buildEmailPending(AppUser user) {
    return _card(children: [
      const Text('Adresse e-mail',
          style: TextStyle(
              fontFamily: 'Spectral',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink)),
      const SizedBox(height: 10),
      if (user.email != null)
        _addressRow(
            user.email!, 'vérifié', AppColors.greenBg, AppColors.greenTx),
      if (user.email != null) const SizedBox(height: 8),
      _addressRow(
          user.contactEmail!, 'en attente', AppColors.goldBg, AppColors.goldTx),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
            color: const Color(0xFFFDF8EE),
            border: Border.all(color: const Color(0xFFEAD9AE)),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: const BoxDecoration(
                  color: AppColors.gold, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('✉',
                  style: TextStyle(fontSize: 9, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lien de validation envoyé (valable 24 h).',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.warnTx,
                          height: 1.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _emailBusy ? null : _resendConfirmation,
                        child: const Text('Renvoyer',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.blueTx)),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _emailBusy ? null : () => _submitEmail(null),
                        child: const Text('Annuler',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.redTx)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_emailError != null) ...[
        const SizedBox(height: 8),
        Text(_emailError!,
            style: const TextStyle(color: AppColors.redTx, fontSize: 12)),
      ],
    ]);
  }

  Widget _buildEmailVerified(AppUser user) {
    return _card(children: [
      const Text('Adresse e-mail de contact',
          style: TextStyle(
              fontFamily: 'Spectral',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F8F5),
            border: Border.all(color: const Color(0xFFCFE2D6)),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                  color: Color(0xFF2E7D4F), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
            const SizedBox(width: 9),
            const Expanded(
                child: Text('Votre adresse a bien été validée.',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.greenTx))),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _addressRow(
          user.contactEmail!, 'vérifiée', AppColors.greenBg, AppColors.greenTx),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () =>
              setState(() => _showReplacementField = !_showReplacementField),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blueTx,
              side: const BorderSide(color: AppColors.border)),
          child: Text(
              'Définir une autre adresse ${_showReplacementField ? '▴' : '▾'}'),
        ),
      ),
      if (_showReplacementField) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _replacementEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration:
              const InputDecoration(hintText: 'nouvelle.adresse@exemple.fr'),
        ),
        if (_emailError != null) ...[
          const SizedBox(height: 8),
          Text(_emailError!,
              style: const TextStyle(color: AppColors.redTx, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _emailBusy
                ? null
                : () => _submitEmail(_replacementEmailController.text.trim()),
            child: _emailBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Envoyer le lien de validation'),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "L'adresse actuelle reste active tant que la nouvelle n'est pas validée.",
          style: TextStyle(fontSize: 11.5, color: AppColors.faint),
        ),
      ],
    ]);
  }

  Widget _addressRow(
      String address, String badge, Color badgeBg, Color badgeTx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
              child: Text(address,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: badgeBg, borderRadius: BorderRadius.circular(8)),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: badgeTx)),
          ),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.blueBg.withOpacity(.6),
          border:
              const Border(left: BorderSide(color: AppColors.brand, width: 3)),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11.5, color: AppColors.blueTx, height: 1.5)),
    );
  }

  Widget _buildPasswordCard() {
    return _card(children: [
      const Text('Mot de passe',
          style: TextStyle(
              fontFamily: 'Spectral',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink)),
      const SizedBox(height: 10),
      _note(
          '12 caractères min., majuscule, minuscule, chiffre et caractère spécial.'),
      const SizedBox(height: 10),
      TextField(
        controller: _newPasswordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _confirmPasswordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirmation'),
      ),
      if (_passwordError != null) ...[
        const SizedBox(height: 8),
        Text(_passwordError!,
            style: const TextStyle(color: AppColors.redTx, fontSize: 12)),
      ],
      if (_passwordSuccess != null) ...[
        const SizedBox(height: 8),
        Text(_passwordSuccess!,
            style: const TextStyle(color: AppColors.greenTx, fontSize: 12)),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _passwordBusy ? null : _changePassword,
          child: _passwordBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Changer le mot de passe'),
        ),
      ),
    ]);
  }
}
