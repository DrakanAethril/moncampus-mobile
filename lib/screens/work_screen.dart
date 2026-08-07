import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/work_item.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../services/work_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import '../widgets/sheet_picker.dart';
import '../widgets/work_detail_sheet.dart';
import 'quiz_take_screen.dart';

/// The Travaux tab. Consultation on both sides: the student's list (design_handoff_mobile 4b) with
/// its EN RETARD / À FAIRE sections and day separators, the teacher's (4d) with the progress of
/// each travail. Which one is drawn follows the role - a teacher never sees their own travaux as
/// work to hand in.
class WorkScreen extends StatelessWidget {
  const WorkScreen({super.key, this.onOpenMail, this.hasUnreadMail = false});

  final VoidCallback? onOpenMail;
  final bool hasUnreadMail;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isTeacher = user?.roles.contains('ROLE_TEACHER') ?? false;

    return isTeacher
        ? TeacherWorkView(onOpenMail: onOpenMail)
        : StudentWorkView(onOpenMail: onOpenMail, hasUnreadMail: hasUnreadMail);
  }
}

/// 4b - "Mon travail".
class StudentWorkView extends StatefulWidget {
  const StudentWorkView(
      {super.key, this.onOpenMail, this.hasUnreadMail = false});

  final VoidCallback? onOpenMail;
  final bool hasUnreadMail;

  @override
  State<StudentWorkView> createState() => _StudentWorkViewState();
}

class _StudentWorkViewState extends State<StudentWorkView> {
  final _workService = WorkService();

  WorkBoard? _board;
  bool _loading = true;
  String? _error;
  int? _subjectFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final board = await _workService.fetchStudentBoard(token);
      if (mounted) setState(() => _board = board);
    } on WorkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de contacter le serveur.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<WorkItem> _filtered(List<WorkItem> items) => _subjectFilter == null
      ? items
      : items.where((item) => item.subjectId == _subjectFilter).toList();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final subjects = _board?.subjects ?? const <WorkSubject>[];
    WorkSubject? selected;
    for (final subject in subjects) {
      if (subject.id == _subjectFilter) selected = subject;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            user: user,
            title: 'Mon travail',
            mail: widget.hasUnreadMail
                ? MailButtonState.unread
                : MailButtonState.idle,
            onMailTap: widget.onOpenMail,
            titleTrailing: HeaderFilterLabel(
              label: selected?.name ?? 'Toutes les matières',
              onTap: subjects.isEmpty ? null : () => _pickSubject(subjects),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Future<void> _pickSubject(List<WorkSubject> subjects) async {
    // Index 0 is "Toutes les matières"; the sheet pops an index so a dismissal (null) stays
    // distinguishable from choosing "toutes".
    final picked = await showSheetPicker(
      context,
      labels: ['Toutes les matières', ...subjects.map((s) => s.name)],
      selectedIndex: _subjectFilter == null
          ? 0
          : subjects.indexWhere((s) => s.id == _subjectFilter) + 1,
    );

    if (picked == null || !mounted) return;
    setState(() =>
        _subjectFilter = picked == 0 ? null : subjects[picked - 1].id);
  }

  Widget _buildBody() {
    if (_loading && _board == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final late = _filtered(_board?.late ?? const []);
    final todo = _filtered(_board?.todo ?? const []);

    if (late.isEmpty && todo.isEmpty) {
      return const _EmptyState(message: 'Aucun travail à faire.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (late.isNotEmpty) ...[
            const _SectionLabel(label: 'En retard', color: AppColors.lateInk),
            const SizedBox(height: 9),
            ..._daySections(late, late: true),
          ],
          if (todo.isNotEmpty) ...[
            if (late.isNotEmpty) const SizedBox(height: 5),
            const _SectionLabel(label: 'À faire', color: AppColors.muted),
            const SizedBox(height: 9),
            ..._daySections(todo, late: false),
          ],
        ],
      ),
    );
  }

  /// One separator per day, however many rows follow it - same rule as the web list.
  List<Widget> _daySections(List<WorkItem> items, {required bool late}) {
    final widgets = <Widget>[];
    String? currentDay;

    for (final item in items) {
      final day = FrenchDate.dayKey(item.dueDate);
      if (day != currentDay) {
        currentDay = day;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 9));
        widgets.add(_DaySeparator(date: item.dueDate, late: late));
        widgets.add(const SizedBox(height: 9));
      } else {
        widgets.add(const SizedBox(height: 9));
      }

      widgets.add(_WorkRow(
        item: item,
        onOpen: () => _openDetail(item),
        onLaunch: () => _launchQuiz(item),
        onRead: () => _openReading(item),
      ));
    }

    return widgets;
  }

  Future<void> _openDetail(WorkItem item) async {
    await showWorkDetailSheet(context, item);
    if (mounted) await _load();
  }

  Future<void> _launchQuiz(WorkItem item) async {
    final token = context.read<AuthService>().token;
    if (token == null || item.quizInstanceId == null) return;

    try {
      final attempt =
          await QuizService().start(token, item.quizInstanceId!);
      if (!mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizTakeScreen(
          attemptId: attempt.attemptId,
          quizName: item.title,
          startAtResult: attempt.concluded,
        ),
      ));
      if (mounted) await _load();
    } on QuizException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// A reading with a link opens it; one built out of an attached file opens the sheet, where the
  /// attachment can be opened like any other.
  Future<void> _openReading(WorkItem item) async {
    final url = item.readingUrl;
    if (url == null) {
      await _openDetail(item);
      return;
    }

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// 4d - "Mes travaux".
class TeacherWorkView extends StatefulWidget {
  const TeacherWorkView({super.key, this.onOpenMail});

  final VoidCallback? onOpenMail;

  @override
  State<TeacherWorkView> createState() => _TeacherWorkViewState();
}

class _TeacherWorkViewState extends State<TeacherWorkView> {
  final _workService = WorkService();

  List<TeacherWorkItem>? _items;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  int? _programFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items =
          await _workService.fetchTeacherWork(token, finished: _tab == 1);
      if (mounted) setState(() => _items = items);
    } on WorkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de contacter le serveur.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final programs = <int, String>{
      for (final item in _items ?? const <TeacherWorkItem>[])
        if (item.programId != null) item.programId!: item.programName ?? '',
    };
    final selectedProgram = _programFilter == null
        ? null
        : programs[_programFilter];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            user: user,
            title: 'Mes travaux',
            // The Courrier école is the students' mailbox - a teacher's app bar keeps the
            // envelope's slot empty rather than opening a box they do not have.
            mail: MailButtonState.hidden,
            titleTrailing: HeaderFilterLabel(
              label: selectedProgram ?? 'Toutes les classes',
              onTap: programs.isEmpty ? null : () => _pickProgram(programs),
            ),
            filters: HeaderFilters(
              labels: const ['En cours', 'Terminés'],
              selectedIndex: _tab,
              onSelected: (index) {
                setState(() => _tab = index);
                _load();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Future<void> _pickProgram(Map<int, String> programs) async {
    final ids = programs.keys.toList();
    final picked = await showSheetPicker(
      context,
      labels: ['Toutes les classes', ...ids.map((id) => programs[id] ?? '')],
      selectedIndex:
          _programFilter == null ? 0 : ids.indexOf(_programFilter!) + 1,
    );

    if (picked == null || !mounted) return;
    setState(() => _programFilter = picked == 0 ? null : ids[picked - 1]);
  }

  Widget _buildBody() {
    if (_loading && _items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final items = (_items ?? const <TeacherWorkItem>[])
        .where((item) =>
            _programFilter == null || item.programId == _programFilter)
        .toList();

    if (items.isEmpty) {
      return _EmptyState(
        message: _tab == 0 ? 'Aucun travail en cours.' : 'Aucun travail terminé.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (_, index) => _TeacherWorkCard(item: items[index]),
      ),
    );
  }
}

/// "EN RETARD" / "À FAIRE".
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppFont.sans(
        size: 11.5,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: .5,
      ),
    );
  }
}

/// "— VEN. 31 JUIL. —": a 1px rule, the date, a 1px rule; red inside the late section.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date, required this.late});

  final DateTime date;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final ruleColor = late ? AppColors.lateBorder : AppColors.border;

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ruleColor)),
        const SizedBox(width: 10),
        Text(
          FrenchDate.short(date).toUpperCase(),
          style: AppFont.sans(
            size: 11.5,
            weight: FontWeight.w700,
            color: late ? AppColors.lateInk : AppColors.navy,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: ruleColor)),
      ],
    );
  }
}

/// One travail on the student's list: the hour alone in a 42px column, a hairline, the travail,
/// then what can be done with it.
class _WorkRow extends StatelessWidget {
  const _WorkRow({
    required this.item,
    required this.onOpen,
    required this.onLaunch,
    required this.onRead,
  });

  final WorkItem item;
  final VoidCallback onOpen;
  final VoidCallback onLaunch;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final (background, border, rule) = switch (item.state) {
      WorkState.late => (
          AppColors.lateBg,
          AppColors.lateBorder,
          AppColors.lateBorder
        ),
      WorkState.submitted => (
          AppColors.doneSurface,
          AppColors.doneBorder,
          AppColors.doneRule
        ),
      WorkState.todo => (AppColors.surface, AppColors.border, AppColors.rule),
    };

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  FrenchDate.time(item.dueDate),
                  textAlign: TextAlign.center,
                  style: AppFont.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, color: rule),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: AppFont.sans(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: AppColors.ink),
                          ),
                        ),
                        if (item.state == WorkState.submitted) ...[
                          const SizedBox(width: 8),
                          const WorkTag(label: 'Rendu'),
                        ],
                      ],
                    ),
                    if (item.metaLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.metaLine,
                        style: AppFont.sans(
                            size: 11.5, color: AppColors.faint),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _trailing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing() {
    if (item.state != WorkState.submitted) {
      if (item.action == WorkAction.quiz) {
        return _RowButton(label: 'Lancer', primary: true, onTap: onLaunch);
      }
      if (item.action == WorkAction.read) {
        return _RowButton(label: 'Lire', primary: false, onTap: onRead);
      }
      // A listening plays inside the sheet rather than anywhere else, so the button opens the very
      // same screen the row already opens - it is there to say the travail is doable here and now.
      if (item.action == WorkAction.listen) {
        return _RowButton(label: 'Écouter', primary: true, onTap: onOpen);
      }
    }

    return const AppIcon(AppIcons.chevronRight,
        size: 14, color: AppColors.chevron, strokeWidth: 2);
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton(
      {required this.label, required this.primary, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? AppColors.brand : AppColors.surface,
          border: primary ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppFont.sans(
            size: 12.5,
            weight: FontWeight.w600,
            color: primary ? Colors.white : AppColors.brandStrong,
          ),
        ),
      ),
    );
  }
}

/// The green "Rendu" pill (and the sheet's, which is the same shape).
class WorkTag extends StatelessWidget {
  const WorkTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.donePillBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFont.sans(
            size: 10.5, weight: FontWeight.w600, color: AppColors.doneInk),
      ),
    );
  }
}

/// One travail on the teacher's list, with its class chip and its progress bar.
class _TeacherWorkCard extends StatelessWidget {
  const _TeacherWorkCard({required this.item});

  final TeacherWorkItem item;

  /// The chip tints of the reference, picked from the class itself so a given class always reads
  /// the same colour without anything being stored.
  static const _chipColors = <(Color, Color)>[
    (AppColors.chipBlueBg, AppColors.chipBlueInk),
    (AppColors.chipPurpleBg, AppColors.chipPurpleInk),
    (AppColors.chipGoldBg, AppColors.chipGoldInk),
    (AppColors.chipTealBg, AppColors.chipTealInk),
  ];

  @override
  Widget build(BuildContext context) {
    final alert = item.progress.alert;
    final (chipBg, chipInk) =
        _chipColors[(item.programId ?? 0) % _chipColors.length];

    return Container(
      decoration: BoxDecoration(
        color: alert ? AppColors.lateBg : AppColors.surface,
        border: Border.all(color: alert ? AppColors.lateBorder : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: AppFont.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink),
                ),
              ),
              if (item.programName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.programName!,
                    style: AppFont.sans(
                        size: 10.5, weight: FontWeight.w600, color: chipInk),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _dueLine(),
            style: AppFont.sans(size: 11.5, color: AppColors.faint),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: item.progress.ratio,
                    minHeight: 5,
                    backgroundColor:
                        alert ? AppColors.lateTrack : AppColors.rule,
                    valueColor: AlwaysStoppedAnimation(
                        alert ? AppColors.lateInk : AppColors.brand),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _counterLabel(),
                style: AppFont.sans(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: alert ? AppColors.lateInk : AppColors.brandStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dueLine() {
    if (item.dueDate == null) return item.natureLabel;

    return '${item.natureLabel} · échéance ${FrenchDate.short(item.dueDate!)} · ${FrenchDate.time(item.dueDate!)}';
  }

  /// What the counter counts follows the nature: deposits are handed in, a quiz is sat, a reading
  /// is read. Past the deadline it is the missing ones that matter, and they read in red.
  String _counterLabel() {
    if (item.progress.hidden) return 'Non publié';

    final missing = item.progress.missing;
    if (missing != null && missing > 0) {
      return '$missing manquant${missing > 1 ? 's' : ''}';
    }

    final done = item.progress.done;
    final noun = switch (item.nature) {
      'quiz' => done > 1 ? 'passages' : 'passage',
      'to_read' => done > 1 ? 'lectures' : 'lecture',
      'to_submit' => done > 1 ? 'rendus' : 'rendu',
      _ => done > 1 ? 'faits' : 'fait',
    };

    return '$done $noun';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppFont.sans(size: 13, color: AppColors.muted, height: 1.6),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  AppFont.sans(size: 13, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Réessayer',
                style: AppFont.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
