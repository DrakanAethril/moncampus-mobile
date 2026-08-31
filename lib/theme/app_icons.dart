import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The handoff's icons, as the literal SVG bodies of the creas
/// (design_handoff_mobile/creas/Campus-Manager-Mobile.dc.html). They are lucide-style outlines -
/// "pas de Material Icons pleins" (handoff, "Notes d'implémentation Flutter") - and the same
/// glyph is drawn at different stroke widths depending on the screen (2 inactive / 2.2 active in
/// the tab bar, 1.8 for the big circled illustrations), which a font-based icon set cannot do.
/// Hence rendering the paths themselves through [AppIcon].
class AppIcons {
  /// Tab bar - Accueil.
  static const home = '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>';

  /// Tab bar - Emploi du t.
  static const calendar =
      '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/>';

  /// Tab bar - Travaux (clipboard + check).
  static const clipboardCheck =
      '<rect x="5" y="4.5" width="14" height="17" rx="2.5"/><path d="M9 4.5V3h6v1.5"/><path d="m9 13.5 2.2 2.2 4-4.4"/>';

  /// Tab bar - « Mes cours », when the space freed by a switched-off feature promotes it from a
  /// home-screen tile to a tab (open book).
  static const bookOpen =
      '<path d="M2 4.5h6a3 3 0 0 1 3 3V20a2.5 2.5 0 0 0-2.5-2.5H2Z"/>'
      '<path d="M22 4.5h-6a3 3 0 0 0-3 3V20a2.5 2.5 0 0 1 2.5-2.5H22Z"/>';

  /// Tab bar - « Quiz », promoted the same way (question mark in a circle).
  static const questionCircle =
      '<circle cx="12" cy="12" r="9"/>'
      '<path d="M9.6 9.6a2.4 2.4 0 1 1 3.3 2.2c-.6.3-.9.8-.9 1.4v.3"/>'
      '<path d="M12 17v.01"/>';

  /// Tab bar - Agenda (calendar with a dot).
  static const calendarDot =
      '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/><circle cx="12" cy="15.5" r="2" fill="currentColor" stroke="none"/>';

  /// App bar - Courrier pro.
  static const envelope =
      '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>';

  static const chevronLeft = '<path d="m15 5-7 7 7 7"/>';
  static const close = '<path d="m6 6 12 12M18 6 6 18"/>';

  /// "Dépôt sur le web" pill (4c) - a laptop.
  static const laptop =
      '<rect x="2.5" y="4.5" width="19" height="13" rx="2"/><path d="M8 20.5h8"/>';

  /// Courrier pro, boîte non activée (5a).
  static const lock =
      '<rect x="4" y="10" width="16" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>';

  static const paperclip =
      '<path d="m21.4 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/>';

  /// FAB "nouveau mail" (5b).
  static const pencil =
      '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>';

  static const reply =
      '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 6 6v3"/>';

  static const send = '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>';

  /// Connexion automatique (6c).
  static const check = '<path d="m5 12.5 4.5 4.5L19 7.5"/>';

  /// Lien expiré (6d).
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';

  /// Relais biométrique (6c) - deliberately generic: never "Face ID" / "Touch ID" (handoff,
  /// principe 8).
  static const fingerprint = '<path d="M12 4a8 8 0 0 1 8 8c0 2.5-.5 4.9-1.4 7"/>'
      '<path d="M4.6 9A8 8 0 0 1 8 5.1"/>'
      '<path d="M12 8a4 4 0 0 1 4 4c0 2.2-.4 4.3-1.1 6.2"/>'
      '<path d="M8.2 11.2A4 4 0 0 0 8 12c0 2.6-.7 5-1.9 7"/>'
      '<path d="M12 12c0 2.9-.8 5.6-2.2 8"/>';

  /// Password show/hide toggle on the login card. The crea draws a 👁 emoji there; an outline
  /// glyph is used instead so the control matches the rest of the icon set.
  static const eye =
      '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>';

  static const eyeOff =
      '<path d="M10.6 6.2A9.8 9.8 0 0 1 12 6c6.4 0 10 7 10 7a17 17 0 0 1-3 3.9"/>'
      '<path d="M6.6 7.7A17 17 0 0 0 2 13s3.6 7 10 7a9.6 9.6 0 0 0 4.5-1.1"/>'
      '<path d="M3 3l18 18"/>';

  /// Chevron shown at the right of a list row - the crea uses a "›" text glyph, kept as text in
  /// the widgets so its optical weight matches the reference exactly.
  static const chevronRight = '<path d="m9 5 7 7-7 7"/>';
}

/// Renders one of [AppIcons]' path bodies at an arbitrary size, colour and stroke width.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 2,
  });

  final String icon;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // `currentColor` inside a body (the agenda dot's fill) resolves against the root `color`
    // attribute, so both stroke and fill follow [color] with a single substitution.
    final hex =
        '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
      'viewBox="0 0 24 24" fill="none" color="$hex" stroke="$hex" '
      'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">'
      '$icon</svg>',
      width: size,
      height: size,
    );
  }
}
