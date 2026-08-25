import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// One entry of the bottom bar - what it shows, and which screen of [MainShell]'s stack it is.
///
/// [stackIndex] is not the tab's position: the stack keeps every screen the app can build, in a
/// fixed order, and the bar draws a subset of it. Separating the two is what lets a tab appear or
/// disappear without the screens behind it renumbering themselves.
class BrandTab {
  const BrandTab({
    required this.icon,
    required this.label,
    required this.stackIndex,
  });

  final String icon;
  final String label;
  final int stackIndex;
}

/// The bottom bar of the whole app - **adaptive** since the feature system arrived (moncampus
/// design/validated/feature-access.md §10.2).
///
/// It used to be four fixed tabs: Accueil · Emploi du t. · Travaux · Agenda. The rule now is that
/// the bar keeps its available tabs in that order and **promotes** « Mes cours », then « Quiz »,
/// from the home screen's shortcut tiles whenever a place frees up, to a maximum of four. Accueil
/// is never removed.
///
/// Principe 4 of the handoff is respected in the sense that counts: the bar is full of what exists.
/// With the defaults this establishment is delivered with - no timetable, no agenda, no course
/// space - it shows **Accueil · Travaux · Quiz**, three tabs, and that is the honest picture rather
/// than four tabs one of which answers 404.
///
/// A hand-built row rather than a [NavigationBar]: the reference has no pill indicator, a 22px
/// lucide outline whose stroke thickens from 2 to 2.2 on the active tab, and a 10px label - none of
/// which Material 3's navigation bar exposes.
class BrandTabBar extends StatelessWidget {
  const BrandTabBar({
    super.key,
    required this.tabs,
    required this.currentStackIndex,
    required this.onSelected,
  });

  final List<BrandTab> tabs;
  final int currentStackIndex;

  /// Answers a **stack** index, not a tab position - see [BrandTab.stackIndex].
  final ValueChanged<int> onSelected;

  /// The five screens the bar can ever show, in the order it shows them. Accueil first and always;
  /// then the three original tabs; then the two promoted from the home screen's tiles, in the order
  /// §10.2 names.
  static const home = BrandTab(icon: AppIcons.home, label: 'Accueil', stackIndex: 0);
  static const timetable = BrandTab(icon: AppIcons.calendar, label: 'Emploi du t.', stackIndex: 1);
  static const work = BrandTab(icon: AppIcons.clipboardCheck, label: 'Travaux', stackIndex: 2);
  static const agenda = BrandTab(icon: AppIcons.calendarDot, label: 'Agenda', stackIndex: 3);
  static const courses = BrandTab(icon: AppIcons.bookOpen, label: 'Mes cours', stackIndex: 4);
  static const quiz = BrandTab(icon: AppIcons.questionCircle, label: 'Quiz', stackIndex: 5);

  @override
  Widget build(BuildContext context) {
    // The creas' 24px bottom padding is the iPhone home indicator; on a device without one the
    // 8px of the row itself is enough.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(6, 8, 6, bottomInset > 0 ? bottomInset : 10),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(tab.stackIndex),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      tab.icon,
                      size: 22,
                      color: tab.stackIndex == currentStackIndex
                          ? AppColors.brand
                          : AppColors.faint,
                      strokeWidth: tab.stackIndex == currentStackIndex ? 2.2 : 2,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: AppFont.sans(
                        size: 10,
                        weight: FontWeight.w600,
                        color: tab.stackIndex == currentStackIndex
                            ? AppColors.brand
                            : AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
