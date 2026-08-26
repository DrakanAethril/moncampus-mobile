import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../services/screen_capture_guard.dart';
import '../theme/app_theme.dart';
import '../widgets/quiz_matching_board.dart';
import '../widgets/quiz_question_form.dart';
import '../widgets/quiz_zone_support.dart';

/// Individual passation on mobile - the phone counterpart of the web's program/quiz_question.html.twig
/// (screen 1e) and its correction (1m), including the "texte à trous" type (screens 2c/2d) that a
/// live contest skips but an individual attempt keeps.
///
/// One question on screen at a time; the answer is saved when the student moves on, never on a
/// per-question "valider" button - same contract as the web, and the reason a dropped connection
/// mid-quiz only ever loses the current question.
class QuizTakeScreen extends StatefulWidget {
  const QuizTakeScreen({
    super.key,
    required this.attemptId,
    required this.quizName,
    this.startAtResult = false,
    this.supervised = false,
    this.sessionKey,
  });

  final int attemptId;
  final String quizName;

  /// True when the student re-opens an évaluation they already handed in.
  final bool startAtResult;

  /// Mode contrôle: leaving the app is journaled, screen capture is blocked, and the banner shows.
  final bool supervised;

  /// The key that owns this attempt, handed over by api_quiz_start. Presented on every call: the
  /// last client to open the attempt owns it, and this one is told rather than left composing into
  /// nothing when a browser takes the hand.
  final String? sessionKey;

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> with WidgetsBindingObserver {
  final _quizService = QuizService();
  final _captureGuard = const ScreenCaptureGuard();

  QuizQuestionPage? _page;
  QuizResult? _result;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// The form's own key, so the screen can read what was entered when the timer fires - the
  /// student may never have touched anything, and an expired question still has to be submitted.
  final GlobalKey<QuizQuestionFormState> _formKey = GlobalKey<QuizQuestionFormState>();

  /// The last entries reported by the form. Kept so the footer's button can be enabled without
  /// reaching into the form on every rebuild.
  QuizAnswerInput _input = const QuizAnswerInput();

  Timer? _timer;
  int? _secondsLeft;

  /// When the app stopped being frontmost, so the return can declare how long it was away.
  ///
  /// The declared duration is only ever *read* by the server when the departure never arrived, and
  /// it is bounded there by the instants the application itself knows - a client that lies can only
  /// accuse itself. The measurement proper is the difference between the two server timestamps.
  DateTime? _leftAt;

  /// The veil, iOS's stand-in for FLAG_SECURE: an opaque layer the instant the app is no longer
  /// frontmost, so the app-switcher snapshot shows it rather than the paper. Harmless on Android,
  /// where the system flag already blackens the thumbnail.
  bool _veiled = false;

  @override
  void initState() {
    super.initState();
    if (widget.supervised) {
      WidgetsBinding.instance.addObserver(this);
      _captureGuard.enable();
    }
    if (widget.startAtResult) {
      _loadResult();
    } else {
      _loadQuestion(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.supervised) {
      WidgetsBinding.instance.removeObserver(this);
      // The flag belongs to the window, not to this screen: left on, it would blacken the whole
      // app's thumbnail long after the assessment ended.
      _captureGuard.disable();
    }
    super.dispose();
  }

  /// Leaving and coming back, translated into the same two facts the browser reports - the server
  /// learns no new vocabulary from a phone.
  ///
  /// `inactive` fires for the notification centre and for split screen as well as for a real
  /// departure: it is a noisy signal, and that is exactly why the rule that reads it
  /// (App\Service\QuizSupervisionAssessor) demands a duration on top of the fact.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.supervised) return;

    final leaving = state == AppLifecycleState.inactive || state == AppLifecycleState.paused;

    if (leaving) {
      if (!_veiled) setState(() => _veiled = true);
      // Only the first of inactive/paused counts: the two arrive one after the other on a single
      // departure, and two beacons would read as two exits.
      if (_leftAt == null) {
        _leftAt = DateTime.now();
        _report('page_hidden');
      }

      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_veiled) setState(() => _veiled = false);
      final away = _leftAt;
      _leftAt = null;
      _report('page_visible', durationMs: away == null ? null : DateTime.now().difference(away).inMilliseconds);
    }
  }

  void _report(String type, {int? durationMs}) {
    final token = context.read<AuthService>().token;
    final key = widget.sessionKey;
    if (token == null || key == null) return;

    // Never awaited: an assessment must not wait on a beacon, and a lost one costs a duration the
    // server reconstructs rather than an interruption for the student.
    unawaited(_quizService.reportEvent(
      token,
      widget.attemptId,
      sessionKey: key,
      type: type,
      position: _page?.position,
      durationMs: durationMs,
    ));
  }

  Future<void> _loadQuestion(int position) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _quizService.fetchQuestion(token, widget.attemptId, position, sessionKey: widget.sessionKey);
      if (!mounted) return;

      // The attempt ran out of time (or was already handed in) while the student was away.
      if (page.concluded) {
        await _loadResult();
        return;
      }

      setState(() {
        _page = page;
        _loading = false;
        // The form rebuilds from scratch on the new position's key; nothing to clear here.
        _input = const QuizAnswerInput();
      });
      _startTimer(page);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }


  /// Per-question countdown. Auto-submits whatever is currently answered when it runs out, matching
  /// the web's quiz_passation controller - the question closes, the attempt carries on.
  ///
  /// It counts down from what is LEFT of the budget, not from the whole of it: the server stamped
  /// the question's first display and refuses a late answer against that, so a countdown starting
  /// afresh on every reopening would only mislead the student.
  void _startTimer(QuizQuestionPage page) {
    _timer?.cancel();
    final seconds = page.secondsRemaining ?? page.secondsForQuestion;
    if (seconds == null) {
      setState(() => _secondsLeft = null);
      return;
    }

    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left = (_secondsLeft ?? 0) - 1;
      setState(() => _secondsLeft = left);
      if (left <= 0) {
        timer.cancel();
        _submit();
      }
    });
  }

  Future<void> _submit() async {
    final page = _page;
    final token = context.read<AuthService>().token;
    if (page == null || token == null || _submitting) return;

    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      // Read from the form rather than from the last reported value: the timer can fire between
      // an entry and its report, and what is sent must be what is on screen.
      final input = _formKey.currentState?.value ?? _input;
      final outcome = await _quizService.submitAnswer(
        token,
        widget.attemptId,
        page.position,
        answerIds: input.answerIds,
        blanks: input.blanks,
        zones: input.zones,
        placements: input.placements,
        associations: input.associations,
        numeric: input.numeric,
        sessionKey: widget.sessionKey,
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      if (outcome.concluded || outcome.nextPosition == null) {
        await _loadResult();
      } else {
        await _loadQuestion(outcome.nextPosition!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadResult() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _quizService.fetchResult(token, widget.attemptId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _page = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quizName)),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            // The veil. Opaque and total: what the app-switcher photographs is this, not the paper.
            if (_veiled)
              const Positioned.fill(
                child: ColoredBox(
                  color: AppColors.navy,
                  child: Center(
                    child: Text('Contrôle en cours',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.redTx)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _page != null ? _loadQuestion(_page!.position) : _loadResult(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_result != null) {
      return _buildResult(_result!);
    }
    if (_page != null) {
      return _buildQuestion(_page!);
    }

    return const SizedBox.shrink();
  }

  Widget _buildQuestion(QuizQuestionPage page) {
    final question = page.question!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (page.supervision?.warn ?? false) _buildSupervisionBanner(page.supervision!),
              Row(
                children: [
                  Expanded(
                    child: Text('Question ${page.position + 1} / ${page.total}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint, letterSpacing: .5)),
                  ),
                  if (_secondsLeft != null) _buildTimerBadge(_secondsLeft!),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: page.total == 0 ? 0 : (page.position + 1) / page.total,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                ),
              ),
              const SizedBox(height: 18),
              QuizQuestionForm(
                // A GlobalKey, so _submit() can read what is on screen when the timer fires. The
                // form clears itself when the question changes (didUpdateWidget), which is why the
                // key does not need to vary per position.
                key: _formKey,
                question: question,
                onChanged: (input) => setState(() => _input = input),
              ),
            ],
          ),
        ),
        _buildFooter(page, question),
      ],
    );
  }

  /// The live warning, in the web's own words. It states facts - how many exits, and how long each
  /// lasted - never an accusation: that is what makes it bearable for the student whose phone rang,
  /// and dissuasive for the other one. It blocks nothing and does not close.
  Widget _buildSupervisionBanner(QuizSupervisionState supervision) {
    final durations = supervision.exitsMs.map((ms) => '${(ms / 1000).round()} s').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(9)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vous avez quitté l’application ${supervision.exitCount} fois depuis le début du contrôle ($durations).',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.goldTx, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Ces sorties sont enregistrées et transmises à votre enseignant.'
            '${supervision.submitAt != null ? ' Au-delà de ${supervision.submitAt} sorties, votre copie sera rendue en l’état.' : ''}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.goldTx, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBadge(int seconds) {
    // Under 10 seconds the badge turns red - the créa's "pulsation sous 10 s", toned down to a
    // colour change rather than an animation that would fight the list's scrolling.
    final urgent = seconds <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? AppColors.redBg : AppColors.goldBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
        style: TextStyle(
          color: urgent ? AppColors.redTx : AppColors.goldTx,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }











  /// The short-answer correction: what they typed, then every accepted wording - the variants are
  /// the marking scheme, so a student who wrote something reasonable that was not accepted can see
  /// it, which is how a teacher finds the variant they forgot.
  List<Widget> _buildShortAnswerCorrection(QuizCorrectionEntry entry) {
    final typed = entry.blankResponses.isNotEmpty ? entry.blankResponses.first : '';
    final accepted = entry.blankExpected.isNotEmpty ? entry.blankExpected.first : const <String>[];

    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: entry.isCorrect ? AppColors.greenBg : AppColors.redBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          'Votre réponse : ${typed.isNotEmpty ? typed : '—'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: entry.isCorrect ? AppColors.greenTx : AppColors.redTx,
          ),
        ),
      ),
      if (accepted.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Réponses acceptées : ${accepted.join(', ')}',
            style: const TextStyle(fontSize: 12, color: AppColors.faint)),
      ],
    ];
  }


  /// The numeric correction: what they typed, and what was expected of them - for a calculée, under
  /// the statement they were actually asked, since no two students got the same one.
  List<Widget> _buildNumericCorrection(QuizCorrectionEntry entry) {
    final decimals = entry.numericDecimals;
    String format(double value) => value.toStringAsFixed(decimals).replaceAll('.', ',');
    final unit = entry.numericUnit != null ? ' ${entry.numericUnit}' : '';
    final typed = entry.numericRaw;

    return [
      if (entry.numericStatement != null) ...[
        Text(entry.numericStatement!,
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.6)),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _numericChip(
            'Votre réponse : ${typed != null && typed.isNotEmpty ? typed : '—'}',
            entry.isCorrect ? AppColors.greenBg : AppColors.redBg,
            entry.isCorrect ? AppColors.greenTx : AppColors.redTx,
          ),
          if (entry.numericExpected != null)
            _numericChip('Attendu : ${format(entry.numericExpected!)}$unit', AppColors.surfaceAlt, AppColors.ink),
        ],
      ),
      if (entry.numericExpected != null && (entry.numericMargin ?? 0) > 0) ...[
        const SizedBox(height: 6),
        Text(
          '(de ${format(entry.numericExpected! - entry.numericMargin!)} à ${format(entry.numericExpected! + entry.numericMargin!)})',
          style: const TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      ],
    ];
  }

  Widget _numericChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
    );
  }




  /// The pairs replayed read-only: each slot green or red, the expected item under the ones that
  /// went wrong, then the teacher's per-pair feedbacks - the phone counterpart of the web's
  /// _quiz_attempt_breakdown apparier branch.
  List<Widget> _buildMatchingCorrection(QuizCorrectionEntry entry) {
    QuizMatchingChoice? placed(String pairId) {
      final key = entry.matchingResponses[pairId];
      if (key == null) return null;
      for (final choice in entry.matchingChoices) {
        if (choice.key == key) return choice;
      }
      return null;
    }

    return [
      QuizMatchingBoard(
        pairs: entry.matchingPairs,
        headers: entry.matchingHeaders,
        stateOf: (pairId) {
          final right = entry.matchingResults[pairId];
          if (right == null) return MatchVisualState.none;
          return right ? MatchVisualState.good : MatchVisualState.bad;
        },
        placedOf: placed,
        reveal: true,
      ),
      for (final pair in entry.matchingPairs)
        if (entry.matchingResults[pair.id] == false && entry.matchingFeedback[pair.id] != null) ...[
          const SizedBox(height: 6),
          Text(entry.matchingFeedback[pair.id]!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.redTx, fontWeight: FontWeight.w600)),
        ],
    ];
  }



  Widget _buildFooter(QuizQuestionPage page, QuizQuestion question) {
    final isLast = page.position + 1 >= page.total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('La réponse est enregistrée au passage à la question suivante',
                style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(isLast ? 'Terminer' : 'Question suivante →'),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(QuizResult result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(result.quizName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 12),
              if (result.scoreVisible)
                Text(
                  result.scoreOn20 != null
                      ? '${result.scoreOn20} / 20'
                      : '${result.scorePercent?.round() ?? 0} %',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.brand),
                )
              else
                const Text('Copie remise',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.muted)),
              if (result.scoreVisible && result.questionTotal != null) ...[
                const SizedBox(height: 6),
                Text('${result.score} / ${result.questionTotal} bonnes réponses',
                    style: const TextStyle(fontSize: 13, color: AppColors.faint)),
              ],
              if (!result.scoreVisible) ...[
                const SizedBox(height: 6),
                const Text('Le score sera publié par votre enseignant.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
              ],
            ],
          ),
        ),
        if (result.correction.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Correction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 10),
          ...result.correction.asMap().entries.map((entry) => _buildCorrectionCard(entry.key + 1, entry.value)),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour aux quiz')),
      ],
    );
  }

  Widget _buildCorrectionCard(int number, QuizCorrectionEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(entry.isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 18, color: entry.isCorrect ? AppColors.greenTx : AppColors.redTx),
              const SizedBox(width: 8),
              Text('Q$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.faint)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entry.isShortAnswer)
            ..._buildShortAnswerCorrection(entry)
          else if (entry.isBlanks)
            ..._buildBlankCorrection(entry)
          else if (entry.isZones)
            ..._buildZoneCorrection(entry)
          else if (entry.isApparier)
            ..._buildMatchingCorrection(entry)
          else if (entry.isNumeric)
            ..._buildNumericCorrection(entry)
          else
            ..._buildAnswerCorrection(entry),
          if (entry.explanation != null && !entry.isCorrect) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(8)),
              child: Text('Correction : ${entry.explanation}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.blueTx, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAnswerCorrection(QuizCorrectionEntry entry) {
    return entry.answers.map((answer) {
      final background = answer.correct
          ? AppColors.greenBg
          : (answer.selected ? AppColors.redBg : AppColors.surfaceAlt);
      final foreground = answer.correct
          ? AppColors.greenTx
          : (answer.selected ? AppColors.redTx : AppColors.faint);

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(7)),
          child: Text(
            '${answer.correct ? '✓ ' : ''}${answer.label}'
            '${answer.selected ? ' — votre réponse' : ''}',
            style: TextStyle(fontSize: 13, color: foreground, fontWeight: answer.correct || answer.selected ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      );
    }).toList();
  }

  /// The support replayed read-only: expected zones in green, a wrongly tapped/placed one in red,
  /// then the teacher's per-zone feedbacks - the phone counterpart of the web's
  /// _quiz_attempt_breakdown zone branches.
  List<Widget> _buildZoneCorrection(QuizCorrectionEntry entry) {
    String? choiceText(String? key) {
      if (key == null) return null;
      for (final choice in entry.zoneChoices) {
        if (choice.key == key) return choice.text;
      }
      return key;
    }

    final wrongLegendeZones =
        entry.zoneResults.entries.where((e) => !e.value).map((e) => e.key).toList();

    return [
      QuizZoneSupport(
        kind: entry.zoneKind ?? 'texte',
        lines: entry.zoneLines,
        imageZones: entry.imageZones,
        imageUrl: entry.imageUrl,
        stateOf: (id) {
          if (entry.isZone) {
            if (entry.zoneCorrectIds.contains(id)) return ZoneVisualState.good;
            if (entry.zoneClicked.contains(id)) return ZoneVisualState.bad;
            return ZoneVisualState.none;
          }
          final right = entry.zoneResults[id];
          if (right == null) return ZoneVisualState.none;
          return right ? ZoneVisualState.good : ZoneVisualState.bad;
        },
        placedTextOf: entry.isLegende ? (id) => choiceText(entry.zonePlacements[id]) : null,
      ),
      // Zone: the teacher's "why this one is wrong" for each mistakenly tapped zone.
      for (final id in entry.zoneClicked)
        if (entry.zoneFeedback[id] != null) ...[
          const SizedBox(height: 8),
          Text(entry.zoneFeedback[id]!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.redTx, fontWeight: FontWeight.w600)),
        ],
      // Légende: what belonged on each zone that ended up wrong or empty.
      for (final id in wrongLegendeZones)
        if (entry.zoneLabels[id] != null) ...[
          const SizedBox(height: 6),
          Text('Attendu : ${entry.zoneLabels[id]}',
              style: const TextStyle(fontSize: 12, color: AppColors.greenTx, fontWeight: FontWeight.w600)),
        ],
    ];
  }

  List<Widget> _buildBlankCorrection(QuizCorrectionEntry entry) {
    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 6,
        children: [
          for (var i = 0; i < entry.blankResponses.length; i++) ...[
            Text('Trou ${i + 1} :', style: const TextStyle(fontSize: 12, color: AppColors.faint)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (entry.blankResults.elementAtOrNull(i) ?? false) ? AppColors.greenBg : AppColors.redBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                entry.blankResponses[i].isEmpty ? '—' : entry.blankResponses[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: (entry.blankResults.elementAtOrNull(i) ?? false) ? AppColors.greenTx : AppColors.redTx,
                ),
              ),
            ),
            if (!(entry.blankResults.elementAtOrNull(i) ?? false) && (entry.blankExpected.elementAtOrNull(i)?.isNotEmpty ?? false))
              Text('attendu : ${entry.blankExpected[i].join(', ')}',
                  style: const TextStyle(fontSize: 12, color: AppColors.greenTx, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    ];
  }
}
