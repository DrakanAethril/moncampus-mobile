import 'package:flutter_test/flutter_test.dart';

import 'package:moncampus_mobile/models/app_user.dart';
import 'package:moncampus_mobile/models/features.dart';

/// The promotion rule of the bottom bar, and the reading of the `features` object it rests on
/// (moncampus design/validated/feature-access.md §10.1 and §10.2).
///
/// The rule is small enough to state in a sentence and easy enough to get subtly wrong: the bar
/// keeps its available tabs in order, promotes « Mes cours » then « Quiz » from the home screen's
/// tiles when a place frees, and caps at four with Accueil never removed. What makes it worth a
/// test is that being wrong is **silent** - the bar simply shows one tab too many or too few, and
/// nobody notices which.
///
/// Written against the same list [MainShell] builds, on a plain [AppUser], so it needs no widget
/// tree and no network: the ordering is the rule, and the rule is what is pinned.
void main() {
  AppUser userWith(Map<String, bool> features) => AppUser(
        id: 1,
        username: 'tester',
        roles: const ['ROLE_STUDENT'],
        features: features,
      );

  /// The same construction as _MainShellState._tabsFor(), kept here in the vocabulary of labels so
  /// a failure reads as the bar somebody would see.
  List<String> barFor(AppUser user) => <String>[
        'Accueil',
        if (user.has(Features.timetable)) 'Emploi du t.',
        if (user.has(Features.studentWork)) 'Travaux',
        if (user.has(Features.agenda)) 'Agenda',
        if (user.has(Features.courseSpace)) 'Mes cours',
        if (user.has(Features.quizTake)) 'Quiz',
      ].take(4).toList();

  group('the delivered bar', () {
    test('is Accueil · Travaux · Quiz with the defaults of §4', () {
      // Timetable, agenda and course space are the three the establishment does not run; work and
      // quiz are on. The design names this exact bar, so it is asserted exactly.
      final user = userWith(const {
        Features.timetable: false,
        Features.agenda: false,
        Features.courseSpace: false,
        Features.studentWork: true,
        Features.quizTake: true,
      });

      expect(barFor(user), ['Accueil', 'Travaux', 'Quiz']);
    });

    test('keeps the original four when everything is on, promoting nothing', () {
      final user = userWith(const {
        Features.timetable: true,
        Features.studentWork: true,
        Features.agenda: true,
        Features.courseSpace: true,
        Features.quizTake: true,
      });

      // Four is the cap: « Mes cours » and « Quiz » stay tiles on the home screen, which is the
      // arrangement the handoff drew.
      expect(barFor(user), ['Accueil', 'Emploi du t.', 'Travaux', 'Agenda']);
    });

    test('promotes one tile when exactly one place frees', () {
      final user = userWith(const {
        Features.timetable: false,
        Features.studentWork: true,
        Features.agenda: true,
        Features.courseSpace: true,
        Features.quizTake: true,
      });

      // « Mes cours » before « Quiz », in the order §10.2 names them.
      expect(barFor(user), ['Accueil', 'Travaux', 'Agenda', 'Mes cours']);
    });

    test('never removes Accueil, even with the whole catalogue off', () {
      final user = userWith(const {
        Features.timetable: false,
        Features.studentWork: false,
        Features.agenda: false,
        Features.courseSpace: false,
        Features.quizTake: false,
      });

      expect(barFor(user), ['Accueil']);
    });

    test('never draws more than four', () {
      final user = userWith(const {});

      expect(barFor(user).length, 4);
    });
  });

  group('reading the catalogue', () {
    test('parses the object the profile carries', () {
      final user = AppUser.fromJson(const {
        'id': 7,
        'username': 'aagonsanou',
        'roles': ['ROLE_STUDENT'],
        'features': {'agenda': false, 'student_work': true},
      });

      expect(user.has(Features.agenda), isFalse);
      expect(user.has(Features.studentWork), isTrue);
    });

    test('an unknown or absent key shows the feature rather than hiding it', () {
      // The failure that matters is the asymmetric one: a backend that has not shipped the field
      // yet, or a key renamed on one side only, must leave the app usable. Hiding everything on a
      // missing map would blank the whole app over a deployment ordering.
      final older = AppUser.fromJson(const {
        'id': 7,
        'username': 'aagonsanou',
        'roles': ['ROLE_STUDENT'],
      });

      expect(older.features, isEmpty);
      expect(older.has(Features.agenda), isTrue);
      expect(barFor(older), ['Accueil', 'Emploi du t.', 'Travaux', 'Agenda']);
    });
  });
}
