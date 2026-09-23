/// « 0,5 » from the number of points « note négative sur erreurs » takes off a wrong answer.
///
/// The same trailing-zero rule the web applies (App\Entity\QuizInstance::getPenaltyPointsLabel()),
/// so a half point is not spelt « 0,50 » here and « 0,5 » there on two screens of the same quiz.
String formatPenaltyPoints(double points) {
  final rounded = (points * 100).round() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

  return text.replaceAll('.', ',');
}

/// A line's own score as a correction prints it: « −0,5 », « +0,67 ».
///
/// Always signed, because that is the whole point of showing it - a line that cost something has to
/// read differently from one that simply earned nothing.
String formatPenaltyScore(double score) {
  final sign = score < 0 ? '−' : '+';

  return '$sign${formatPenaltyPoints(score.abs())}';
}
