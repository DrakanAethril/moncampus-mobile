import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// The app's navigation menu - deliberately minimal for now (just Accueil + Déconnexion). The web
/// app's navbar (templates/layout/app.html.twig) has many more sections (Messages, Bibliothèque,
/// Gestion, Paramètres...), but none of those screens exist in this mobile app yet - this drawer
/// is meant to grow alongside them rather than listing entries with nowhere to go.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.navy),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Text(
                  user?.initials ?? '?',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              accountName: Text(user?.greetingName ?? ''),
              accountEmail: Text(user?.email ?? user?.username ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Accueil'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Déconnexion'),
              onTap: () => context.read<AuthService>().logout(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
