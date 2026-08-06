import 'package:flutter/material.dart';

/// "#1B6BA8" as a [Color] - the API hands out per-formation colours as hex strings (see
/// App\Service\NameColorGenerator on the backend).
Color parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '');

  return Color(int.parse('FF$cleaned', radix: 16));
}
