import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The stream could not be opened (the hub answered something other than 200).
class EventStreamException implements Exception {}

/// Hand-rolled SSE - Dart has no built-in EventSource. `http`'s streamed response is enough since
/// every Mercure update the app listens to is a single-line `data:` JSON blob with no custom
/// `event:` name - the client dispatches on the payload's own `type` key instead. Yields each
/// event's data. Unlike a browser's EventSource, this does not auto-reconnect: the caller retries
/// on error or done.
Stream<String> eventStreamData(Uri uri, String bearerToken) async* {
  final request = http.Request('GET', uri)
    ..headers['Authorization'] = 'Bearer $bearerToken'
    ..headers['Accept'] = 'text/event-stream';

  final streamedResponse = await http.Client().send(request);
  if (streamedResponse.statusCode != 200) {
    throw EventStreamException();
  }

  final lines = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter());

  final buffer = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
      }
      continue;
    }
    if (line.startsWith('data:')) {
      buffer.write(line.substring(5).trimLeft());
    }
    // 'id:'/'retry:' lines and ':'-prefixed keep-alive comments are intentionally ignored.
  }
}

/// A file downloaded behind the API's Bearer auth, which an external browser could not present -
/// written to a temp file and handed to the OS viewer.
Future<void> openDownloadedFile(String filename, Uint8List bytes, {String? mimeType}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}

/// Opens, outside the app, the address [resolve] answers - a document the API hands out only once
/// asked (it records the opening first). Nothing opens when it answers null.
Future<void> openResolvedUrl(Future<String?> Function() resolve) async {
  final url = await resolve();
  if (url != null) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Only the PWA is opened by an address carrying a login token; the phone gets its own through the
/// campusmanager:// deep link (AuthGate).
String? takeLoginTokenFromAddress() => null;
