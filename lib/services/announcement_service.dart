import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/announcement.dart';
import 'api_config.dart';

class AnnouncementException implements Exception {
  AnnouncementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AnnouncementService {
  AnnouncementService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Announcement>> fetchAnnouncements(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/announcements');
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw AnnouncementException('Impossible de charger les annonces.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return (body['announcements'] as List<dynamic>)
        .map((announcement) => Announcement.fromJson(announcement as Map<String, dynamic>))
        .toList();
  }
}
