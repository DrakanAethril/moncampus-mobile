import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_theme.dart';
import 'quiz_matching_board.dart';
import 'quiz_zone_support.dart';

/// What a student has entered for one question, in the shape the API reads it.
///
/// One object for the twelve types rather than one per family: the server takes the same six named
/// lists whatever the question was (App\Service\QuizAnswerChecker), and a payload per family would
/// be six places to remember when a thirteenth type arrives.
class QuizAnswerInput {
  const QuizAnswerInput({
    this.answerIds = const [],
    this.blanks = const [],
    this.zones = const [],
    this.placements = const {},
    this.associations = const {},
    this.numeric = '',
  });

  final List<int> answerIds;
  final List<String> blanks;
  final List<String> zones;
  final Map<String, String> placements;
  final Map<String, String> associations;
  final String numeric;

  /// Whether anything at all has been entered - what a "Valider" button is enabled on.
  bool get isEmpty =>
      answerIds.isEmpty &&
      blanks.every((value) => value.trim().isEmpty) &&
      zones.isEmpty &&
      placements.isEmpty &&
      associations.isEmpty &&
      numeric.trim().isEmpty;
}

/// The answering half of a quiz question - the twelve types, and the state behind each.
///
/// Lifted out of QuizTakeScreen when the interactive video needed the same twelve renderings on top
/// of a player. It is the widget twin of the server's App\Service\QuizQuestionPayload: one
/// description of the twelve types on each side of the wire, so a zone, an appariement or a
/// calculée behaves the same in a quiz and inside a video.
///
/// It owns the entry state and hands it back through [onChanged]; the screen around it owns the
/// question, the navigation and the grading. That split is what lets a passation (several
/// questions, one attempt, a timer) and a marker (one question, no attempt, a paused video) share
/// it without either learning about the other.
class QuizQuestionForm extends StatefulWidget {
  const QuizQuestionForm({
    super.key,
    required this.question,
    required this.onChanged,
  });

  final QuizQuestion question;

  /// Called on every entry, with everything entered so far.
  final ValueChanged<QuizAnswerInput> onChanged;

  @override
  State<QuizQuestionForm> createState() => QuizQuestionFormState();
}

class QuizQuestionFormState extends State<QuizQuestionForm> {
  /// Selected answer ids. A Set for qcm_multi; for every single-answer type it simply never holds
  /// more than one.
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

  /// Apparier question: pair id => placed choice key. Kept apart from [_placements] rather than
  /// shared: the two are the same shape but not the same thing, and one map serving both would
  /// carry a légende's answer into the next question if a reset were ever missed.
  final Map<String, String> _associations = {};

  /// Numérique / Calculée: the answer as typed, comma and unit included - the server reads it.
  final TextEditingController _numericController = TextEditingController();
  String? _activeChoiceKey;
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(QuizQuestionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new question in the same slot must not inherit the previous one's entries - the very
    // mistake the two separate maps above already guard against, one level up.
    if (oldWidget.question != widget.question) {
      setState(_reset);
    }
  }

  @override
  void dispose() {
    _numericController.dispose();
    for (final controller in _blankControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reset() {
    final question = widget.question;

    _selected.clear();
    _zoneSelected.clear();
    _placements.clear();
    _associations.clear();
    _selectedWord = null;
    _activeChoiceKey = null;
    _hintShown = false;
    _numericController.text = '';
    _ordered = question.isOrder ? question.answers.map((a) => a.id).toList() : [];

    for (final controller in _blankControllers) {
      controller.dispose();
    }
    _blankControllers.clear();

    // A short answer is one blank, typed freely - the very same controller/response plumbing the
    // texte à trous uses, which is what the server stores it as. Its count comes from the type
    // rather than from the statement: the statement is a question, not a sentence with a hole, so
    // there are no segments to count (App\Entity\QuizQuestionDefinitionTrait says the same).
    final blankCount = question.isShortAnswer ? 1 : question.blankCount;
    _blanks = List.filled(blankCount, '');
    if (question.isShortAnswer || (question.isBlanks && !question.isWordBank)) {
      for (var i = 0; i < blankCount; i++) {
        final controller = TextEditingController();
        final index = i;
        controller.addListener(() {
          _blanks[index] = controller.text.trim();
          _emit();
        });
        _blankControllers.add(controller);
      }
    }
  }

  /// The entries as the API reads them - only the lists this question's type actually uses, so a
  /// leftover from a previous type can never travel.
  QuizAnswerInput get value {
    final question = widget.question;

    return QuizAnswerInput(
      answerIds: question.isOrder ? _ordered : _selected.toList(),
      blanks: question.isBlanks || question.isShortAnswer ? List.of(_blanks) : const [],
      zones: question.isZone ? _zoneSelected.toList() : const [],
      placements: question.isLegende ? Map.of(_placements) : const {},
      associations: question.isApparier ? Map.of(_associations) : const {},
      numeric: question.isNumeric ? _numericController.text : '',
    );
  }

  void _emit() => widget.onChanged(value);

  /// setState plus the report - every renderer below calls this instead of setState, so no entry
  /// can change without the screen around being told.
  void _change(VoidCallback change) {
    setState(change);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.isShortAnswer)
          ..._buildShortAnswer(question)
        else if (question.isBlanks)
          ..._buildBlanks(question)
        else if (question.isZones)
          ..._buildZones(question)
        else if (question.isApparier)
          ..._buildMatching(question)
        else if (question.isNumeric)
          ..._buildNumeric(question)
        else
          ..._buildStandard(question),
      ],
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
        onTap: () => _change(() {
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
                  onPressed: entry.key == 0 ? null : () => _change(() => _swapOrder(entry.key, entry.key - 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: entry.key == _ordered.length - 1 ? null : () => _change(() => _swapOrder(entry.key, entry.key + 1)),
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
      onTap: () => _change(() {
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
        onChanged: (_) => _change(() {}),
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
        onTap: used ? null : () => _change(() => _selectedWord = isSelected ? null : word),
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
        onZoneTap: (id) => _change(() {
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
            onPressed: () => _change(() => _hintShown = !_hintShown),
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

  /// A Réponse courte: the question, and one field to type a word or a short phrase into.
  ///
  /// Reuses the blanks' own controller (there is exactly one) so the answer travels in the same
  /// `blanks` field the server already reads - the type is stored as a texte à trous with a single
  /// blank, and the app has no reason to know more than that.
  List<Widget> _buildShortAnswer(QuizQuestion question) {
    final hint = question.blankIgnoreCase && question.blankTolerateTypo
        ? 'Majuscules et accents sont ignorés, et une faute de frappe est tolérée.'
        : question.blankIgnoreCase
            ? 'Majuscules et accents sont ignorés.'
            : question.blankTolerateTypo
                ? 'Une faute de frappe est tolérée.'
                : 'Réponse comparée exactement : la casse et les accents comptent.';

    return [
      Text(question.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5)),
      const SizedBox(height: 18),
      TextField(
        controller: _blankControllers.isNotEmpty ? _blankControllers.first : null,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.ink),
        decoration: const InputDecoration(hintText: 'Tapez votre réponse'),
      ),
      const SizedBox(height: 10),
      Text(hint, style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
    ];
  }

  /// A Numérique / Calculée question: the statement (already carrying this student's own drawn
  /// values - the server renders it, the app never substitutes anything) and one field for the
  /// number.
  ///
  /// A plain text field with a decimal keyboard rather than a number-only input: a French keyboard
  /// produces a comma, and a stricter field would swallow the keystroke without telling the student
  /// why. The server reads "2,5", "1 234,5" and "240 km" alike.
  List<Widget> _buildNumeric(QuizQuestion question) {
    final unit = question.numericUnit;
    final showFixedUnit = unit != null && !question.numericUnitRequired;

    return [
      Text(question.numericStatement ?? question.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5)),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _numericController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
              decoration: const InputDecoration(hintText: 'Votre réponse'),
            ),
          ),
          if (showFixedUnit) ...[
            const SizedBox(width: 10),
            // A fixed unit sits beside the field so the student types only the number; when the
            // teacher requires the unit it is part of the answer and the hint below says so.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(unit,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.faint)),
            ),
          ],
        ],
      ),
      if (unit != null && question.numericUnitRequired) ...[
        const SizedBox(height: 8),
        const Text("Indiquez aussi l'unité.", style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
      ],
    ];
  }

  /// An Apparier question: arm an item of the pool, then tap the slot it belongs to - the phone
  /// counterpart of the web's _quiz_apparier_take partial, and the same tap-not-drag interaction as
  /// the word bank and the légende labels. Either column may be pictures; that is entirely the
  /// board widget's business, which is why nothing here branches on it.
  List<Widget> _buildMatching(QuizQuestion question) {
    return [
      Text(question.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4)),
      const SizedBox(height: 6),
      const Text('Touchez un élément, puis la case où le placer. Retouchez une case remplie pour reprendre son élément.',
          style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
      const SizedBox(height: 14),
      QuizMatchingBoard(
        pairs: question.matchingPairs,
        headers: question.matchingHeaders,
        stateOf: (_) => MatchVisualState.none,
        placedOf: (pairId) => _matchingChoice(question, _associations[pairId]),
        onSlotTap: (pairId) => _change(() {
          if (_associations.containsKey(pairId)) {
            // A filled slot hands its item back, whatever chip is armed.
            _associations.remove(pairId);
          } else if (_activeChoiceKey != null) {
            _associations[pairId] = _activeChoiceKey!;
            _activeChoiceKey = null;
          }
        }),
      ),
      const SizedBox(height: 20),
      const Text('ÉLÉMENTS À RELIER',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.faint, letterSpacing: .5)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _buildMatchingChips(question)),
      const SizedBox(height: 14),
      Text('${_associations.length} / ${question.matchingPairs.length} associations faites',
          style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
    ];
  }

  QuizMatchingChoice? _matchingChoice(QuizQuestion question, String? key) {
    if (key == null) return null;
    for (final choice in question.matchingChoices) {
      if (choice.key == key) return choice;
    }
    return null;
  }

  List<Widget> _buildMatchingChips(QuizQuestion question) {
    final usedKeys = _associations.values.toSet();

    return question.matchingChoices.map((choice) {
      final used = usedKeys.contains(choice.key);
      final isActive = !used && _activeChoiceKey == choice.key;

      // Same chip states as the word bank: armed = blue halo, placed = greyed out.
      return GestureDetector(
        onTap: used ? null : () => _change(() => _activeChoiceKey = isActive ? null : choice.key),
        child: Opacity(
          opacity: used ? .45 : 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: choice.imageUrl != null ? 6 : 14, vertical: choice.imageUrl != null ? 6 : 8),
            decoration: BoxDecoration(
              color: used ? AppColors.surfaceAlt : (isActive ? AppColors.blueBg : AppColors.surface),
              border: Border.all(color: isActive ? AppColors.brand : AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: QuizMatchingItem(
              text: choice.text,
              imageUrl: choice.imageUrl,
              color: used ? AppColors.faint : (isActive ? AppColors.blueTx : AppColors.ink),
              fontSize: 13.5,
              strikeThrough: used && choice.imageUrl == null,
            ),
          ),
        ),
      );
    }).toList();
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
        onTap: used ? null : () => _change(() => _activeChoiceKey = isActive ? null : choice.key),
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
}
