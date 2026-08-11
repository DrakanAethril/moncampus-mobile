import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_theme.dart';

/// How one pair row should be painted - the passation leaves every row [none], the correction
/// drives [good]/[bad]. Mirrors the web's cm-match__row modifier classes.
enum MatchVisualState { none, good, bad }

/// The two columns of an Apparier question - the phone counterpart of the web's
/// templates/quiz/_matching_board.html.twig, shared by the passation and the correction so the two
/// can never disagree on what a pair looks like.
///
/// Either column may hold text or a picture; which one is a property of the column, not of the item
/// (App\Enum\MatchingSideKind), so a row is laid out the same way all the way down. Slots are
/// tappable when [onSlotTap] is given, inert otherwise (correction).
///
/// The columns stack rather than sitting side by side: on a phone, two pictures across a 360 dp
/// screen leaves neither legible, and the arrow already says which way the association reads.
class QuizMatchingBoard extends StatelessWidget {
  const QuizMatchingBoard({
    super.key,
    required this.pairs,
    required this.headers,
    required this.stateOf,
    this.placedOf,
    this.onSlotTap,
    this.reveal = false,
  });

  final List<QuizMatchingPair> pairs;
  final QuizMatchingHeaders headers;
  final MatchVisualState Function(String pairId) stateOf;

  /// The item currently sitting in a pair's slot, null while the slot is empty.
  final QuizMatchingChoice? Function(String pairId)? placedOf;
  final void Function(String pairId)? onSlotTap;

  /// Show each pair's real right-hand item under the slot - correction only, since that item *is*
  /// the answer (the server does not even send it during the attempt).
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headers.left.isNotEmpty || headers.right.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              [headers.left, headers.right].where((h) => h.isNotEmpty).join('  →  '),
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.faint, letterSpacing: .5),
            ),
          ),
        for (final pair in pairs) _buildRow(pair),
      ],
    );
  }

  Widget _buildRow(QuizMatchingPair pair) {
    final state = stateOf(pair.id);
    final placed = placedOf?.call(pair.id);

    final background = switch (state) {
      MatchVisualState.good => AppColors.greenBg,
      MatchVisualState.bad => AppColors.redBg,
      MatchVisualState.none => Colors.transparent,
    };
    final accent = switch (state) {
      MatchVisualState.good => AppColors.greenTx,
      MatchVisualState.bad => AppColors.redTx,
      MatchVisualState.none => AppColors.border,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: state == MatchVisualState.none ? Colors.transparent : accent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: QuizMatchingItem(text: pair.left, imageUrl: pair.leftImageUrl),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text('↓', textAlign: TextAlign.center, style: TextStyle(color: AppColors.faint)),
          ),
          GestureDetector(
            onTap: onSlotTap == null ? null : () => onSlotTap!(pair.id),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: placed != null && state == MatchVisualState.none ? AppColors.blueBg : AppColors.surface,
                border: Border.all(
                  color: state != MatchVisualState.none ? accent : (placed != null ? AppColors.brand : AppColors.border),
                  // A dashed border is not a thing Flutter draws without a painter; an empty slot
                  // reads as "drop here" from being empty and outlined, which is enough.
                  width: placed != null ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: placed == null
                  ? const SizedBox(height: 20)
                  : QuizMatchingItem(
                      text: placed.text,
                      imageUrl: placed.imageUrl,
                      color: state == MatchVisualState.bad
                          ? AppColors.redTx
                          : (state == MatchVisualState.good ? AppColors.greenTx : AppColors.blueTx),
                      strikeThrough: state == MatchVisualState.bad,
                    ),
            ),
          ),
          if (reveal && state != MatchVisualState.good && pair.hasAnswer) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendu : ',
                    style: TextStyle(fontSize: 12, color: AppColors.greenTx, fontWeight: FontWeight.w600)),
                Expanded(
                  child: QuizMatchingItem(
                    text: pair.right ?? '',
                    imageUrl: pair.rightImageUrl,
                    color: AppColors.greenTx,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One item of either column: its picture when it has one, its text otherwise. The text of an image
/// item is its alternative text, which is why it is still what gets announced and what stands in
/// when the picture cannot be fetched.
class QuizMatchingItem extends StatelessWidget {
  const QuizMatchingItem({
    super.key,
    required this.text,
    required this.imageUrl,
    this.color = AppColors.ink,
    this.fontSize = 14,
    this.strikeThrough = false,
  });

  final String text;
  final String? imageUrl;
  final Color color;
  final double fontSize;
  final bool strikeThrough;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w500,
          decoration: strikeThrough ? TextDecoration.lineThrough : null,
        ),
      );
    }

    return Semantics(
      label: text.isEmpty ? null : text,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl!,
          height: 84,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          // A picture that will not load must not take the answer down with it: the alt text is a
          // real fallback here, not a placeholder.
          errorBuilder: (_, __, ___) => Text(
            text.isEmpty ? '🖼' : text,
            style: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
