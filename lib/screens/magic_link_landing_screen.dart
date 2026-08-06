import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/magic_login_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'magic_login_screen.dart';

/// Where a mailed link lands (design_handoff_mobile 6c/6d): the token is traded for a session
/// straight away, then the biometric relay is offered - or, if the link is no longer valid, the
/// way to ask for a new one.
class MagicLinkLandingScreen extends StatefulWidget {
  const MagicLinkLandingScreen({super.key, required this.token});

  final String token;

  @override
  State<MagicLinkLandingScreen> createState() => _MagicLinkLandingScreenState();
}

class _MagicLinkLandingScreenState extends State<MagicLinkLandingScreen> {
  final _service = MagicLoginService();

  bool _expired = false;
  bool _unreachable = false;
  bool _busy = true;
  String? _firstname;
  bool _biometricsOffered = false;

  @override
  void initState() {
    super.initState();
    _consume();
  }

  Future<void> _consume() async {
    final auth = context.read<AuthService>();

    try {
      final result = await _service.consume(widget.token);
      await auth.adoptToken(result.token);
      if (!mounted) return;

      final canUseBiometrics = await auth.canUseBiometrics;
      if (!mounted) return;

      setState(() {
        _firstname = result.firstname;
        // Nothing to offer on a device without biometrics: the session is already open, so the
        // screen just closes itself.
        _biometricsOffered = canUseBiometrics && !auth.biometricEnabled;
        _busy = false;
      });

      if (!_biometricsOffered) _close();
    } on MagicLinkExpiredException {
      if (mounted) {
        setState(() {
          _expired = true;
          _busy = false;
        });
      }
    } catch (_) {
      // A link that could not be checked at all is not an expired link: saying so would send the
      // student asking for another one that would fail the same way.
      if (mounted) {
        setState(() {
          _unreachable = true;
          _busy = false;
        });
      }
    }
  }

  void _close() {
    // AuthGate already shows the app shell once the session is open - this screen only has to get
    // out of the way.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandHero(
        child: _busy
            ? const BrandCard(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _unreachable
                ? _unreachableCard()
                : _expired
                    ? _expiredCard()
                    : _welcomeCard(),
      ),
    );
  }

  /// 6c.
  Widget _welcomeCard() {
    final greeting = _firstname == null || _firstname!.isEmpty
        ? 'Vous êtes connecté'
        : 'Bonjour $_firstname, vous êtes connecté';

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
                  color: AppColors.donePillBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.check,
                  size: 26, color: AppColors.doneInk, strokeWidth: 2.2),
            ),
          ),
          const SizedBox(height: 13),
          Text(greeting,
              textAlign: TextAlign.center,
              style: AppFont.spectral(size: 17, color: AppColors.navy)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.only(top: 15),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.rule)),
            ),
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
                        size: 24,
                        color: AppColors.brandStrong,
                        strokeWidth: 1.8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Activez la connexion biométrique pour ouvrir l'app sans lien ni mot de passe la prochaine fois.",
                  textAlign: TextAlign.center,
                  style: AppFont.sans(
                      size: 13, color: AppColors.muted, height: 1.6),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await context.read<AuthService>().setBiometricEnabled(true);
                    if (mounted) _close();
                  },
                  child: const Text('Activer la biométrie'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _close,
                  child: Text('Plus tard',
                      textAlign: TextAlign.center,
                      style: AppFont.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.faint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The server could not be reached - same layout as 6d, but it does not blame the link.
  Widget _unreachableCard() {
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
                  color: AppColors.goldSurface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.clock,
                  size: 24, color: AppColors.goldInk, strokeWidth: 1.8),
            ),
          ),
          const SizedBox(height: 13),
          Text('Connexion impossible',
              textAlign: TextAlign.center,
              style: AppFont.spectral(size: 17, color: AppColors.navy)),
          const SizedBox(height: 13),
          Text('Le serveur est injoignable. Réessayez dans un instant.',
              textAlign: TextAlign.center,
              style:
                  AppFont.sans(size: 13, color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: _close,
            child: Text('Revenir à la connexion',
                textAlign: TextAlign.center,
                style: AppFont.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong)),
          ),
        ],
      ),
    );
  }

  /// 6d.
  Widget _expiredCard() {
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
                  color: AppColors.goldSurface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.clock,
                  size: 24, color: AppColors.goldInk, strokeWidth: 1.8),
            ),
          ),
          const SizedBox(height: 13),
          Text("Ce lien n'est plus valable",
              textAlign: TextAlign.center,
              style: AppFont.spectral(size: 17, color: AppColors.navy)),
          const SizedBox(height: 13),
          Text('Il a expiré ou a déjà été utilisé.',
              textAlign: TextAlign.center,
              style:
                  AppFont.sans(size: 13, color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 13),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const MagicLoginScreen(),
              ));
            },
            child: const Text('Recevoir un nouveau lien'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _close,
            child: Text('Revenir à la connexion',
                textAlign: TextAlign.center,
                style: AppFont.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong)),
          ),
        ],
      ),
    );
  }
}
