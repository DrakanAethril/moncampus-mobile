/// Gestion > Matériel, as the phone sees it (moncampus Api\EquipmentController).
///
/// The server decides which gestures a piece accepts ([EquipmentItem.actions]); the app only
/// names them. That keeps the status rules - a missing mouse can only be found, a broken one only
/// repaired - in one place, the ledger on the server.
library;

/// The gestures, with the French the web screens use for them.
abstract final class EquipmentAction {
  static const deploy = 'deploy';
  static const returnToStock = 'return';
  static const missing = 'missing';
  static const outOfOrder = 'out_of_order';
  static const found = 'found';
  static const repaired = 'repaired';
  static const intake = 'intake';

  static const labels = <String, String>{
    deploy: 'Utilisé',
    returnToStock: 'Disponible',
    missing: 'Disparu',
    outOfOrder: 'Hors d’usage',
    found: 'Retrouvé',
    repaired: 'Réparé',
    intake: 'Ajouter au stock',
  };

  /// A lost or broken piece: the two gestures that ask why.
  static bool isIncident(String action) => action == missing || action == outOfOrder;

  /// Where saying the room makes sense - put into service, or where it happened. Always optional.
  static bool takesRoom(String action) => action == deploy || isIncident(action);

  static String label(String action) => labels[action] ?? action;
}

/// The causes of an incident, in the order of the web form.
abstract final class EquipmentCause {
  static const values = <String, String>{
    'wear': 'Usure normale',
    'accident': 'Accident',
    'damage': 'Dégradation',
    'theft': 'Vol',
    'breakdown': 'Panne',
    'unknown': 'Inconnue',
  };
}

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.room,
    required this.typeName,
    required this.actions,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
        id: json['id'] as int,
        code: json['code'] as String,
        status: json['status'] as String,
        statusLabel: json['statusLabel'] as String,
        room: json['room'] as String?,
        typeName: json['typeName'] as String,
        actions: (json['actions'] as List<dynamic>).cast<String>(),
      );

  final int id;
  final String code;
  final String status;
  final String statusLabel;
  final String? room;
  final String typeName;
  final List<String> actions;
}

class EquipmentType {
  const EquipmentType({
    required this.id,
    required this.name,
    required this.category,
    required this.unitTracked,
    required this.available,
    required this.inUse,
    required this.level,
  });

  factory EquipmentType.fromJson(Map<String, dynamic> json) => EquipmentType(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String?,
        unitTracked: json['unitTracked'] as bool,
        available: json['available'] as int,
        inUse: json['inUse'] as int,
        level: json['level'] as String,
      );

  final int id;
  final String name;
  final String? category;
  final bool unitTracked;
  final int available;
  final int inUse;

  /// green / gold / red - the stock badge of the web list.
  final String level;

  /// What the phone offers on a type: a delivery for a unit-tracked one (its pieces are moved
  /// through their own code), every quantity gesture otherwise.
  List<String> get actions => unitTracked
      ? const [EquipmentAction.intake]
      : const [
          EquipmentAction.deploy,
          EquipmentAction.returnToStock,
          EquipmentAction.missing,
          EquipmentAction.outOfOrder,
          EquipmentAction.found,
          EquipmentAction.repaired,
          EquipmentAction.intake,
        ];
}

class EquipmentRoom {
  const EquipmentRoom({required this.id, required this.name});

  factory EquipmentRoom.fromJson(Map<String, dynamic> json) =>
      EquipmentRoom(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

/// A label code read back: the pieces it names, and - when the check digit was wrong - the piece
/// it nearly names, offered as a suggestion and never as a match.
class EquipmentLookup {
  const EquipmentLookup({required this.items, required this.suggestions, required this.wrongCheckDigit});

  factory EquipmentLookup.fromJson(Map<String, dynamic> json) => EquipmentLookup(
        items: (json['items'] as List<dynamic>)
            .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        suggestions: (json['suggestions'] as List<dynamic>)
            .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        wrongCheckDigit: json['wrongCheckDigit'] as bool,
      );

  final List<EquipmentItem> items;
  final List<EquipmentItem> suggestions;
  final bool wrongCheckDigit;
}

/// What a gesture needs besides its name. Everything is optional except what the gesture asks
/// for: a quantity on a type, a cause on an incident.
class EquipmentMovement {
  const EquipmentMovement({
    required this.action,
    this.quantity,
    this.origin,
    this.cause,
    this.roomId,
    this.note,
  });

  final String action;
  final int? quantity;

  /// available / in_use - where lost or broken pieces of a quantity type were taken from.
  final String? origin;
  final String? cause;
  final int? roomId;
  final String? note;

  Map<String, dynamic> toJson() => {
        'action': action,
        if (quantity != null) 'quantity': quantity,
        if (origin != null) 'origin': origin,
        if (cause != null) 'cause': cause,
        if (roomId != null) 'roomId': roomId,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };
}
