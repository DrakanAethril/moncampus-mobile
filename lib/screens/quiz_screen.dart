import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'quiz_contract_screen.dart';
import 'quiz_live_join_screen.dart';
import 'quiz_take_screen.dart';

/// Screen 1k of design_handoff_quiz - the student's Quiz tab: the live contest banner when one is
/// running, then the graded "Évaluations" and the unlimited "Entraînement libre".
///
/// Mirrors the web's program/quiz_mine.html.twig (screen 1d) rather than being a mobile-only view:
/// the same quizzes, the same statuses, so a student who starts on the phone and finishes in a
/// browser sees one consistent list.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _quizService = QuizService();

  QuizHub? _hub;
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
      final hub = await _quizService.fetchHub(token);

      if (!mounted) return;
      setState(() {
        _hub = hub;
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

  /// Opens a quiz. [contractFor] is the supervised assessment whose entry contract has to be read
  /// first - it is shown BEFORE the start call, because « rien n'est enregistré avant que vous
  /// n'appuyiez sur Commencer » is only true if the attempt does not exist yet.
  ///
  /// Never on a resumption: the sentence would be false, and a student whose app was killed
  /// mid-assessment has better things to read than a contract they already accepted.
  Future<void> _start(int instanceId, String name, {QuizEvaluation? contractFor}) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    if (contractFor != null && !contractFor.done && !contractFor.inProgress) {
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => QuizContractScreen(evaluation: contractFor)),
      );
      if (accepted != true || !mounted) return;
    }

    try {
      final started = await _quizService.start(token, instanceId);
      if (!mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizTakeScreen(
          attemptId: started.attemptId,
          quizName: name,
          // An évaluation already handed in has nothing left to answer - open its result directly.
          startAtResult: started.concluded,
          supervised: started.supervised,
          sessionKey: started.sessionKey,
        ),
      ));
      // Scores and "à faire / fait" statuses change while the student is inside the quiz.
      if (mounted) _load();
    } on QuizException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            user: context.watch<AuthService>().currentUser,
            child: AppHeaderTitleRow(
              title: 'Quiz',
              trailing: hub?.program != null
                  ? Text(hub!.program!.name,
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
          Expanded(child: _buildBody(hub)),
        ],
      ),
    );
  }

  Widget _buildBody(QuizHub? hub) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(_error!, retry: true);
    }
    if (hub == null || hub.program == null) {
      return _buildMessage("Aucune classe ne vous est rattachée pour l'instant.");
    }
    if (!hub.hasLiveSession && hub.evaluations.isEmpty && hub.practice.isEmpty) {
      return _buildMessage('Aucun quiz pour le moment.', retry: true);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hub.hasLiveSession) ...[
            _buildLiveBanner(hub),
            const SizedBox(height: 20),
          ],
          if (hub.evaluations.isNotEmpty) ...[
            const _SectionTitle('Évaluations'),
            const SizedBox(height: 10),
            ...hub.evaluations.map(_buildEvaluationCard),
            const SizedBox(height: 20),
          ],
          if (hub.practice.isNotEmpty) ...[
            const _SectionTitle('Entraînement libre'),
            const SizedBox(height: 4),
            const Text('Refaisable à volonté, questions tirées au hasard à chaque tentative',
                style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
            const SizedBox(height: 10),
            ...hub.practice.map(_buildPracticeCard),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(String message, {bool retry = false}) {
    // A ListView (not a Column) so the pull-to-refresh gesture still works on an empty state.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (retry) ...[
            const SizedBox(height: 16),
            Center(child: TextButton(onPressed: _load, child: const Text('Réessayer'))),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveBanner(QuizHub hub) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizLiveJoinScreen(
          sessionId: hub.liveSessionId!,
          quizName: hub.liveSessionName ?? '',
          hostName: hub.liveSessionHost ?? '',
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('QUIZ EN COURS',
                    style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Text(hub.liveSessionName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Concours lancé par ${hub.liveSessionHost ?? ''}'
              '${hub.liveParticipantCount > 0 ? ' · ${hub.liveParticipantCount} connectés' : ''}',
              style: const TextStyle(color: Color(0xFFCFDDE9), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => QuizLiveJoinScreen(
                    sessionId: hub.liveSessionId!,
                    quizName: hub.liveSessionName ?? '',
                    hostName: hub.liveSessionHost ?? '',
                  ),
                )),
                child: const Text('Rejoindre le concours'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationCard(QuizEvaluation evaluation) {
    final meta = <String>[
      if (evaluation.closesAt != null) 'Jusqu\'au ${_formatDay(evaluation.closesAt!)}',
      '${evaluation.questionCount} questions',
      if (evaluation.secondsPerQuestion != null) '${evaluation.secondsPerQuestion} s/question',
      if (evaluation.globalTimeMinutes != null) '${evaluation.globalTimeMinutes} min au total',
      if (evaluation.supervised) 'surveillé',
    ];

    return _QuizCard(
      name: evaluation.name,
      meta: meta.join(' · '),
      // A finished évaluation still opens - on its result, not on question 1. But an attempt open
      // right now comes first, and the order only ever matters in one case: a teacher granted a new
      // attempt over a copy already handed in. Read the other way round, the card would say « Voir
      // ma copie » on the very quiz the student is being asked to sit again - and the server would
      // send them to question 1 anyway, since QuizAttemptStarter resumes the open attempt.
      actionLabel: evaluation.inProgress
          ? 'Reprendre'
          : (evaluation.done ? 'Voir ma copie' : 'Commencer'),
      // An attempt already open outlives the window on the server (api_quiz_start resumes it before
      // asking the clock), so a new attempt granted after the closing date must not read as FERMÉ.
      enabled: evaluation.inProgress || evaluation.done || evaluation.openNow,
      badge: evaluation.inProgress
          ? const _Badge(label: 'EN COURS', background: AppColors.blueBg, foreground: AppColors.blueTx)
          : (evaluation.done
              ? _Badge(
                  label: evaluation.scorePercent != null ? '${evaluation.scorePercent!.round()} %' : 'Copie remise',
                  background: AppColors.greenBg,
                  foreground: AppColors.greenTx)
              : (evaluation.supervised
                  // Said on the card rather than only at the door: a student who knows an assessment
                  // is supervised before opening it can choose where to sit down.
                  ? const _Badge(label: 'MODE CONTRÔLE', background: AppColors.goldBg, foreground: AppColors.goldTx)
                  : (evaluation.openNow
                      ? const _Badge(label: 'À FAIRE', background: AppColors.goldBg, foreground: AppColors.goldTx)
                      : const _Badge(label: 'FERMÉ', background: AppColors.bg, foreground: AppColors.faint)))),
      onPressed: () => _start(
        evaluation.instanceId,
        evaluation.name,
        contractFor: evaluation.supervised ? evaluation : null,
      ),
    );
  }

  Widget _buildPracticeCard(QuizPractice practice) {
    final meta = <String>[
      if (practice.bestScorePercent != null) 'Meilleur score ${practice.bestScorePercent!.round()} %',
      practice.attemptCount == 0
          ? 'Jamais tenté'
          : '${practice.attemptCount} tentative${practice.attemptCount > 1 ? 's' : ''}',
    ];

    return _QuizCard(
      name: practice.name,
      meta: meta.join(' · '),
      actionLabel: practice.inProgress ? 'Reprendre' : "S'entraîner",
      enabled: practice.openNow,
      onPressed: () => _start(practice.instanceId, practice.name),
    );
  }

  String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.name,
    required this.meta,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
    this.badge,
  });

  final String name;
  final String meta;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
            ],
          ),
          const SizedBox(height: 4),
          Text(meta, style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: enabled ? onPressed : null, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
