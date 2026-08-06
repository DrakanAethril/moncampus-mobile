import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The list behind a header filter ("Toutes les matières" / "Toutes les classes"). Returns the
/// index of the chosen label, or null when the sheet is dismissed.
Future<int?> showSheetPicker(
  BuildContext context, {
  required List<String> labels,
  required int selectedIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
          bottom: 12 + MediaQuery.of(context).padding.bottom, top: 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < labels.length; i++)
            ListTile(
              title: Text(
                labels[i],
                style: AppFont.sans(
                  size: 14,
                  weight:
                      i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
                  color: i == selectedIndex
                      ? AppColors.brandStrong
                      : AppColors.ink,
                ),
              ),
              onTap: () => Navigator.of(context).pop(i),
            ),
        ],
      ),
    ),
  );
}
