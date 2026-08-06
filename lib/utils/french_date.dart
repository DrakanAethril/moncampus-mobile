/// French date wording, as the mockups spell it - "jeu. 06 août" on a day separator, "jeudi 6 août"
/// above the home greeting, "17:00" in a row's time column.
///
/// Written out rather than pulled from `intl`: the app ships one locale, and the reference only
/// ever needs these three shapes.
class FrenchDate {
  static const _weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static const _weekdaysShort = [
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _monthsShort = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  /// "jeudi 6 août" - the home screen's date line, drawn uppercase by the style.
  static String full(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  /// "jeu. 06 août" - day separators (4b) and "Donné le …" (4c).
  static String short(DateTime date) =>
      '${_weekdaysShort[date.weekday - 1]} ${_twoDigits(date.day)} ${_monthsShort[date.month - 1]}';

  /// "mar. 04" - a mail received earlier this month (5b).
  static String dayAndNumber(DateTime date) =>
      '${_weekdaysShort[date.weekday - 1]} ${_twoDigits(date.day)}';

  /// "17:00".
  static String time(DateTime date) =>
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

  /// The key a day separator groups on.
  static String dayKey(DateTime date) =>
      '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
