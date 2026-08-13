import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_cue.dart';
import '../services/auth_service.dart';
import '../services/video_cue_service.dart';
import '../theme/app_theme.dart';
import 'quiz_question_form.dart';

/// The question that appears over the player when its marker is reached (créas 5B, screen 4).
///
/// Three rules, all of them the web's:
///
///  1. **A marker only fires by walking onto it, never by skipping past it.** What is asked is what
///     has been watched, so the trigger is a narrow window around the timecode and only while the
///     video is actually playing - dragging the playhead over a marker leaves it unasked.
///  2. **A marker is asked once.** The answer that counts is the first one; a second viewing is a
///     viewing.
///  3. **Blocking means blocking.** A blocking marker keeps the video paused until it is answered;
///     a non-blocking one can be dismissed and the video goes on.
///
/// The statement is rendered by [QuizQuestionForm], the same widget the passation uses - which is
/// the whole reason it was lifted out of the quiz screen. Twelve types, one description, on both
/// sides of the wire and on both screens.
class VideoCueOverlay extends StatefulWidget {
  const VideoCueOverlay({
    super.key,
    required this.assignmentId,
    required this.fileId,
    required this.cues,
    required this.position,
    required this.playing,
    required this.onPause,
    required this.onResume,
    required this.onSeek,
    required this.onAnswered,
  });

  final int assignmentId;
  final int fileId;
  final List<VideoCuePoint> cues;

  /// The playhead, as the player reports it.
  final Duration position;
  final bool playing;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final void Function(Duration to) onSeek;

  /// Called once a marker has been answered, so the list can be refreshed.
  final void Function(int cueId) onAnswered;

  @override
  State<VideoCueOverlay> createState() => _VideoCueOverlayState();
}

class _VideoCueOverlayState extends State<VideoCueOverlay> {
  final _service = VideoCueService();
  final _formKey = GlobalKey<QuizQuestionFormState>();

  /// How close to the timecode a playing position has to land to fire the marker. Wide enough for
  /// the gap between two position ticks (~200 ms on Android), far short of a seek.
  static const _window = Duration(milliseconds: 700);

  /// Markers fired during this viewing - a marker must not re-fire while its own question is open,
  /// nor a moment later because the playhead has not moved past the window yet.
  final Set<int> _fired = {};

  VideoCueQuestion? _open;
  VideoCueOutcome? _outcome;
  QuizAnswerInput _input = const QuizAnswerInput();
  bool _busy = false;

  @override
  void didUpdateWidget(VideoCueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) _maybeFire();
  }

  void _maybeFire() {
    // Rule 1: only while playing, and only inside the window. A drag lands outside it, and the
    // marker stays unasked - what is asked is what has been watched.
    if (!widget.playing || _open != null || _busy) return;

    for (final cue in widget.cues) {
      if (cue.fileId != null && cue.fileId != widget.fileId) continue;
      if (cue.answered || _fired.contains(cue.id)) continue;

      final delta = widget.position - cue.position;
      if (delta >= Duration.zero && delta <= _window) {
        _fired.add(cue.id);
        _ask(cue);

        return;
      }
    }
  }

  Future<void> _ask(VideoCuePoint cue) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    if (cue.pauseVideo) widget.onPause();
    setState(() => _busy = true);

    try {
      final question = await _service.fetchQuestion(token, widget.assignmentId, cue.id);
      if (!mounted) return;
      _open = question;
      _outcome = null;
      _input = const QuizAnswerInput();
      _busy = false;
      _refresh();
      await _present();
    } on VideoCueException catch (error) {
      if (!mounted) return;
      // A statement that will not load must not leave the video paused for ever - it says so and
      // the video goes on, rather than stopping the lesson on a network hiccup.
      _busy = false;
      _open = null;
      _refresh();
      _complain(error.message);
      widget.onResume();
    }
  }

  Future<void> _submit() async {
    final open = _open;
    final token = context.read<AuthService>().token;
    if (open == null || token == null) return;

    _busy = true;
    _refresh();

    try {
      final outcome = await _service.submitAnswer(
        token,
        widget.assignmentId,
        open.cueId,
        _formKey.currentState?.value ?? _input,
      );
      if (!mounted) return;
      _outcome = outcome;
      _busy = false;
      _refresh();
      widget.onAnswered(open.cueId);
    } on VideoCueException catch (error) {
      if (!mounted) return;
      _busy = false;
      _refresh();
      _complain(error.message);
    }
  }

  void _complain(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
    _open = null;
    _outcome = null;
    if (mounted) setState(() {});
    widget.onResume();
  }

  void _replay() {
    final open = _open;
    final from = open?.replayFrom;
    Navigator.of(context, rootNavigator: true).pop();
    _open = null;
    _outcome = null;
    if (mounted) setState(() {});
    if (from != null) {
      widget.onSeek(Duration(milliseconds: (from * 1000).round()));
    }
    widget.onResume();
  }

  /// Nothing on screen: the question is presented as a modal, because a panel confined to the
  /// player's own rectangle cannot hold a texte à trous on a phone - the statement was clipped at
  /// two lines. The interruption is the same, it simply has the whole screen to say it in.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Future<void> _present() async {
    await showDialog<void>(
      context: context,
      // A marker is an interruption: it is dismissed by answering or by « Plus tard », never by a
      // tap outside - and a blocking one has no « Plus tard » at all.
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          _rebuildDialog = () => setDialogState(() {});

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            backgroundColor: Colors.transparent,
            child: _buildPanel(),
          );
        },
      ),
    );
    _rebuildDialog = null;
  }

  /// Lets the state below repaint the dialog, which lives in its own subtree.
  VoidCallback? _rebuildDialog;

  void _refresh() {
    if (mounted) setState(() {});
    _rebuildDialog?.call();
  }

  Widget _buildPanel() {
    final open = _open;
    if (open == null) return const SizedBox.shrink();

    final outcome = _outcome;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: AppColors.navy,
            child: Row(
              children: [
                const Icon(Icons.help_outline, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Question sur ce passage',
                      style: AppFont.sans(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                ),
                if (open.blocking)
                  Text('Obligatoire',
                      style: AppFont.sans(size: 11, color: AppColors.gold)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: outcome == null
                  ? QuizQuestionForm(
                      key: _formKey,
                      question: open.question,
                      onChanged: (input) {
                        _input = input;
                        _refresh();
                      },
                    )
                  : _buildOutcome(outcome),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: outcome == null ? _buildAnswerBar(open) : _buildOutcomeBar(open, outcome),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcome(VideoCueOutcome outcome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(outcome.correct ? Icons.check_circle : Icons.cancel,
                size: 20, color: outcome.correct ? AppColors.greenTx : AppColors.redTx),
            const SizedBox(width: 8),
            Text(outcome.correct ? 'Bonne réponse' : 'Réponse incorrecte',
                style: AppFont.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: outcome.correct ? AppColors.greenTx : AppColors.redTx)),
          ],
        ),
        if ((outcome.explanation ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(outcome.explanation!,
              style: AppFont.sans(size: 13, color: AppColors.text, height: 1.5)),
        ],
        if (!outcome.recorded) ...[
          const SizedBox(height: 10),
          Text('Vous aviez déjà répondu : cette réponse ne change pas votre résultat.',
              style: AppFont.sans(size: 11.5, color: AppColors.muted)),
        ],
      ],
    );
  }

  Widget _buildAnswerBar(VideoCueQuestion open) {
    return Row(
      children: [
        // Rule 3: a blocking marker offers no way past it.
        if (!open.blocking)
          TextButton(onPressed: _busy ? null : _close, child: const Text('Plus tard')),
        const Spacer(),
        FilledButton(
          onPressed: _busy || _input.isEmpty ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Valider'),
        ),
      ],
    );
  }

  Widget _buildOutcomeBar(VideoCueQuestion open, VideoCueOutcome outcome) {
    final replay = open.replayFrom;

    return Row(
      children: [
        if (replay != null)
          TextButton(
            onPressed: _replay,
            child: Text('↺ Revoir ${_mmss(replay)}'),
          ),
        const Spacer(),
        FilledButton(onPressed: _close, child: const Text('Reprendre la vidéo')),
      ],
    );
  }

  String _mmss(double seconds) {
    final total = seconds.round();

    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }
}
