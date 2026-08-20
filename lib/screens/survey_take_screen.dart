import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/survey.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Answering a survey on the phone - the counterpart of the web's survey/respond.html.twig.
///
/// Three things design/validated/surveys.md §10.3 asks of this screen, and each is a promise rather
/// than a nicety:
///
///  - **the anonymity notice is shown before the first question**, in full. It is a promise made to
///    the respondent, and it cannot exist on the web and not here;
///  - **the draft survives the app being closed** - that is the whole reason the API takes a
///    `submit` flag rather than offering two routes;
///  - **the ranking is doable one-handed**: two arrows per row, the very choice the quiz's
///    « ordre » question made (quiz_question_form.dart).
///
/// A « titre » line is drawn as a section heading and never counted: the counter under the form
/// would otherwise never reach its total.
class SurveyTakeScreen extends StatefulWidget {
  const SurveyTakeScreen({super.key, required this.surveyId, required this.surveyName});

  final int surveyId;
  final String surveyName;

  @override
  State<SurveyTakeScreen> createState() => _SurveyTakeScreenState();
}

class _SurveyTakeScreenState extends State<SurveyTakeScreen> {
  final _surveyService = SurveyService();

  Survey? _survey;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  /// The draft's id, kept so a resumed passation writes into the same response - the only way back
  /// to it on an anonymous campaign, where no respondent is stored.
  int? _responseId;

  /// questionId => picked answer ids. For a ranking question the list is the order itself.
  final Map<int, List<int>> _picked = {};

  /// questionId => free text.
  final Map<int, String> _texts = {};

  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final survey = await _surveyService.fetchSurvey(token, widget.surveyId);
      if (!mounted) return;

      setState(() {
        _survey = survey;
        _loading = false;
        // A ranking question starts in the order the server sent - which is an answer in itself, so
        // it is seeded rather than left empty.
        for (final question in survey.questions) {
          if (question.isOrder) {
            _picked[question.id] = [for (final answer in question.answers) answer.id];
          }
        }
      });
    } on SurveyException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Impossible de contacter le serveur.'; _loading = false; });
    }
  }

  List<SurveyAnswerInput> _inputs() {
    final survey = _survey;
    if (survey == null) return const [];

    return [
      for (final question in survey.answerableQuestions)
        if (question.isComment)
          SurveyAnswerInput(questionId: question.id, freeText: _texts[question.id] ?? '')
        else
          SurveyAnswerInput(questionId: question.id, answerIds: _picked[question.id] ?? const []),
    ];
  }

  Future<void> _save({required bool submit}) async {
    final token = context.read<AuthService>().token;
    if (token == null || _saving) return;

    setState(() { _saving = true; _notice = null; });

    try {
      final result = await _surveyService.saveResponse(
        token,
        widget.surveyId,
        _inputs(),
        submit: submit,
        responseId: _responseId,
      );

      if (!mounted) return;

      setState(() { _responseId = result.responseId; _saving = false; });

      if (result.submitted) {
        Navigator.of(context).pop(true);

        return;
      }

      setState(() => _notice = 'Brouillon enregistré. Vous pourrez reprendre plus tard.');
    } on SurveyException catch (e) {
      if (mounted) setState(() { _saving = false; _notice = e.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _notice = "Impossible d'enregistrer vos réponses."; });
    }
  }

  /// How many answerable questions carry something - the counter's numerator.
  int get _answered {
    final survey = _survey;
    if (survey == null) return 0;

    return survey.answerableQuestions.where((question) {
      if (question.isComment) return (_texts[question.id] ?? '').trim().isNotEmpty;
      if (question.isOrder) return true;

      return (_picked[question.id] ?? const []).isNotEmpty;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            AppHeader(
              user: user,
              child: AppHeaderTitleRow(
                title: widget.surveyName,
                onBack: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(error, textAlign: TextAlign.center, style: AppFont.sans(size: 13, color: AppColors.muted))),
      );
    }

    final survey = _survey;
    if (survey == null) return const SizedBox.shrink();

    var number = 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _AnonymityNotice(anonymous: survey.anonymous),
              if ((survey.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(survey.description!.trim(),
                    style: AppFont.sans(size: 13.5, color: AppColors.text, height: 1.6)),
              ],
              const SizedBox(height: 14),
              for (final question in survey.questions) ...[
                if (question.isHeading)
                  _SectionHeading(label: question.label)
                else ...[
                  Builder(builder: (context) {
                    number += 1;

                    return _QuestionCard(
                      question: question,
                      number: number,
                      picked: _picked[question.id] ?? const [],
                      controller: _controllerFor(question),
                      onPicked: (ids) => setState(() => _picked[question.id] = ids),
                      onText: (value) => setState(() => _texts[question.id] = value),
                    );
                  }),
                ],
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        _footer(survey),
      ],
    );
  }

  TextEditingController _controllerFor(SurveyQuestion question) =>
      _controllers.putIfAbsent(question.id, () => TextEditingController(text: _texts[question.id] ?? ''));

  Widget _footer(Survey survey) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notice != null) ...[
            Text(_notice!, style: AppFont.sans(size: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                // The total excludes the section headings - see the class docblock.
                'Question $_answered sur ${survey.questionCount}',
                style: AppFont.sans(size: 12, color: AppColors.faint),
              ),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : () => _save(submit: false),
                child: const Text('Plus tard'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _saving ? null : () => _save(submit: true),
                child: Text(_saving ? '…' : 'Envoyer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The promise, before the first question. On a nominative campaign it says so too: a respondent
/// who does not know which of the two they are in cannot answer honestly either.
class _AnonymityNotice extends StatelessWidget {
  const _AnonymityNotice({required this.anonymous});

  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: anonymous ? AppColors.blueSoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: anonymous ? AppColors.blueSoft : AppColors.border),
      ),
      child: Text(
        anonymous
            ? 'Vos réponses sont anonymes. Personne — ni votre enseignant, ni l’administration — ne '
                'pourra savoir qui a répondu quoi. Il est seulement enregistré que vous avez '
                'répondu, pour ne pas vous relancer inutilement. Évitez de vous nommer dans les '
                'commentaires.'
            : 'Ce sondage est nominatif : la personne qui l’a lancé verra vos réponses avec votre '
                'nom. Il n’est pas noté.',
        style: AppFont.sans(size: 12.5, color: AppColors.text, height: 1.55),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(label, style: AppFont.spectral(size: 15.5, color: AppColors.ink)),
    );
  }
}

/// One question - the four answerable types in one card.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.number,
    required this.picked,
    required this.controller,
    required this.onPicked,
    required this.onText,
  });

  final SurveyQuestion question;
  final int number;
  final List<int> picked;
  final TextEditingController controller;
  final ValueChanged<List<int>> onPicked;
  final ValueChanged<String> onText;

  /// The wording that says what the question expects - the only way a respondent knows.
  String get _hint {
    final help = (question.helpText ?? '').trim();
    if (help.isNotEmpty) return help;
    if (question.isSingle) return 'une seule réponse';
    if (question.isMulti) return 'plusieurs réponses possibles';
    if (question.isOrder) return 'utilisez les flèches pour classer';

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q$number', style: AppFont.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.faint)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.required_ ? '${question.label} *' : question.label,
                      style: AppFont.sans(size: 14, color: AppColors.ink, height: 1.4),
                    ),
                    if (_hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_hint, style: AppFont.sans(size: 11.5, color: AppColors.faint)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (question.isSingle) ..._single(),
          if (question.isMulti) ..._multi(),
          if (question.isOrder) ..._order(),
          if (question.isComment) _comment(),
        ],
      ),
    );
  }

  List<Widget> _single() => [
        for (final answer in question.answers)
          _Choice(
            label: answer.label,
            selected: picked.contains(answer.id),
            multiple: false,
            onTap: () => onPicked([answer.id]),
          ),
      ];

  List<Widget> _multi() => [
        for (final answer in question.answers)
          _Choice(
            label: answer.label,
            selected: picked.contains(answer.id),
            multiple: true,
            onTap: () {
              final next = [...picked];
              if (next.contains(answer.id)) {
                next.remove(answer.id);
              } else {
                // The author's own cap, enforced here so the respondent is not told off after the
                // fact by a server refusal.
                final max = question.maxChoices;
                if (max != null && next.length >= max) return;
                next.add(answer.id);
              }
              onPicked(next);
            },
          ),
      ];

  /// Two arrows per row rather than a drag handle - usable one-handed, and the same choice the
  /// quiz's own ranking question made.
  List<Widget> _order() {
    final byId = {for (final answer in question.answers) answer.id: answer};

    return [
      for (var index = 0; index < picked.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text('${index + 1}.',
                    style: AppFont.sans(size: 12.5, weight: FontWeight.w700, color: AppColors.faint)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(byId[picked[index]]?.label ?? '',
                      style: AppFont.sans(size: 14, color: AppColors.ink)),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: index == 0 ? null : () => onPicked(_swapped(index, index - 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: index == picked.length - 1 ? null : () => onPicked(_swapped(index, index + 1)),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<int> _swapped(int from, int to) {
    final next = [...picked];
    final moved = next.removeAt(from);
    next.insert(to, moved);

    return next;
  }

  /// The comment, with the counter the server's own cap dictates: a silent truncation is a bug.
  Widget _comment() {
    final max = question.maxLength ?? 2000;

    return TextField(
      controller: controller,
      maxLines: 4,
      maxLength: max,
      onChanged: onText,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        counterText: '${controller.text.length} / $max',
        isDense: true,
      ),
      style: AppFont.sans(size: 13.5, color: AppColors.ink),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.blueSoft : AppColors.surfaceAlt,
            border: Border.all(color: selected ? AppColors.brand : AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                multiple
                    ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 18,
                color: selected ? AppColors.brand : AppColors.chevron,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppFont.sans(size: 14, color: selected ? AppColors.brandStrong : AppColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
