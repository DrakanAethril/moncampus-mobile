/// « 33,33 % » from the percentage the API hands out for a student's aménagement.
///
/// The durations the app displays already include it - the server applies it before sending them
/// (App\Service\Accommodation\AccommodationProfile on the backend) - so this is only ever used to
/// say *why* the numbers differ from the ones announced in class, never to compute anything.
String formatExtraTimePercent(double percent) {
  final rounded = (percent * 100).round() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

  return '${text.replaceAll('.', ',')} %';
}
