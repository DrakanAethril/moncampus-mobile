import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Agenda tab (design 3d) - deliberately a placeholder, not a reskinned mock-up with fake events.
/// There is no Event/Agenda entity anywhere on the backend (unlike the timetable and messaging
/// tabs, which reuse real, already-existing data) - building this screen for real means designing
/// and shipping that backend feature first. See [[project_mobile_app_ldap_jwt_progress]].
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: const Text('Agenda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
          ),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined, size: 48, color: AppColors.faint),
                    SizedBox(height: 16),
                    Text(
                      'Bientôt disponible',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "L'agenda des événements de l'établissement arrivera dans une prochaine mise à jour.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
