import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/school_mail_service.dart';
import '../widgets/brand_tab_bar.dart';
import 'agenda_screen.dart';
import 'home_screen.dart';
import 'school_mail_screen.dart';
import 'timetable_screen.dart';
import 'work_screen.dart';

/// The four tabs of the app - Accueil · Emploi du t. · Travaux · Agenda (design_handoff_mobile,
/// principe 4). The internal messaging left the app with the fifth tab, and the Courrier école is
/// reached from the app bar's envelope, never from here (principe 5).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // IndexedStack keeps every child mounted (so switching tabs doesn't lose scroll position/state),
  // but that also means every tab's initState() - and its data fetch - would fire at once on
  // login if all of them were built up front. Building only the tabs actually visited so far
  // avoids simultaneous network calls the user hasn't asked for yet.
  final Set<int> _visitedIndices = {0};

  /// Drives the gold dot on the app bar's envelope. Read once when the shell mounts and refreshed
  /// on the way back from the mailbox - the students' box is the only one that has unread mail.
  int _unreadMail = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;
    if (!(auth.currentUser?.roles.contains('ROLE_STUDENT') ?? false)) return;

    try {
      final mailbox =
          await SchoolMailService().fetchFolder(token, sent: false);
      if (mounted) setState(() => _unreadMail = mailbox.unread);
    } catch (_) {
      // A mailbox that cannot be read simply shows no dot.
    }
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _visitedIndices.add(index);
    });
  }

  Future<void> _openMail() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SchoolMailScreen(),
    ));
    await _refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onViewTimetable: () => _select(1),
            onViewWork: () => _select(2),
            onOpenMail: _openMail,
            hasUnreadMail: _unreadMail > 0,
          ),
          _visitedIndices.contains(1)
              ? const TimetableScreen()
              : const SizedBox.shrink(),
          _visitedIndices.contains(2)
              ? WorkScreen(
                  onOpenMail: _openMail, hasUnreadMail: _unreadMail > 0)
              : const SizedBox.shrink(),
          _visitedIndices.contains(3)
              ? const AgendaScreen()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar:
          BrandTabBar(currentIndex: _index, onSelected: _select),
    );
  }
}
