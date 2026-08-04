import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'agenda_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'quiz_screen.dart';
import 'timetable_screen.dart';

/// The "direction retenue" (chosen direction) from the design: a 5-tab bottom navigation bar
/// replacing the old Drawer-only menu.
///
/// Accueil / Emploi du temps / Agenda / Quiz / Plus. Quiz took the slot Messages used to hold
/// (design_handoff_quiz, screen 1k): the messaging screens are all still in the codebase, they
/// simply have no entry point in the app for now - nothing links to MessagesScreen anymore.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // IndexedStack keeps every child mounted (so switching tabs doesn't lose scroll position/state),
  // but that also means every tab's initState() - and its data fetch - would fire at once on
  // login if all 5 were built up front. Building only the tabs actually visited so far avoids 4
  // simultaneous network calls the user hasn't asked for yet.
  final Set<int> _visitedIndices = {0};

  void _onDestinationSelected(int index) {
    setState(() {
      _index = index;
      _visitedIndices.add(index);
    });
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
          _visitedIndices.contains(3) ? const QuizScreen() : const SizedBox.shrink(),
          _visitedIndices.contains(4) ? const MoreScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        indicatorColor: AppColors.blueBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.brand),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.brand),
            label: 'Emploi du t.',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event, color: AppColors.brand),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz, color: AppColors.brand),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: AppColors.brand),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
