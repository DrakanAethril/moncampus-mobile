import 'dart:async';

import 'package:flutter/material.dart';

import '../services/magic_login_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';

/// Connexion par lien (design_handoff_mobile 6a then 6b), reached from "Mot de passe oublié ?".
///
/// One screen, two states: asking for the contact address, then confirming the link was sent with
/// a 60 s countdown before it can be asked again. There is no password reset anywhere in this flow
/// (principe 7) - a student without a contact address is sent to the établissement.
class MagicLoginScreen extends StatefulWidget {
  const MagicLoginScreen({super.key});

  @override
  State<MagicLoginScreen> createState() => _MagicLoginScreenState();
}

class _MagicLoginScreenState extends State<MagicLoginScreen> {
  static const _resendDelay = Duration(seconds: 60);

  final _service = MagicLoginService();
  final _emailController = TextEditingController();

  String? _maskedEmail;
  bool _sending = false;
  String? _error;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Indiquez votre mail de contact.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final masked = await _service.requestLink(email);
      if (!mounted) return;
      setState(() => _maskedEmail = masked);
      _startCountdown();
    } on MagicLoginException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de contacter le serveur.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandHero(
        child: _maskedEmail == null ? _requestCard() : _sentCard(),
      ),
    );
  }

  /// 6a.
  Widget _requestCard() {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: AppIcon(AppIcons.chevronLeft,
                      size: 16, color: AppColors.faint, strokeWidth: 2.2),
                ),
              ),
              Text('Connexion par lien',
                  style: AppFont.spectral(size: 17, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "Recevez un lien de connexion sur votre mail de contact : en l'ouvrant depuis ce téléphone, vous serez connecté automatiquement.",
            style: AppFont.sans(size: 13, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 15),
          Text('Mail de contact',
              style: AppFont.sans(
                  size: 13, weight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppFont.sans(size: 14.5, color: AppColors.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: _border(AppColors.border),
              enabledBorder: _border(AppColors.border),
              focusedBorder: _border(AppColors.brand),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: AppFont.sans(size: 12.5, color: AppColors.lateInk)),
          ],
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("M'envoyer un lien de connexion"),
          ),
          const SizedBox(height: 15),
          const _ContactFooter(question: 'Aucun mail de contact enregistré ?'),
        ],
      ),
    );
  }

  /// 6b.
  Widget _sentCard() {
    final canResend = _secondsLeft <= 0;

    return BrandCard(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: AppColors.blueSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.envelope,
                  size: 24, color: AppColors.brandStrong, strokeWidth: 1.8),
            ),
          ),
          const SizedBox(height: 13),
          Text('Lien envoyé',
              textAlign: TextAlign.center,
              style: AppFont.spectral(size: 17, color: AppColors.navy)),
          const SizedBox(height: 13),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Un lien de connexion a été envoyé à '),
                TextSpan(
                  text: _maskedEmail,
                  style: AppFont.sans(
                      size: 13, weight: FontWeight.w700, color: AppColors.ink),
                ),
                const TextSpan(
                    text: '.\nIl est valable 15 minutes et à usage unique.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: AppFont.sans(size: 13, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 13),
          OutlinedButton(
            onPressed: canResend && !_sending ? _send : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: canResend ? AppColors.surface : AppColors.surfaceAlt,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: Text(
              canResend
                  ? 'Renvoyer le lien'
                  : 'Renvoyer le lien · $_secondsLeft s',
              style: AppFont.sans(
                size: 13.5,
                weight: FontWeight.w600,
                color: canResend ? AppColors.brandStrong : AppColors.faint,
              ),
            ),
          ),
          const SizedBox(height: 13),
          const _ContactFooter(question: "Le mail n'arrive pas ?"),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
}

/// The card's ruled-off footer: the only way out when the mail never comes (principe 7).
class _ContactFooter extends StatelessWidget {
  const _ContactFooter({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$question\nContactez l\'établissement — '),
            TextSpan(
              text: '05 55 45 81 00',
              style: AppFont.sans(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: AppColors.brandStrong),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: AppFont.sans(size: 12.5, color: AppColors.muted, height: 1.6),
      ),
    );
  }
}
