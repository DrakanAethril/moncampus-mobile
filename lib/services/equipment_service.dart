import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/equipment.dart';
import 'api_config.dart';

class EquipmentException implements Exception {
  EquipmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mobile counterpart to moncampus Api\EquipmentController.
///
/// A refused gesture (not enough in stock, a piece whose status changed meanwhile, a missing cause)
/// comes back as a 422 carrying the web's own French sentence, and is thrown with it so the screen
/// shows exactly what the web would have flashed.
class EquipmentService {
  EquipmentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<EquipmentLookup> lookup(String token, String code) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/equipment/lookup')
        .replace(queryParameters: {'code': code});
    final response = await _client.get(uri, headers: _headers(token));
    _check(response, 'Impossible de chercher ce code.');

    return EquipmentLookup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<EquipmentType>> types(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/equipment/types'),
      headers: _headers(token),
    );
    _check(response, 'Impossible de charger le matériel.');

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['types'] as List<dynamic>)
        .map((e) => EquipmentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EquipmentRoom>> rooms(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/equipment/rooms'),
      headers: _headers(token),
    );
    _check(response, 'Impossible de charger les salles.');

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['rooms'] as List<dynamic>)
        .map((e) => EquipmentRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One gesture on one piece; answers the piece as it now stands.
  Future<EquipmentItem> moveItem(String token, int itemId, EquipmentMovement movement) async {
    final response = await _post(token, '/api/equipment/items/$itemId/movements', movement);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return EquipmentItem.fromJson(body['item'] as Map<String, dynamic>);
  }

  /// One gesture on a type; answers its new counters and, after a delivery of pieces, their codes.
  Future<({EquipmentType type, List<String> createdCodes})> moveType(
      String token, int typeId, EquipmentMovement movement) async {
    final response = await _post(token, '/api/equipment/types/$typeId/movements', movement);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (
      type: EquipmentType.fromJson(body['type'] as Map<String, dynamic>),
      createdCodes: (body['createdCodes'] as List<dynamic>).cast<String>(),
    );
  }

  Future<http.Response> _post(String token, String path, EquipmentMovement movement) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode(movement.toJson()),
    );
    _check(response, 'Le mouvement n’a pas pu être enregistré.');

    return response;
  }

  void _check(http.Response response, String fallback) {
    if (response.statusCode == 200) return;

    if (response.statusCode == 422) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'];
        if (error is String && error.isNotEmpty) throw EquipmentException(error);
      } on FormatException {
        // Not the JSON refusal we expect - fall through to the generic sentence.
      }
    }

    throw EquipmentException(fallback);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
