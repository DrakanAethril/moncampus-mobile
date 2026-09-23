import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_theme.dart';

/// What a wrong answer costs, said before it is given and again while it is being given.
///
/// One widget for the door of a supervised assessment and for the passation itself, the way the web
/// shares one partial between its two screens (templates/program/_quiz_penalty_notice.html.twig):
/// a penalty nobody was told about is a trap rather than a rule, and two screens wording it
/// separately is how they come to announce different arithmetic.
///
/// Renders nothing at all when the quiz carries no penalty, so every caller can include it
/// unconditionally.
class QuizPenaltyNotice extends StatelessWidget {
  const QuizPenaltyNotice({super.key, required this.penalty, this.margin});

  final QuizNegativeMarking? penalty;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final penalty = this.penalty;
    if (penalty == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(9)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            penalty.costSentence,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.redTx, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '${penalty.floorSentence} Une réponse partiellement juste n’est jamais pénalisée, '
            'ni une question laissée sans réponse.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.redTx, height: 1.4),
          ),
        ],
      ),
    );
  }
}
