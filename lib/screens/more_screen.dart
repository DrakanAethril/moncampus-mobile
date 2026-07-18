import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'profile_screen.dart';

/// "Plus" tab (5th tab bar destination) - takes over what the old Drawer held (user identity +
/// déconnexion) now that the tab bar is the app's primary navigation.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return SafeArea(
      child: Column(
        children: [
          AppHeader(user: user),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.gold,
                          child: Text(
                            user?.initials ?? '?',
                            style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.greetingName ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.ink),
                              ),
                              if (user?.email != null)
                                Text(user!.email!,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline,
                        color: AppColors.brand),
                    title: const Text('Mon profil',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.ink)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.border),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<AuthService>().logout(),
                icon: const Icon(Icons.logout, color: AppColors.redTx),
                label: const Text('Déconnexion',
                    style: TextStyle(color: AppColors.redTx)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
