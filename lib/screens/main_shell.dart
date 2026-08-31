import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/features.dart';
import '../services/auth_service.dart';
import '../services/school_mail_service.dart';
import '../widgets/brand_tab_bar.dart';
import 'agenda_screen.dart';
import 'course_space_screen.dart';
import 'home_screen.dart';
import 'quiz_screen.dart';
import 'school_mail_screen.dart';
import 'timetable_screen.dart';
import 'work_screen.dart';

/// The bottom-bar shell, **adaptive** since the feature system arrived (moncampus
/// design/validated/feature-access.md §10.2).
///
/// Four fixed tabs became a bar that keeps its available ones in order - Accueil · Emploi du temps ·
/// Travaux · Agenda - and **promotes** « Mes cours » then « Quiz » from the home screen's shortcut
/// tiles when a place frees, to a maximum of four. Accueil is never removed.
///
/// The Courrier pro is still never a tab (handoff, principe 5): it is the app bar's envelope, and
/// that envelope now disappears with its feature rather than with the ROLE_STUDENT check it used to
/// carry - which was always a rough stand-in for the same question.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  /// An index into the **stack**, not a tab position - the stack holds every screen the app can
  /// build, in a fixed order, so a tab appearing or disappearing renumbers nothing.
  int _index = 0;

  // IndexedStack keeps every child mounted (so switching tabs doesn't lose scroll position/state),
  // but that also means every tab's initState() - and its data fetch - would fire at once on
  // login if all of them were built up front. Building only the tabs actually visited so far
  // avoids simultaneous network calls the user hasn't asked for yet.
  final Set<int> _visitedIndices = {0};

  /// Drives the gold dot on the app bar's envelope. Read once when the shell mounts and refreshed
  /// on the way back from the mailbox.
  int _unreadMail = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The catalogue is re-read on every return to the foreground (moncampus
  /// design/validated/feature-access.md §10.1).
  ///
  /// It is what makes a switch-off reach an app that is already open, and it is the answer to the
  /// awkward half of §8.7: a JWT issued before the change stays valid, so the app keeps working and
  /// would otherwise go on showing a tab whose endpoint has started answering 404 until the next
  /// cold start. A profile call on resume costs one request and closes that window.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final auth = context.read<AuthService>();
    if (auth.token == null) return;

    // Failure is silence: the app keeps the catalogue it has. Logging somebody out because their
    // phone came back from sleep on a dead network would be a far worse answer than a list that is
    // a few minutes old.
    auth.refreshCurrentUser().then((_) {
      if (mounted) _refreshUnread();
    }).catchError((_) {});
  }

  Future<void> _refreshUnread() async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;
    // The feature rather than ROLE_STUDENT, which is what this line always meant: the Courrier
    // école is decided per formation, so two students of the same class can differ, and a role
    // could never have said so. It also covers the individual derogation (§3.5) for free.
    if (!(auth.currentUser?.has(Features.schoolMail) ?? false)) return;

    try {
      final mailbox =
          await SchoolMailService().fetchFolder(token, sent: false);
      if (mounted) setState(() => _unreadMail = mailbox.unread);
    } catch (_) {
      // A mailbox that cannot be read simply shows no dot - including the 404 of a feature that
      // was switched off since this token was issued (§8.7). Not an error to put in front of
      // anybody: the envelope itself is already gone on the next profile refresh.
    }
  }

  void _select(int stackIndex) {
    setState(() {
      _index = stackIndex;
      _visitedIndices.add(stackIndex);
    });
  }

  Future<void> _openMail() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SchoolMailScreen(),
    ));
    await _refreshUnread();
  }

  /// The bar this account gets, in order, capped at four.
  ///
  /// Accueil, then whichever of the three original tabs still exist, then the two promoted from the
  /// home screen's tiles to fill what is left. With the defaults of §4 - no timetable, no agenda, no
  /// course space - that is Accueil · Travaux · Quiz.
  List<BrandTab> _tabsFor(AppUser? user) {
    final available = <BrandTab>[
      BrandTabBar.home,
      if (user?.has(Features.timetable) ?? true) BrandTabBar.timetable,
      if (user?.has(Features.studentWork) ?? true) BrandTabBar.work,
      if (user?.has(Features.agenda) ?? true) BrandTabBar.agenda,
      if (user?.has(Features.courseSpace) ?? true) BrandTabBar.courses,
      if (user?.has(Features.quizTake) ?? true) BrandTabBar.quiz,
    ];

    return available.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final tabs = _tabsFor(user);
    final promoted = tabs.map((tab) => tab.stackIndex).toSet();
    final hasMail = user?.has(Features.schoolMail) ?? false;

    // A tab that disappears under the finger - an administrator switching a feature off while the
    // app is open - would otherwise leave the bar highlighting nothing and the stack showing a
    // screen with no way back. Falling to Accueil is the one landing that always exists.
    final current = promoted.contains(_index) ? _index : 0;

    return Scaffold(
      body: IndexedStack(
        index: current,
        children: [
          HomeScreen(
            onViewTimetable: () => _select(BrandTabBar.timetable.stackIndex),
            onViewWork: () => _select(BrandTabBar.work.stackIndex),
            onOpenMail: hasMail ? _openMail : null,
            hasUnreadMail: _unreadMail > 0,
            // The tiles the bar has taken over: showing « Quiz » as a tile *and* as a tab would be
            // two doors to one screen, which is how somebody ends up on the wrong one.
            showCoursesTile: !promoted.contains(BrandTabBar.courses.stackIndex),
            showQuizTile: !promoted.contains(BrandTabBar.quiz.stackIndex),
          ),
          _mounted(BrandTabBar.timetable.stackIndex, const TimetableScreen()),
          _mounted(
            BrandTabBar.work.stackIndex,
            WorkScreen(
              onOpenMail: hasMail ? _openMail : null,
              hasUnreadMail: _unreadMail > 0,
            ),
          ),
          _mounted(BrandTabBar.agenda.stackIndex, const AgendaScreen()),
          _mounted(BrandTabBar.courses.stackIndex, const CourseSpaceScreen()),
          _mounted(BrandTabBar.quiz.stackIndex, const QuizScreen()),
        ],
      ),
      bottomNavigationBar: BrandTabBar(
        tabs: tabs,
        currentStackIndex: current,
        onSelected: _select,
      ),
    );
  }

  /// A screen is only built once its tab has actually been opened - see [_visitedIndices].
  Widget _mounted(int stackIndex, Widget screen) =>
      _visitedIndices.contains(stackIndex) ? screen : const SizedBox.shrink();
}
