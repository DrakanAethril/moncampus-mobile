import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/features.dart';
import '../screens/profile_screen.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'brand.dart';

/// State of the app bar's envelope button (Courrier pro) - the only entry point to the mailbox,
/// which is never a tab (handoff, principe 5).
enum MailButtonState {
  /// Screens that are not the mailbox, nothing unread.
  idle,

  /// Same, with the gold 9px dot - unread mail, student side only (4a/4b).
  unread,

  /// The mailbox itself (5a/5b): gold tile, and the avatar takes the translucent tile instead.
  active,

  /// Roles with no Courrier pro at all.
  hidden,
}

/// The brand app bar of every tab-root screen: medallion + logotype + "depuis 1634" between two
/// rules, then the envelope and the initials avatar (handoff, "Composants récurrents" and creas
/// 4a/4b/4d/5a/5b).
///
/// [title] adds the screen-title row below it ("Mon travail", "Courrier pro"), [titleTrailing]
/// the light-blue text at its right (the "Toutes les matières ▾" filter), and [filters] the row
/// of pills under that (En cours/Terminés, Reçus/Envoyés). [child] is the legacy slot still used
/// by the screens the mobile handoff does not cover (emploi du temps' week selector).
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.user,
    this.child,
    this.onAvatarTap,
    this.title,
    this.titleTrailing,
    this.filters,
    this.mail = MailButtonState.idle,
    this.onMailTap,
  });

  final AppUser? user;
  final Widget? child;
  final VoidCallback? onAvatarTap;
  final String? title;
  final Widget? titleTrailing;
  final Widget? filters;
  final MailButtonState mail;
  final VoidCallback? onMailTap;

  @override
  Widget build(BuildContext context) {
    final hasRowsBelow = title != null || filters != null || child != null;

    // The envelope follows the Courrier pro feature, decided here rather than at each of the
    // eight call sites: this widget already knows the user, and a rule spread over eight screens is
    // a rule that will be right on seven of them (moncampus design/validated/feature-access.md
    // §10.3).
    final resolvedMail = (user?.has(Features.schoolMail) ?? true)
        ? mail
        : MailButtonState.hidden;

    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
        18,
        // The creas' 58px top padding is the status bar plus a small gap; taking the real inset
        // keeps that gap identical on every device instead of guessing a notch height.
        MediaQuery.of(context).padding.top + 6,
        18,
        hasRowsBelow ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandMedallion.small(),
              const SizedBox(width: 11),
              const Flexible(child: BrandWordmark.appBar()),
              const SizedBox(width: 12),
              if (resolvedMail != MailButtonState.hidden) ...[
                _MailButton(state: resolvedMail, onTap: onMailTap),
                const SizedBox(width: 9),
              ],
              _Avatar(
                user: user,
                muted: resolvedMail == MailButtonState.active,
                onTap: onAvatarTap ??
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title!,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: AppFont.spectral(size: 17, color: Colors.white),
                ),
                if (titleTrailing != null)
                  // The title keeps its line whatever the trailing text is (a long student
                  // address, a filter label): the trailing side is what gets clipped.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: titleTrailing!,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (filters != null) ...[
            const SizedBox(height: 12),
            filters!,
          ],
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

class _MailButton extends StatelessWidget {
  const _MailButton({required this.state, required this.onTap});

  final MailButtonState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == MailButtonState.active;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active ? AppColors.gold : Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcons.envelope,
                size: 16,
                color: active ? AppColors.navy : Colors.white,
              ),
            ),
            if (state == MailButtonState.unread)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navy, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.muted, required this.onTap});

  final AppUser? user;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: muted ? Colors.white.withOpacity(.12) : AppColors.gold,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          user?.initials ?? '?',
          style: AppFont.sans(
            size: 12,
            weight: FontWeight.w700,
            color: muted ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

/// A row of header filter pills - active pill in gold, the others translucent (handoff,
/// "Filtres header"; creas 4d "En cours/Terminés" and 5b "Reçus · 2 / Envoyés").
class HeaderFilters extends StatelessWidget {
  const HeaderFilters({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: i == selectedIndex
                    ? AppColors.gold
                    : Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                labels[i],
                style: AppFont.sans(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: i == selectedIndex
                      ? AppColors.navy
                      : AppColors.headerLight,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The light-blue trailing text of a title row that opens a filter ("Toutes les matières ▾").
class HeaderFilterLabel extends StatelessWidget {
  const HeaderFilterLabel({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        '$label ▾',
        style: AppFont.sans(size: 12.5, color: AppColors.headerLight),
      ),
    );
  }
}

/// A pushed screen's second header row: "‹" back chevron + title, optional trailing widget - see
/// design 3g/3j/3k for the one-level-deep case that keeps the brand row above it.
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
              child: AppIcon(AppIcons.chevronLeft,
                  size: 18, color: AppColors.headerLight, strokeWidth: 2.2),
            ),
          ),
        Expanded(
          child: Text(
            title,
            style: AppFont.spectral(size: 17, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The compact navigation bar for screens pushed two levels deep from a tab root (creas 5c
/// "‹ Courrier pro", 5d "Annuler / Nouveau mail / Envoyer") - these deliberately drop the brand
/// row entirely rather than stack it under yet another header.
///
/// A plain widget, not a `Scaffold.appBar:` - that slot lays a `PreferredSizeWidget` out from
/// y=0 using only its own `preferredSize` for height, with no awareness of the status bar, so a
/// fixed-height custom bar there ends up partly hidden underneath it. Used instead as an ordinary
/// child inside the screen's own body, and it applies the status bar inset itself.
class AppNavBar extends StatelessWidget {
  const AppNavBar(
      {super.key,
      required this.title,
      this.leading,
      this.trailing,
      this.centerTitle = false});

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: AppFont.spectral(size: 17, color: Colors.white),
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
          18, MediaQuery.of(context).padding.top + 6, 18, 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          if (centerTitle) ...[
            Expanded(child: Center(child: titleText)),
          ] else
            Expanded(child: titleText),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
