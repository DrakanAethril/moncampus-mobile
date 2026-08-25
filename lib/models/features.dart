/// The feature keys this app actually reads, named once.
///
/// The catalogue itself lives on the backend (`App\Enum\Feature`, moncampus
/// design/validated/feature-access.md §4) and has some fifty entries; only the handful below bear
/// on anything the app draws. Naming them here rather than typing `'course_space'` in four places
/// is what keeps a rename from silently becoming "show everything", since [AppUser.has] answers
/// `true` for a key it does not recognise - deliberately, so an older backend does not blank the
/// app, and accidentally if somebody mistypes one.
abstract final class Features {
  /// The « Emploi du temps » tab, the day's classes on the home screen, and the next-class card.
  static const timetable = 'timetable';

  /// The « Travaux » tab and the home screen's work block.
  static const studentWork = 'student_work';

  /// The « Agenda » tab.
  static const agenda = 'agenda';

  /// The « Mes cours » tile, promoted to a tab when one frees up.
  static const courseSpace = 'course_space';

  /// The « Quiz » tile, same promotion rule.
  static const quizTake = 'quiz_take';

  /// The app bar's envelope and its gold dot - never a tab (handoff, principe 5).
  static const schoolMail = 'school_mail';

  /// The « Sondage en attente » card and « Mes sondages » behind it.
  static const surveys = 'surveys';

  /// The live-contest banner, and the only entry point the multiplayer contest has.
  static const quizLive = 'quiz_live';
}
