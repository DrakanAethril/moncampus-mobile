import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import 'agenda_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'more_screen.dart';
import 'timetable_screen.dart';

/// The "direction retenue" (chosen direction) from the design: a 5-tab bottom navigation bar
/// (Accueil / Emploi du temps / Agenda / Messages / Plus) replacing the old Drawer-only menu.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _unreadCount = 0;
  final _messagingService = MessagingService();

  // IndexedStack keeps every child mounted (so switching tabs doesn't lose scroll position/state),
  // but that also means every tab's initState() - and its data fetch - would fire at once on
  // login if all 5 were built up front. Building only the tabs actually visited so far avoids 4
  // simultaneous network calls the user hasn't asked for yet.
  final Set<int> _visitedIndices = {0};

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final count = await _messagingService.fetchUnreadCount(token);
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Silent - the badge just doesn't update, not worth surfacing an error for a background refresh.
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _index = index;
      _visitedIndices.add(index);
    });
    if (index == 3) {
      _refreshUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onViewTimetable: () => _onDestinationSelected(1),
            onViewAgenda: () => _onDestinationSelected(2),
          ),
          _visitedIndices.contains(1) ? const TimetableScreen() : const SizedBox.shrink(),
          _visitedIndices.contains(2) ? const AgendaScreen() : const SizedBox.shrink(),
          _visitedIndices.contains(3) ? MessagesScreen(onUnreadChanged: _refreshUnreadCount) : const SizedBox.shrink(),
          _visitedIndices.contains(4) ? const MoreScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        indicatorColor: AppColors.blueBg,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.brand),
            label: 'Accueil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.brand),
            label: 'Emploi du t.',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event, color: AppColors.brand),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: _unreadCount > 0
                ? Badge(label: Text('$_unreadCount'), backgroundColor: AppColors.gold, textColor: AppColors.navy, child: const Icon(Icons.mail_outline))
                : const Icon(Icons.mail_outline),
            selectedIcon: _unreadCount > 0
                ? Badge(label: Text('$_unreadCount'), backgroundColor: AppColors.gold, textColor: AppColors.navy, child: const Icon(Icons.mail, color: AppColors.brand))
                : const Icon(Icons.mail, color: AppColors.brand),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: AppColors.brand),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
