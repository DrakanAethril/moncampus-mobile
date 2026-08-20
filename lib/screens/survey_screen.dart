import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/survey.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import 'survey_take_screen.dart';

/// « Mes sondages » - the surveys still waiting for an answer.
///
/// Reached from a travail à faire and from the home card, never from a tab of its own: the tab bar
/// does not move for this (design/validated/surveys.md §10.3). It exists because a survey may be
/// addressed to somebody who has no travail à faire at all - a teacher, a member of staff, a tutor -
/// and this is then their only door.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _surveyService = SurveyService();

  List<SurveySummary> _pending = const [];
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

    try {
      final pending = await _surveyService.fetchPending(token);
      if (mounted) setState(() { _pending = pending; _loading = false; _error = null; });
    } on SurveyException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Impossible de contacter le serveur.'; _loading = false; });
    }
  }

  Future<void> _open(SurveySummary survey) async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SurveyTakeScreen(surveyId: survey.id, surveyName: survey.name),
      ),
    );

    // Answered: the row leaves the list, because the list is « what is still owed ».
    if (answered == true && mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            AppHeader(
              user: context.watch<AuthService>().currentUser,
              child: AppHeaderTitleRow(
                title: 'Mes sondages',
                onBack: () => Navigator.of(context).pop(),
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

    if (_pending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text('Aucun sondage ne vous attend.',
              textAlign: TextAlign.center, style: AppFont.sans(size: 13, color: AppColors.muted)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _SurveyRow(survey: _pending[index], onTap: () => _open(_pending[index])),
      ),
    );
  }
}

class _SurveyRow extends StatelessWidget {
  const _SurveyRow({required this.survey, required this.onTap});

  final SurveySummary survey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${survey.questionCount} question${survey.questionCount > 1 ? 's' : ''}',
      if (survey.closesAt != null) 'avant le ${FrenchDate.short(survey.closesAt!)}',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                  Text(survey.name, style: AppFont.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Said on the row too, not only inside: whether one is about to answer
                      // anonymously is the first thing a respondent wants to know.
                      _Pill(label: survey.anonymous ? 'anonyme' : 'nominatif', highlighted: survey.anonymous),
                      const SizedBox(width: 8),
                      Text(meta, style: AppFont.sans(size: 12, color: AppColors.faint)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.blueSoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFont.sans(
          size: 11,
          weight: FontWeight.w600,
          color: highlighted ? AppColors.brandStrong : AppColors.muted,
        ),
      ),
    );
  }
}
