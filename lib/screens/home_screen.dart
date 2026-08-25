import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/features.dart';
import '../models/lesson_session.dart';
import '../models/quiz_live_state.dart';
import '../models/survey.dart';
import '../models/work_item.dart';
import '../services/auth_service.dart';
import '../services/quiz_live_service.dart';
import '../services/quiz_service.dart';
import '../services/survey_service.dart';
import '../services/timetable_service.dart';
import '../services/work_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import '../widgets/work_detail_sheet.dart';
import 'course_space_screen.dart';
import 'quiz_live_join_screen.dart';
import 'survey_screen.dart';
import 'survey_take_screen.dart';
import 'quiz_screen.dart';
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
    this.showCoursesTile = true,
    this.showQuizTile = true,
  });

  final VoidCallback? onViewTimetable;
  final VoidCallback? onViewWork;
  final VoidCallback? onOpenMail;
  final bool hasUnreadMail;

  /// False once [MainShell] has promoted the shortcut to a tab of its own: one door per screen, or
  /// somebody ends up on the wrong one (moncampus design/validated/feature-access.md §10.2).
  final bool showCoursesTile;
  final bool showQuizTile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _timetableService = TimetableService();
  final _quizLiveService = QuizLiveService();
  final _workService = WorkService();
  final _surveyService = SurveyService();

  List<LessonSession>? _todaySessions;
  QuizLiveActiveSession? _activeLiveSession;
  WorkBoard? _board;

  /// The surveys still owed - loaded for **every** role, unlike the work board: a teacher or a
  /// tutor aimed at by a satisfaction survey has no travail à faire at all.
  List<SurveySummary> _pendingSurveys = const [];
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
    final user = auth.currentUser;
    final isStudent = user?.roles.contains('ROLE_STUDENT') ?? false;
    // A switched-off feature is not asked for at all. Its endpoint would answer 404 and the
    // catchError below would swallow it into an empty card - correct, but a round trip spent
    // learning what the profile already said (§10.1).
    final wantsTimetable = user?.has(Features.timetable) ?? true;
    final wantsWork = isStudent && (user?.has(Features.studentWork) ?? true);
    final wantsLive = isStudent && (user?.has(Features.quizLive) ?? true);
    final wantsSurveys = user?.has(Features.surveys) ?? true;

    setState(() => _loading = true);

    // Independent widgets, independent failures - one card not loading shouldn't blank the
    // others (unlike TimetableScreen's single-source dependency).
    // Both the live contest and the work board are student-only endpoints on the API side - a
    // teacher or an admin asking for them gets a 403 the backend logs as an error, so the gate
    // is here rather than in the catchError above.
    final results = await Future.wait([
      if (wantsTimetable)
        _timetableService
            .fetchWeek(token, from: monday, to: sunday)
            .catchError((_) => <LessonSession>[])
      else
        Future<List<LessonSession>>.value(const <LessonSession>[]),
      if (wantsLive)
        _quizLiveService.fetchActive(token).catchError((_) => null)
      else
        Future<QuizLiveActiveSession?>.value(null),
      if (wantsWork)
        _workService
            .fetchStudentBoard(token)
            .catchError((_) => const WorkBoard(items: [], subjects: []))
      else
        Future<WorkBoard?>.value(null),
    ]);

    // Asked for separately rather than in the wait above: it is the one call that is not
    // student-only, so folding it into that conditional list would tie it to a role it does not
    // have.
    final surveys = wantsSurveys
        ? await _surveyService
            .fetchPending(token)
            .catchError((_) => const <SurveySummary>[])
        : const <SurveySummary>[];

    if (!mounted) return;

    final today = DateTime(now.year, now.month, now.day);
    final todaySessions = (results[0] as List<LessonSession>)
        .where((session) => FrenchDate.isSameDay(session.day, today))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    setState(() {
      _todaySessions = todaySessions;
      _activeLiveSession = results[1] as QuizLiveActiveSession?;
      _board = results[2] as WorkBoard?;
      _pendingSurveys = surveys;
      _loading = false;
    });
  }

  /// « Mes sondages » in full - offered only when more than one is waiting, since with a single one
  /// the card already *is* the list.
  Future<void> _openSurveyList() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SurveyScreen()));
    if (mounted) await _loadToday();
  }

  Future<void> _openSurvey(SurveySummary survey) async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SurveyTakeScreen(surveyId: survey.id, surveyName: survey.name),
      ),
    );

    if (answered == true && mounted) await _loadToday();
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
    // Both shortcuts lead to student-only areas; a teacher opening them would meet a 403.
    final isStudent = user?.roles.contains('ROLE_STUDENT') ?? false;
    // A tile is drawn when the feature exists **and** the bar has not already promoted it to a tab
    // (moncampus design/validated/feature-access.md §10.2).
    final showCourses = isStudent &&
        widget.showCoursesTile &&
        (user?.has(Features.courseSpace) ?? true);
    final showQuiz = isStudent &&
        widget.showQuizTile &&
        (user?.has(Features.quizTake) ?? true);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            user: user,
            // The envelope's own feature check lives in AppHeader, which already knows the
            // user - here it is only ever "is there unread mail".
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
                  if (showCourses || showQuiz) ...[
                    _ShortcutRow(
                      onCourses: showCourses ? _openCourses : null,
                      onQuiz: showQuiz ? _openQuiz : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  // « Sondage en attente » - shown to every role, because a survey addressed to a
                  // teacher, a member of staff or a tutor has no travail à faire at all, and this
                  // card plus « Mes sondages » are then their only door
                  // (design/validated/surveys.md §8).
                  if (_pendingSurveys.isNotEmpty) ...[
                    _PendingSurveyCard(
                      survey: _pendingSurveys.first,
                      others: _pendingSurveys.length - 1,
                      onAnswer: () => _openSurvey(_pendingSurveys.first),
                      onSeeAll: _pendingSurveys.length > 1 ? _openSurveyList : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_activeLiveSession != null) ...[
                    _LiveContestBanner(
                      session: _activeLiveSession!,
                      onJoin: () => _joinLiveContest(_activeLiveSession!),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Both read the timetable, which this establishment may well keep elsewhere: with
                  // « Emploi du temps » switched off they have nothing to show, and « Emploi du
                  // temps → » at the foot of « Ma journée » leads to a tab that no longer exists.
                  if ((user?.has(Features.timetable) ?? true) &&
                      _nextSession != null) ...[
                    _NextClassCard(session: _nextSession!),
                    const SizedBox(height: 14),
                  ],
                  if (work.isNotEmpty) ...[
                    _workCard(work),
                    const SizedBox(height: 14),
                  ],
                  if (user?.has(Features.timetable) ?? true) _todayCard(),
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

  void _openCourses() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CourseSpaceScreen()));
  }

  /// The Quiz hub - the évaluations and the entraînement libre of the class, which is not the same
  /// list as the travaux. Its screen shipped with the quiz feature and nothing ever pushed it.
  void _openQuiz() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuizScreen()));
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

/// Two doors the tab bar has no room for: « Mes cours » and « Quiz ».
///
/// The bar stays at four tabs on purpose (design_handoff_mobile, principe 4), so these live on the
/// home screen - which is where a student lands anyway, and where the day's own cards already sit.
/// The two shortcut tiles of the handoff (principe 5). Either can be absent - because its feature
/// is switched off, or because the bar has promoted it to a tab - and the row then draws the other
/// one full width rather than leaving a gap where a tile used to be.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({this.onCourses, this.onQuiz});

  final VoidCallback? onCourses;
  final VoidCallback? onQuiz;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (onCourses != null)
        _ShortcutTile(icon: Icons.menu_book_outlined, label: 'Mes cours', onTap: onCourses!),
      if (onQuiz != null)
        _ShortcutTile(icon: Icons.quiz_outlined, label: 'Quiz', onTap: onQuiz!),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: AppFont.sans(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// « Sondage en attente » on the home screen.
///
/// Shown to every role on purpose: a survey reaches a student through their travail à faire, but a
/// teacher, a member of staff or a tutor has none at all, and this card is then their only door
/// (design/validated/surveys.md §8).
///
/// It says how many questions and by when, and nothing of the content: a card that summarised the
/// survey would be read instead of it.
class _PendingSurveyCard extends StatelessWidget {
  const _PendingSurveyCard({
    required this.survey,
    required this.others,
    required this.onAnswer,
    this.onSeeAll,
  });

  final SurveySummary survey;

  /// How many more are waiting behind this one.
  final int others;
  final VoidCallback onAnswer;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${survey.questionCount} question${survey.questionCount > 1 ? 's' : ''}',
      if (survey.closesAt != null) 'avant le ${FrenchDate.short(survey.closesAt!)}',
      if (others > 0) 'et $others autre${others > 1 ? 's' : ''}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sondage en attente',
                    style: AppFont.sans(
                        size: 11, weight: FontWeight.w700, color: AppColors.faint)),
                const SizedBox(height: 4),
                Text(survey.name,
                    style: AppFont.sans(
                        size: 14.5, weight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(meta, style: AppFont.sans(size: 12, color: AppColors.faint)),
                if (onSeeAll != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text('Tout voir →',
                        style: AppFont.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.brandStrong)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: onAnswer, child: const Text('Répondre')),
        ],
      ),
    );
  }
}
