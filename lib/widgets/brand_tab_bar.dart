import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// The four-tab bar of the whole app - Accueil · Emploi du t. · Travaux · Agenda (handoff,
/// principe 4: the internal messaging is gone and the Courrier école is never a tab).
///
/// A hand-built row rather than a [NavigationBar]: the reference has no pill indicator, a 22px
/// lucide outline whose stroke thickens from 2 to 2.2 on the active tab, and a 10px label - none
/// of which Material 3's navigation bar exposes.
class BrandTabBar extends StatelessWidget {
  const BrandTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = <({String icon, String label})>[
    (icon: AppIcons.home, label: 'Accueil'),
    (icon: AppIcons.calendar, label: 'Emploi du t.'),
    (icon: AppIcons.clipboardCheck, label: 'Travaux'),
    (icon: AppIcons.calendarDot, label: 'Agenda'),
  ];

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
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      _tabs[i].icon,
                      size: 22,
                      color:
                          i == currentIndex ? AppColors.brand : AppColors.faint,
                      strokeWidth: i == currentIndex ? 2.2 : 2,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tabs[i].label,
                      style: AppFont.sans(
                        size: 10,
                        weight: FontWeight.w600,
                        color: i == currentIndex
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
