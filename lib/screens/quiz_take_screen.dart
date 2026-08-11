import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
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
  });

  final int attemptId;
  final String quizName;

  /// True when the student re-opens an évaluation they already handed in.
  final bool startAtResult;

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  final _quizService = QuizService();

  QuizQuestionPage? _page;
  QuizResult? _result;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Selected answer ids for the current question. A Set for qcm_multi; for every single-answer
  /// type it simply never holds more than one.
  final Set<int> _selected = {};

  /// Presentation order for an "ordre" question - the ids as the student has arranged them.
  List<int> _ordered = [];

  /// One entry per blank of a texte à trous, in text order. Both modes write here: the word bank
  /// puts the placed word in, free input puts what was typed.
  List<String> _blanks = [];
  String? _selectedWord;
  final List<TextEditingController> _blankControllers = [];

  /// Zone question: the zone ids currently tapped.
  final Set<String> _zoneSelected = {};

  /// Légende question: zone id => placed choice key, and the chip currently armed for placing.
  final Map<String, String> _placements = {};
  String? _activeChoiceKey;
  bool _hintShown = false;

  Timer? _timer;
  int? _secondsLeft;

  @override
  void initState() {
    super.initState();
    if (widget.startAtResult) {
      _loadResult();
    } else {
      _loadQuestion(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _blankControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestion(int position) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _quizService.fetchQuestion(token, widget.attemptId, position);
      if (!mounted) return;

      // The attempt ran out of time (or was already handed in) while the student was away.
      if (page.concluded) {
        await _loadResult();
        return;
      }

      setState(() {
        _page = page;
        _loading = false;
        _resetAnswerState(page.question!);
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

  void _resetAnswerState(QuizQuestion question) {
    _selected.clear();
    _selectedWord = null;
    _zoneSelected.clear();
    _placements.clear();
    _activeChoiceKey = null;
    _hintShown = false;
    _ordered = question.isOrder ? question.answers.map((a) => a.id).toList() : [];

    for (final controller in _blankControllers) {
      controller.dispose();
    }
    _blankControllers.clear();

    _blanks = List.filled(question.blankCount, '');
    if (question.isBlanks && !question.isWordBank) {
      for (var i = 0; i < question.blankCount; i++) {
        final controller = TextEditingController();
        final index = i;
        controller.addListener(() => _blanks[index] = controller.text.trim());
        _blankControllers.add(controller);
      }
    }
  }

  /// Per-question countdown. Auto-submits whatever is currently answered when it runs out, matching
  /// the web's quiz_passation controller - the question closes, the attempt carries on.
  void _startTimer(QuizQuestionPage page) {
    _timer?.cancel();
    final seconds = page.secondsForQuestion;
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

    final question = page.question!;
    final answerIds = question.isOrder ? _ordered : _selected.toList();

    try {
      final outcome = await _quizService.submitAnswer(
        token,
        widget.attemptId,
        page.position,
        answerIds: answerIds,
        blanks: question.isBlanks ? _blanks : const [],
        zones: question.isZone ? _zoneSelected.toList() : const [],
        placements: question.isLegende ? Map.of(_placements) : const {},
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
      body: SafeArea(child: _buildBody()),
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
              if (question.isBlanks)
                ..._buildBlanks(question)
              else if (question.isZones)
                ..._buildZones(question)
              else
                ..._buildStandard(question),
            ],
          ),
        ),
        _buildFooter(page, question),
      ],
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

  List<Widget> _buildStandard(QuizQuestion question) {
    return [
      Text(question.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4)),
      if (question.imageUrl != null) ...[
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(question.imageUrl!)),
      ],
      const SizedBox(height: 16),
      if (question.isOrder)
        ..._buildOrder(question)
      else
        ...question.answers.map((answer) => _buildOption(question, answer)),
    ];
  }

  Widget _buildOption(QuizQuestion question, QuizAnswerOption answer) {
    final isSelected = _selected.contains(answer.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          if (question.isMulti) {
            isSelected ? _selected.remove(answer.id) : _selected.add(answer.id);
          } else {
            _selected
              ..clear()
              ..add(answer.id);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blueBg : AppColors.surface,
            border: Border.all(color: isSelected ? AppColors.brand : AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                question.isMulti
                    ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 20,
                color: isSelected ? AppColors.brand : AppColors.faint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(answer.label,
                    style: TextStyle(fontSize: 14.5, color: isSelected ? AppColors.blueTx : AppColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOrder(QuizQuestion question) {
    final byId = {for (final answer in question.answers) answer.id: answer};

    return [
      const Text('Rangez les réponses dans le bon ordre.',
          style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
      const SizedBox(height: 10),
      // A plain up/down pair rather than a drag handle: the same choice the web editor made, and it
      // stays usable one-handed on a phone.
      ..._ordered.asMap().entries.map((entry) {
        final answer = byId[entry.value]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text('${entry.key + 1}.', style: const TextStyle(color: AppColors.faint, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(child: Text(answer.label, style: const TextStyle(fontSize: 14.5))),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: entry.key == 0 ? null : () => setState(() => _swapOrder(entry.key, entry.key - 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: entry.key == _ordered.length - 1 ? null : () => setState(() => _swapOrder(entry.key, entry.key + 1)),
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  void _swapOrder(int from, int to) {
    final moved = _ordered.removeAt(from);
    _ordered.insert(to, moved);
  }

  /// Screens 2c/2d. The statement is rendered as inline spans so the blanks sit inside the sentence
  /// rather than under it - a Wrap of small widgets, since Flutter's rich text cannot host the
  /// tappable chips and text fields the design calls for.
  List<Widget> _buildBlanks(QuizQuestion question) {
    final filled = _blanks.where((value) => value.trim().isNotEmpty).length;

    return [
      Text(
        question.isWordBank
            ? 'Touchez un mot de la banque, puis le trou où le placer. Touchez un mot placé pour le retirer.'
            : 'Complétez chaque trou.',
        style: const TextStyle(fontSize: 12.5, color: AppColors.faint),
      ),
      const SizedBox(height: 14),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 8,
        children: question.blankSegments.map((segment) {
          if (!segment.isBlank) {
            return Text(segment.text, style: const TextStyle(fontSize: 16, height: 1.9, color: AppColors.ink));
          }

          return question.isWordBank ? _buildBlankSlot(segment.index) : _buildBlankField(segment.index);
        }).toList(),
      ),
      if (question.isWordBank) ...[
        const SizedBox(height: 20),
        const Text('BANQUE DE MOTS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.faint, letterSpacing: .5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _buildWordBank(question)),
      ],
      const SizedBox(height: 14),
      Text('$filled / ${question.blankCount} trous remplis',
          style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
    ];
  }

  Widget _buildBlankSlot(int index) {
    final value = _blanks[index];
    final isFilled = value.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() {
        if (isFilled) {
          // A filled blank hands its word back to the bank.
          _blanks[index] = '';
        } else if (_selectedWord != null) {
          _blanks[index] = _selectedWord!;
          _selectedWord = null;
        }
      }),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFilled ? AppColors.blueBg : AppColors.surfaceAlt,
          border: Border.all(
            color: isFilled ? AppColors.brand : (_selectedWord != null ? AppColors.brand : AppColors.border),
            style: isFilled ? BorderStyle.solid : BorderStyle.none,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          isFilled ? value : '　',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isFilled ? AppColors.blueTx : AppColors.faint),
        ),
      ),
    );
  }

  Widget _buildBlankField(int index) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: TextField(
        controller: _blankControllers[index],
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'votre réponse',
          hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.faint),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  List<Widget> _buildWordBank(QuizQuestion question) {
    // A word can legitimately appear twice in the bank (two blanks with the same answer, or a
    // decoy equal to an answer), so "already placed" is a count, not a lookup: placing one copy
    // greys out exactly one chip and leaves the other available.
    final remaining = <String, int>{};
    for (final value in _blanks.where((v) => v.isNotEmpty)) {
      remaining[value] = (remaining[value] ?? 0) + 1;
    }

    return question.wordBank.map((word) {
      final used = (remaining[word] ?? 0) > 0;
      if (used) {
        remaining[word] = remaining[word]! - 1;
      }
      final isSelected = !used && _selectedWord == word;

      return GestureDetector(
        onTap: used ? null : () => setState(() => _selectedWord = isSelected ? null : word),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: used ? AppColors.surfaceAlt : (isSelected ? AppColors.blueBg : AppColors.surface),
            border: Border.all(color: isSelected ? AppColors.brand : AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: used ? AppColors.faint : (isSelected ? AppColors.blueTx : AppColors.ink),
              decoration: used ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      );
    }).toList();
  }

  /// The two "zones" types: tap the right zone(s) of a support (zone), or arm a label chip then
  /// tap the zone it belongs on (legende) - the phone counterpart of the web's
  /// _quiz_zone_take / _quiz_legende_take partials. Same tap-not-drag interaction as the word bank.
  List<Widget> _buildZones(QuizQuestion question) {
    final hint = question.isLegende
        ? 'Touchez une étiquette, puis la zone où la placer. Retouchez une zone remplie pour reprendre son étiquette.'
        : (question.zoneMultiple
            ? 'Plusieurs zones sont attendues : touchez chacune d\'elles (retoucher désélectionne).'
            : 'Touchez la zone demandée dans le support.');

    return [
      Text(question.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4)),
      const SizedBox(height: 6),
      Text(hint, style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
      const SizedBox(height: 14),
      QuizZoneSupport(
        kind: question.zoneKind ?? 'texte',
        lines: question.zoneLines,
        imageZones: question.imageZones,
        imageUrl: question.imageUrl,
        stateOf: (id) {
          if (question.isZone && _zoneSelected.contains(id)) return ZoneVisualState.selected;
          if (_hintShown && !question.zoneHintIds.contains(id)) return ZoneVisualState.dimmed;
          return ZoneVisualState.none;
        },
        placedTextOf: question.isLegende ? (id) => _choiceText(question, _placements[id]) : null,
        onZoneTap: (id) => setState(() {
          if (question.isZone) {
            _zoneSelected.contains(id) ? _zoneSelected.remove(id) : _zoneSelected.add(id);
          } else if (_placements.containsKey(id)) {
            // A filled zone hands its label back, whatever chip is armed.
            _placements.remove(id);
          } else if (_activeChoiceKey != null) {
            _placements[id] = _activeChoiceKey!;
            _activeChoiceKey = null;
          }
        }),
      ),
      if (question.isZone && question.zoneHintIds.isNotEmpty) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => setState(() => _hintShown = !_hintShown),
            child: const Text('? Indice'),
          ),
        ),
      ],
      if (question.isLegende) ...[
        const SizedBox(height: 20),
        const Text('ÉTIQUETTES À PLACER',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.faint, letterSpacing: .5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _buildChoiceChips(question)),
        const SizedBox(height: 14),
        Text('${_placements.length} / ${question.zoneIds.length} étiquettes placées',
            style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
      ],
    ];
  }

  String? _choiceText(QuizQuestion question, String? key) {
    if (key == null) return null;
    for (final choice in question.zoneChoices) {
      if (choice.key == key) return choice.text;
    }
    return key;
  }

  List<Widget> _buildChoiceChips(QuizQuestion question) {
    final usedKeys = _placements.values.toSet();

    return question.zoneChoices.map((choice) {
      final used = usedKeys.contains(choice.key);
      final isActive = !used && _activeChoiceKey == choice.key;

      // Same chip states as the word bank: armed = blue halo, placed = greyed strikethrough.
      return GestureDetector(
        onTap: used ? null : () => setState(() => _activeChoiceKey = isActive ? null : choice.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: used ? AppColors.surfaceAlt : (isActive ? AppColors.blueBg : AppColors.surface),
            border: Border.all(color: isActive ? AppColors.brand : AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            choice.text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: used ? AppColors.faint : (isActive ? AppColors.blueTx : AppColors.ink),
              decoration: used ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      );
    }).toList();
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
          if (entry.isBlanks)
            ..._buildBlankCorrection(entry)
          else if (entry.isZones)
            ..._buildZoneCorrection(entry)
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
