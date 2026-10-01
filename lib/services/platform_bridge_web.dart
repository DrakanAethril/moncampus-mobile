import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

// web/campus_web.js, loaded by index.html before the app.
@JS('campusWeb')
external _CampusWeb get _campusWeb;

extension type _CampusWeb._(JSObject _) implements JSObject {
  external _Subscription subscribe(String url, String token, JSFunction onMessage, JSFunction onEnd);
  external void saveFile(String name, String? mime, JSUint8Array bytes);
  external void forgetLoginToken();
  external _PendingTab openPending();
}

extension type _PendingTab._(JSObject _) implements JSObject {
  external void go(String url);
  external void close();
}

extension type _Subscription._(JSObject _) implements JSObject {
  external void close();
}

/// The stream could not be opened, or broke.
class EventStreamException implements Exception {
  EventStreamException(this.reason);

  final String reason;

  @override
  String toString() => 'EventStreamException: $reason';
}

/// The browser's half of the SSE reader (campusWeb.subscribe: fetch read as it arrives). Same
/// contract as the phone's: each event's data, no reconnection, done when the server closes,
/// an error when it fails. Cancelling the subscription aborts the request.
Stream<String> eventStreamData(Uri uri, String bearerToken) {
  late final StreamController<String> controller;
  _Subscription? subscription;

  controller = StreamController<String>(
    onListen: () {
      subscription = _campusWeb.subscribe(
        uri.toString(),
        bearerToken,
        ((JSString data) => controller.add(data.toDart)).toJS,
        ((JSString? reason) {
          if (reason != null) controller.addError(EventStreamException(reason.toDart));
          controller.close();
        }).toJS,
      );
    },
    onCancel: () => subscription?.close(),
  );

  return controller.stream;
}

/// Opens, in a new tab, the address [resolve] answers. The tab is opened before asking - this runs
/// inside the tap, which a browser requires of a new tab and which is over once the API has
/// answered (campusWeb.openPending) - then sent there, or closed when there is nothing to open.
Future<void> openResolvedUrl(Future<String?> Function() resolve) async {
  final tab = _campusWeb.openPending();
  try {
    final url = await resolve();
    url == null ? tab.close() : tab.go(url);
  } catch (_) {
    tab.close();
    rethrow;
  }
}

/// No « open with » in a browser: the file is handed over as a download.
Future<void> openDownloadedFile(String filename, Uint8List bytes, {String? mimeType}) async {
  _campusWeb.saveFile(filename, mimeType, bytes.toJS);
}

/// The magic link opens /campus-app/?login=<token> (MagicLoginService::requestMobileLink()). Read
/// once, then removed from the address.
String? takeLoginTokenFromAddress() {
  final token = Uri.base.queryParameters['login'];
  if (token == null || token.isEmpty) return null;
  _campusWeb.forgetLoginToken();

  return token;
}
