import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course_space.dart';
import '../services/auth_service.dart';
import '../services/course_space_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'course_sequence_screen.dart';

/// « Mes cours » - the séquences a student's class has opened to them.
///
/// Mirrors the web's course_space/program.html.twig rather than being a mobile-only view: the same
/// séquences, published or held by the same conditions, so a student who reads a chapter on the
/// phone and the next in a browser sees one list.
///
/// A student almost always has exactly one class, so the class picker is skipped when there is one
/// - showing a list of a single item asks a question that has no second answer.
class CourseSpaceScreen extends StatefulWidget {
  const CourseSpaceScreen({super.key});

  @override
  State<CourseSpaceScreen> createState() => _CourseSpaceScreenState();
}

class _CourseSpaceScreenState extends State<CourseSpaceScreen> {
  final _service = CourseSpaceService();

  List<CourseProgram> _programs = const [];
  CourseProgramPage? _page;
  bool _loading = true;
  String? _error;

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
      final programs = await _service.fetchPrograms(token);
      final page = programs.isEmpty
          ? null
          : await _service.fetchProgram(token, (_page?.program ?? programs.first).id);

      if (!mounted) return;
      setState(() {
        _programs = programs;
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectProgram(CourseProgram program) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final page = await _service.fetchProgram(token, program.id);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _openSequence(CourseSequence sequence) {
    final page = _page;
    if (page == null || sequence.locked) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseSequenceScreen(
        programId: page.program.id,
        sequenceId: sequence.id,
        title: sequence.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            user: context.watch<AuthService>().currentUser,
            child: AppHeaderTitleRow(
              title: 'Mes cours',
              trailing: _page != null
                  ? Text(_page!.program.name,
                      style: const TextStyle(
                          color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _message(_error!, retry: true);

    final page = _page;
    if (page == null) {
      return _message("Aucune classe ne vous est rattachée pour l'instant.");
    }
    if (page.sequences.isEmpty) {
      return _message(
        "Aucun cours n'a encore été ouvert par vos enseignants.",
        retry: true,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Only when there is a choice to make.
          if (_programs.length > 1) ...[
            _ProgramPicker(
              programs: _programs,
              selected: page.program,
              onSelected: _selectProgram,
            ),
            const SizedBox(height: 16),
          ],
          for (final sequence in page.sequences) ...[
            _SequenceCard(sequence: sequence, onOpen: () => _openSequence(sequence)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: AppFont.sans(size: 13, color: AppColors.muted)),
            if (retry) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgramPicker extends StatelessWidget {
  const _ProgramPicker({required this.programs, required this.selected, required this.onSelected});

  final List<CourseProgram> programs;
  final CourseProgram selected;
  final ValueChanged<CourseProgram> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final program in programs)
          GestureDetector(
            onTap: () => onSelected(program),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: program.id == selected.id ? AppColors.ink : AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                program.name,
                style: AppFont.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: program.id == selected.id ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SequenceCard extends StatelessWidget {
  const _SequenceCard({required this.sequence, required this.onOpen});

  final CourseSequence sequence;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sequence.locked ? null : onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sequence.title,
                    style: AppFont.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      // A locked chapter is greyed rather than hidden: it is coming, and the row
                      // says what opens it.
                      color: sequence.locked ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                ),
                if (!sequence.locked)
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sequence.seanceCount > 1
                  ? '${sequence.seanceCount} séances'
                  : '${sequence.seanceCount} séance',
              style: AppFont.sans(size: 12, color: AppColors.muted),
            ),
            if (sequence.locked)
              for (final reason in sequence.lockedReasons) ...[
                const SizedBox(height: 6),
                _LockLine(reason),
              ],
          ],
        ),
      ),
    );
  }
}

/// The sentence that opens a locked row, written by the server and shown as it came.
class _LockLine extends StatelessWidget {
  const _LockLine(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.lock_outline, size: 13, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(reason, style: AppFont.sans(size: 11.5, color: AppColors.muted)),
        ),
      ],
    );
  }
}
