import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/lesson_session.dart';
import '../models/quiz_live_state.dart';
import '../models/work_item.dart';
import '../services/auth_service.dart';
import '../services/quiz_live_service.dart';
import '../services/quiz_service.dart';
import '../services/timetable_service.dart';
import '../services/work_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import '../widgets/work_detail_sheet.dart';
import 'quiz_live_join_screen.dart';
import 'quiz_take_screen.dart';

/// Accueil (design_handoff_mobile 4a): the date and the greeting, the next class, the "Travaux"
/// block - the closest deadlines first - and "Ma journée".
///
/// The live-contest banner is the one thing on this screen the handoff does not draw: the
/// multiplayer contest has no tab of its own since the menu went down to four, and it is only
/// worth an entry point while a session is actually open, so it appears here only then.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onViewTimetable,
    this.onViewWork,
    this.onOpenMail,
    this.hasUnreadMail = false,
  });

  final VoidCallback? onViewTimetable;
  final VoidCallback? onViewWork;
  final VoidCallback? onOpenMail;
  final bool hasUnreadMail;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _timetableService = TimetableService();
  final _quizLiveService = QuizLiveService();
  final _workService = WorkService();

  List<LessonSession>? _todaySessions;
  QuizLiveActiveSession? _activeLiveSession;
  WorkBoard? _board;
  bool _loading = true;

  /// How many travaux the home block holds before sending on to the Travaux tab.
  static const _workPreviewCount = 3;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final auth = context.read<AuthService>();
    final token = auth.token;
    if (token == null) return;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final isStudent = auth.currentUser?.roles.contains('ROLE_STUDENT') ?? false;

    setState(() => _loading = true);

    // Independent widgets, independent failures - one card not loading shouldn't blank the
    // others (unlike TimetableScreen's single-source dependency).
    final results = await Future.wait([
      _timetableService
          .fetchWeek(token, from: monday, to: sunday)
          .catchError((_) => <LessonSession>[]),
      _quizLiveService.fetchActive(token).catchError((_) => null),
      if (isStudent)
        _workService
            .fetchStudentBoard(token)
            .catchError((_) => const WorkBoard(items: [], subjects: [])),
    ]);

    if (!mounted) return;

    final today = DateTime(now.year, now.month, now.day);
    final todaySessions = (results[0] as List<LessonSession>)
        .where((session) => FrenchDate.isSameDay(session.day, today))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    setState(() {
      _todaySessions = todaySessions;
      _activeLiveSession = results[1] as QuizLiveActiveSession?;
      _board = isStudent ? results[2] as WorkBoard : null;
      _loading = false;
    });
  }

  LessonSession? get _nextSession {
    final sessions = _todaySessions;
    if (sessions == null) return null;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    for (final session in sessions) {
      final parts = session.endTime.split(':');
      final endMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (endMinutes >= nowMinutes) return session;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final work = _board?.items ?? const <WorkItem>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            user: user,
            mail: widget.hasUnreadMail
                ? MailButtonState.unread
                : MailButtonState.idle,
            onMailTap: widget.onOpenMail,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadToday,
              color: AppColors.brand,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Greeting(user: user),
                  const SizedBox(height: 14),
                  if (_activeLiveSession != null) ...[
                    _LiveContestBanner(
                      session: _activeLiveSession!,
                      onJoin: () => _joinLiveContest(_activeLiveSession!),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_nextSession != null) ...[
                    _NextClassCard(session: _nextSession!),
                    const SizedBox(height: 14),
                  ],
                  if (work.isNotEmpty) ...[
                    _workCard(work),
                    const SizedBox(height: 14),
                  ],
                  _todayCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workCard(List<WorkItem> items) {
    return _HomeCard(
      title: 'Travaux',
      actionLabel: 'Tout voir →',
      onAction: widget.onViewWork,
      children: [
        for (final item in items.take(_workPreviewCount))
          _HomeWorkRow(
            item: item,
            onOpen: () => _openWork(item),
            onLaunch: () => _launchQuiz(item),
          ),
      ],
    );
  }

  Widget _todayCard() {
    final sessions = _todaySessions ?? const <LessonSession>[];

    return _HomeCard(
      title: 'Ma journée',
      actionLabel: 'Emploi du temps →',
      onAction: widget.onViewTimetable,
      children: [
        if (_loading && sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text("Aucun cours aujourd'hui.",
                style: AppFont.sans(size: 12.5, color: AppColors.muted)),
          )
        else
          for (var i = 0; i < sessions.length; i++)
            _DayRow(session: sessions[i], gold: i.isOdd),
      ],
    );
  }

  Future<void> _openWork(WorkItem item) async {
    if (item.action == WorkAction.read && item.readingUrl != null) {
      await launchUrl(Uri.parse(item.readingUrl!),
          mode: LaunchMode.externalApplication);
      return;
    }

    await showWorkDetailSheet(context, item);
    if (mounted) await _loadToday();
  }

  Future<void> _launchQuiz(WorkItem item) async {
    final token = context.read<AuthService>().token;
    if (token == null || item.quizInstanceId == null) return;

    try {
      final attempt = await QuizService().start(token, item.quizInstanceId!);
      if (!mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizTakeScreen(
          attemptId: attempt.attemptId,
          quizName: item.title,
          startAtResult: attempt.concluded,
        ),
      ));
      if (mounted) await _loadToday();
    } on QuizException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _joinLiveContest(QuizLiveActiveSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizLiveJoinScreen(
        sessionId: session.sessionId,
        quizName: session.name,
        hostName: session.hostName,
      ),
    ));
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FrenchDate.full(DateTime.now()).toUpperCase(),
          style: AppFont.sans(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.faint,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Bonjour ${user?.firstname ?? user?.username ?? ''}',
          style: AppFont.spectral(size: 22, color: AppColors.navy),
        ),
      ],
    );
  }
}

/// "Prochain cours · dans 25 min" over the class itself, on the navy-to-blue gradient.
class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.session});

  final LessonSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1, -0.35),
          end: Alignment(1, 0.35),
          colors: [AppColors.navy, AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heading(),
            style: AppFont.sans(
              size: 11,
              weight: FontWeight.w600,
              color: AppColors.headerLight,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  session.title,
                  style: AppFont.sans(
                      size: 15, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    if (session.room != null) 'Salle ${session.room}',
                    if (session.teacher != null) session.teacher!,
                  ].join(' · '),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.sans(
                      size: 12.5, color: AppColors.headerLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "dans 25 min" while the class is still ahead, "en cours" once it has started - the mockup's
  /// countdown, read off the clock rather than stored anywhere.
  String _heading() {
    final parts = session.startTime.split(':');
    final start = DateTime(session.day.year, session.day.month, session.day.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final minutes = start.difference(DateTime.now()).inMinutes;

    if (minutes <= 0) return 'PROCHAIN COURS · EN COURS';
    if (minutes < 60) return 'PROCHAIN COURS · DANS $minutes MIN';

    return 'PROCHAIN COURS · ${session.startTime}';
  }
}

/// The white card of the home screen: a heading row with its link, then rows.
class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.actionLabel,
    required this.children,
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final List<Widget> children;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.rule)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title,
                    style: AppFont.sans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel,
                    style: AppFont.sans(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One travail in the home block - flatter than the Travaux tab's row: no hour column, the
/// deadline reads in the meta line, and only a quiz keeps an action.
class _HomeWorkRow extends StatelessWidget {
  const _HomeWorkRow(
      {required this.item, required this.onOpen, required this.onLaunch});

  final WorkItem item;
  final VoidCallback onOpen;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final late = item.state == WorkState.late;

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: late ? AppColors.lateBg : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: late
              ? const Border(
                  left: BorderSide(color: AppColors.lateInk, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFont.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                  Text(
                    [
                      if (item.subject != null) item.subject!,
                      FrenchDate.short(item.dueDate),
                      FrenchDate.time(item.dueDate),
                    ].join(' · '),
                    style: AppFont.sans(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (item.state == WorkState.late) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.latePillBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'En retard',
          style: AppFont.sans(
              size: 10.5, weight: FontWeight.w600, color: AppColors.lateInk),
        ),
      );
    }

    if (item.action == WorkAction.quiz) {
      return GestureDetector(
        onTap: onLaunch,
        child: Text(
          'Lancer',
          style: AppFont.sans(
              size: 12, weight: FontWeight.w600, color: AppColors.brandStrong),
        ),
      );
    }

    return const AppIcon(AppIcons.chevronRight,
        size: 13, color: AppColors.chevron, strokeWidth: 2);
  }
}

/// One class of "Ma journée": the slot in a fixed-width column, then the class. Two tints
/// alternate down the day, as in the reference.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.session, required this.gold});

  final LessonSession session;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gold ? AppColors.goldSoft : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
              color: gold ? AppColors.gold : AppColors.brand, width: 3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '${session.startTime}–${session.endTime}',
              style: AppFont.sans(
                size: 11.5,
                weight: FontWeight.w600,
                color: gold ? AppColors.chipGoldInk : AppColors.brandStrong,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.sans(
                      size: 13, weight: FontWeight.w600, color: AppColors.ink),
                ),
                Text(
                  [
                    if (session.room != null) session.room!,
                    if (session.teacher != null) session.teacher!,
                  ].join(' · '),
                  style: AppFont.sans(size: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one card outside the handoff - see [HomeScreen]'s docblock.
class _LiveContestBanner extends StatelessWidget {
  const _LiveContestBanner({required this.session, required this.onJoin});

  final QuizLiveActiveSession session;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: AppColors.gold, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'CONCOURS EN COURS',
                  style: AppFont.sans(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.gold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(session.name,
                style: AppFont.sans(
                    size: 15, weight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 3),
            Text('Lancé par ${session.hostName}',
                style:
                    AppFont.sans(size: 12.5, color: AppColors.headerLight)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('Rejoindre le concours',
                  style: AppFont.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.navy)),
            ),
          ],
        ),
      ),
    );
  }
}
