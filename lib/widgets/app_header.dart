import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

/// The brand header shared by every tab-root screen and one-level-deep pushed screens (design 3a:
/// navy bar, white "B" logo, "Institution Beaupeyrat / depuis 1634", gold square avatar - no
/// notification bell). Tapping the avatar always opens [ProfileScreen] unless a screen overrides
/// [onAvatarTap]. [child], when given, is a second row below the brand row (week selector, folder
/// chips, or an [AppHeaderTitleRow] for a pushed screen's title+back) - see that class's docblock
/// for why two-level-deep screens (compose, message detail) use [AppNavBar] instead of this.
class AppHeader extends StatelessWidget {
  const AppHeader(
      {super.key, required this.user, this.child, this.onAvatarTap});

  final AppUser? user;
  final Widget? child;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(18, 12, 18, child == null ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Text('B',
                    style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Institution Beaupeyrat',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text('depuis 1634',
                      style: TextStyle(
                          color: Color(0xFF7D99B0),
                          fontSize: 10,
                          letterSpacing: .5)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAvatarTap ??
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

/// A pushed screen's second header row: "‹" back chevron + title, optional trailing widget (e.g.
/// message detail's trash icon) - see design 3g/3j/3k for the one-level-deep case that keeps the
/// brand row above it.
class AppHeaderTitleRow extends StatelessWidget {
  const AppHeaderTitleRow(
      {super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          GestureDetector(
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text('‹',
                  style: TextStyle(
                      fontSize: 19,
                      color: Color(0xFFCFDDE9),
                      fontWeight: FontWeight.w600)),
            ),
          ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The compact navigation bar for screens pushed two levels deep from a tab root (design 3h
/// compose: "Annuler … Envoyer", 3i message detail: "‹ … 🗑") - these deliberately drop the brand
/// row entirely rather than stack it under yet another header, matching the reference mockups
/// (unlike 3g/3j/3k's profile screens, which are only one level deep and keep the brand row via
/// [AppHeader]).
///
/// A plain widget, not a `Scaffold.appBar:` - that slot lays a `PreferredSizeWidget` out from
/// y=0 using only its own `preferredSize` for height, with no awareness of the status bar, so a
/// fixed-height custom bar there ends up partly hidden underneath it (its content clipped by the
/// system status bar - this bit the "Envoyer"/back-chevron rows before). Used instead as an
/// ordinary child inside the screen's own `SafeArea`, same as [AppHeader] everywhere else in the
/// app, so it's pushed down by the real inset instead of a guessed one.
class AppNavBar extends StatelessWidget {
  const AppNavBar(
      {super.key, required this.title, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: Text(
              title,
              textAlign: leading != null && trailing != null
                  ? TextAlign.center
                  : TextAlign.left,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
