import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/app_user.dart';
import 'package:moncampus_mobile/models/equipment.dart';
import 'package:moncampus_mobile/models/features.dart';

/// What the phone reads off Api\EquipmentController, and the few rules it keeps on its own.
///
/// The status rules - which gesture a piece accepts - are the server's and come with the piece;
/// what belongs here is who sees the door, what a gesture sends, and that a wrong check digit is
/// read as a suggestion rather than a match.
void main() {
  AppUser user(List<String> roles, Map<String, bool> features) =>
      AppUser(id: 1, username: 'tester', roles: roles, features: features);

  group('the « Matériel » door', () {
    test('opens for a keeper of the inventory whose backend knows the feature', () {
      final keeper = user(const ['ROLE_SUPPORT-TECH'], const {'equipment': true});

      expect(keeper.keepsEquipment, isTrue);
      expect(keeper.hasStrictly(Features.equipment), isTrue);
    });

    test('stays shut for a teacher, even with the feature lit', () {
      expect(user(const ['ROLE_TEACHER'], const {'equipment': true}).keepsEquipment, isFalse);
    });

    /// An older backend has no /api/equipment: a missing key must not draw a door that answers 404,
    /// unlike the other features, whose unknown keys read as "on".
    test('stays shut when the backend does not know the feature yet', () {
      final keeper = user(const ['ROLE_STAFF'], const {});

      expect(keeper.has(Features.equipment), isTrue, reason: 'the lenient reading');
      expect(keeper.hasStrictly(Features.equipment), isFalse);
    });
  });

  group('EquipmentLookup', () {
    Map<String, dynamic> item(String code, List<String> actions) => {
          'id': 3,
          'code': code,
          'status': 'available',
          'statusLabel': 'Disponible',
          'room': null,
          'typeId': 9,
          'typeName': 'Souris',
          'actions': actions,
        };

    test('reads the piece and the gestures the server allows', () {
      final lookup = EquipmentLookup.fromJson({
        'items': [item('CA-0142-0', ['deploy', 'missing', 'out_of_order'])],
        'suggestions': [],
        'wrongCheckDigit': false,
      });

      expect(lookup.items.single.code, 'CA-0142-0');
      expect(lookup.items.single.actions, ['deploy', 'missing', 'out_of_order']);
    });

    test('keeps a mistyped code apart, as a suggestion', () {
      final lookup = EquipmentLookup.fromJson({
        'items': [],
        'suggestions': [item('CA-0142-0', ['deploy'])],
        'wrongCheckDigit': true,
      });

      expect(lookup.items, isEmpty);
      expect(lookup.suggestions.single.code, 'CA-0142-0');
      expect(lookup.wrongCheckDigit, isTrue);
    });
  });

  group('EquipmentType', () {
    EquipmentType type({required bool unitTracked}) => EquipmentType.fromJson({
          'id': 1,
          'name': 'Câbles',
          'category': null,
          'unitTracked': unitTracked,
          'available': 4,
          'inUse': 2,
          'onOrder': 0,
          'level': 'gold',
        });

    /// A labelled piece moves through its own code: its type only takes a delivery.
    test('a unit-tracked type only takes a delivery', () {
      expect(type(unitTracked: true).actions, [EquipmentAction.intake]);
    });

    test('a quantity type takes every gesture', () {
      expect(type(unitTracked: false).actions, contains(EquipmentAction.missing));
      expect(type(unitTracked: false).actions, contains(EquipmentAction.intake));
    });
  });

  group('EquipmentMovement', () {
    test('sends only what the gesture has, and no blank note', () {
      const movement = EquipmentMovement(action: 'missing', quantity: 2, origin: 'available', cause: 'theft', note: '  ');

      expect(movement.toJson(), {'action': 'missing', 'quantity': 2, 'origin': 'available', 'cause': 'theft'});
    });

    test('an incident asks why and may name the room; putting back does neither', () {
      expect(EquipmentAction.isIncident('out_of_order'), isTrue);
      expect(EquipmentAction.takesRoom('deploy'), isTrue);
      expect(EquipmentAction.takesRoom('return'), isFalse);
      expect(EquipmentAction.isIncident('found'), isFalse);
    });
  });
}
