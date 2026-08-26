import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_theme.dart';

/// The door of a supervised assessment, in the terms of the web's own entry contract: what is
/// recorded, who reads it, for how long, and the fact that nothing is recorded yet.
///
/// It is not a formality - it *is* the device. An announced surveillance deters; a silent one only
/// documents. And it is the prior information that makes the processing lawful in the first place,
/// which is why this screen exists rather than a line of small print somewhere.
///
/// Nothing is started until "Commencer" is pressed: the attempt itself is created by that press
/// (App\Controller\Api\QuizController::start()), so the last bullet is literally true.
class QuizContractScreen extends StatefulWidget {
  const QuizContractScreen({super.key, required this.evaluation});

  final QuizEvaluation evaluation;

  @override
  State<QuizContractScreen> createState() => _QuizContractScreenState();
}

class _QuizContractScreenState extends State<QuizContractScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final evaluation = widget.evaluation;

    return Scaffold(
      appBar: AppBar(title: Text(evaluation.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(7)),
                  child: const Text('MODE CONTRÔLE',
                      style: TextStyle(color: AppColors.goldTx, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(evaluation.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              [
                '${evaluation.questionCount} questions',
                if (evaluation.secondsPerQuestion != null) '${evaluation.secondsPerQuestion} s par question',
                if (evaluation.globalTimeMinutes != null) '${evaluation.globalTimeMinutes} min au total',
                '1 tentative',
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5, color: AppColors.faint),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ce contrôle est surveillé.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.goldTx)),
                  SizedBox(height: 8),
                  _Bullet('Le temps que vous passez sur chaque question est enregistré.'),
                  _Bullet(
                      "Chaque fois que vous quittez l'application — autre application, écran verrouillé — la sortie et sa durée sont enregistrées."),
                  _Bullet('Votre enseignant en reçoit le détail avec votre copie.'),
                  _Bullet('Ces enregistrements sont conservés 12 mois, puis supprimés.'),
                  _Bullet(
                      "Le contenu de vos autres applications n'est pas lu, et rien n'est enregistré avant que vous n'appuyiez sur « Commencer »."),
                  _Bullet("Les captures d'écran sont désactivées pendant la passation."),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _accepted = !_accepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: _accepted, onChanged: (value) => setState(() => _accepted = value ?? false)),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('J’ai lu et je commence le contrôle.',
                          style: TextStyle(fontSize: 14, color: AppColors.ink)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Inert until the box is ticked - the contract is read, not scrolled past.
                onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Commencer'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Retour')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 13, color: AppColors.goldTx)),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.goldTx)),
            ),
          ],
        ),
      );
}
