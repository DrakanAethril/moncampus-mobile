import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The institution medallion: blue disc, cream ring, white emblem. Used at 38px in the app bar,
/// 104px on the connexion screens (4e/6a-6d), 112px on the launch screen (4f).
class BrandMedallion extends StatelessWidget {
  const BrandMedallion({
    super.key,
    required this.size,
    required this.ringWidth,
    this.shadow,
  });

  /// App bar (4a/4b/4d/5a/5b).
  const BrandMedallion.small({super.key})
      : size = 38,
        ringWidth = 2.5,
        shadow = null;

  final double size;
  final double ringWidth;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    // The emblem keeps its 166x215 aspect ratio; the creas size it at 16x21 inside a 38px
    // medallion, i.e. width = 42% of the disc.
    final emblemWidth = size * 16 / 38;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: ringWidth),
        boxShadow: shadow,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/brand/embleme-white.png',
        width: emblemWidth,
        height: emblemWidth * 215 / 166,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// "Institution Beaupeyrat" over "depuis 1634" in gold small-caps between two gold rules.
///
/// [stretchRules] is the app bar variant, where the rules stretch to the logotype's width; the
/// connexion/launch variant uses two fixed 26px rules centred under the name.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    required this.nameSize,
    required this.vintageSize,
    required this.letterSpacing,
    this.stretchRules = false,
  });

  const BrandWordmark.appBar({super.key})
      : nameSize = 14,
        vintageSize = 9,
        letterSpacing = 1.5,
        stretchRules = true;

  const BrandWordmark.hero({super.key})
      : nameSize = 20,
        vintageSize = 10,
        letterSpacing = 2.4,
        stretchRules = false;

  final double nameSize;
  final double vintageSize;
  final double letterSpacing;
  final bool stretchRules;

  @override
  Widget build(BuildContext context) {
    final vintage = Text(
      'DEPUIS 1634',
      style: AppFont.sans(
        size: vintageSize,
        weight: stretchRules ? FontWeight.w400 : FontWeight.w600,
        color: AppColors.gold,
        letterSpacing: letterSpacing,
      ),
    );

    // IntrinsicWidth so the app bar variant's rules stretch to the logotype's own width, as in the
    // reference - inside a Row they would otherwise take every pixel left of the envelope.
    final column = Column(
      crossAxisAlignment:
          stretchRules ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Institution Beaupeyrat',
          style: AppFont.spectral(
            size: nameSize,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        SizedBox(height: stretchRules ? 2 : 5),
        Row(
          mainAxisSize: stretchRules ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _rule(stretchRules),
            SizedBox(width: stretchRules ? 6 : 8),
            // The trailing letter-spacing of the last glyph would otherwise push the text off
            // centre between the two rules.
            Padding(
              padding: EdgeInsets.only(left: letterSpacing),
              child: vintage,
            ),
            SizedBox(width: stretchRules ? 6 : 8),
            _rule(stretchRules),
          ],
        ),
      ],
    );

    return stretchRules ? IntrinsicWidth(child: column) : column;
  }

  Widget _rule(bool stretch) {
    const rule = SizedBox(height: 1, child: ColoredBox(color: AppColors.gold));
    return stretch
        ? const Expanded(child: rule)
        : const SizedBox(width: 26, child: rule);
  }
}

/// Gradient backdrop shared by connexion (4e) and the magic-link screens (6a-6d):
/// `linear-gradient(170deg,#12344d 0%,#1B6BA8 55%,#f2f5f8 55%,#f2f5f8 100%)`, then the medallion
/// and logotype, then [child] in a 22px gutter.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // 170deg in CSS is 10 degrees off vertical, hence the slight horizontal offset.
          begin: Alignment(-0.18, -1),
          end: Alignment(0.18, 1),
          colors: [AppColors.navy, AppColors.brand, AppColors.bg, AppColors.bg],
          stops: [0, 0.55, 0.55, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 44),
                    const BrandMedallion(
                      size: 104,
                      ringWidth: 5,
                      shadow: [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 34,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const BrandWordmark.hero(),
                    const SizedBox(height: 34),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: child,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: 14 + MediaQuery.of(context).padding.bottom,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// The white card used on every hero screen (login form, magic-link steps).
class BrandCard extends StatelessWidget {
  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2412344D),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
