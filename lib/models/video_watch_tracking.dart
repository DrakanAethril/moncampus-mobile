/// What one report of the video player carries - the body of
/// `POST /api/student-work/{id}/video/{fileId}/watch-progress`, read on the server by
/// App\Service\VideoWatchReport.
class VideoWatchReport {
  const VideoWatchReport({
    required this.percent,
    this.watchedSeconds = 0,
    this.events = const [],
  });

  final int percent;
  final int watchedSeconds;
  final List<Map<String, Object>> events;

  Map<String, Object> toJson() => {
        'percent': percent,
        'watchedSeconds': watchedSeconds,
        'events': events,
      };
}

/// The watch tracking of one video file, without a player: the mobile twin of
/// video_watch_controller.js on the web, and it has to stay one - the same student must not be
/// "à moitié" on one screen and "vu" on the other, nor show skips on one and none on the other.
///
/// Kept apart from the widget so the rules can be replayed in a test, position by position.
///
///  1. **Contiguity, not position.** What is credited is the furthest point reached *without
///     jumping*: a position beyond it, plus the tolerance, earns nothing until the gap itself has
///     been watched. Rewinding costs nothing.
///  2. **Crediting resumes from what the server knows**, not from zero.
///
/// Beside the percentage, and deciding nothing, it gathers what the teacher's statistics read:
///
///  - the wall-clock time really spent playing;
///  - each **skip** - a forward jump landing beyond both where the playhead was and what had been
///    credited. Jumping around inside what was already watched misses nothing;
///  - each **loss of focus** - the app leaving the foreground while the video played, which the
///    player answers by pausing it.
class VideoWatchTracking {
  VideoWatchTracking({required int initialPercent})
      : maxPercent = initialPercent,
        _sentPercent = initialPercent;

  /// How far ahead of the furthest point watched a tick may land and still count. Wide enough for
  /// the gap between two position events, far short of a seek.
  static const contiguityTolerance = Duration(milliseconds: 1500);

  /// Two ticks further apart than this are not playing - a stalled network, a phone asleep.
  static const _maxTickGap = Duration(seconds: 2);

  int maxPercent;
  int _sentPercent;
  Duration? _credited;
  Duration? _lastPosition;
  DateTime? _lastTickAt;
  double _pendingWatchedSeconds = 0;
  final List<Map<String, Object>> _pendingEvents = [];

  /// A playing tick. [now] is injectable for the tests.
  void tick(Duration position, Duration total, {DateTime? now}) {
    if (total.inMilliseconds == 0) return;
    final at = now ?? DateTime.now();

    _credited ??= Duration(milliseconds: total.inMilliseconds * maxPercent ~/ 100);

    // A jump since the previous tick: settled here, from where the playhead was.
    final last = _lastPosition;
    if (last != null && position > last + contiguityTolerance) {
      final from = last > _credited! ? last : _credited!;
      if (position > from + contiguityTolerance) {
        _pendingEvents.add({
          'type': 'skip',
          'from': from.inMilliseconds / 1000,
          'to': position.inMilliseconds / 1000,
        });
      }
    }
    _lastPosition = position;

    final lastTick = _lastTickAt;
    if (lastTick != null) {
      final elapsed = at.difference(lastTick);
      if (elapsed > Duration.zero && elapsed < _maxTickGap) {
        _pendingWatchedSeconds += elapsed.inMilliseconds / 1000;
      }
    }
    _lastTickAt = at;

    // Rule 1: beyond what has been watched, plus the tolerance, was jumped to.
    if (position > _credited! + contiguityTolerance) return;
    if (position > _credited!) _credited = position;

    final percent = _credited!.inMilliseconds * 100 ~/ total.inMilliseconds;
    if (percent > maxPercent) maxPercent = percent;

    // The last fraction of a second rarely produces an event: a file watched to the very end must
    // reach 100, or no travail would ever complete.
    if (total - _credited! <= const Duration(milliseconds: 250)) maxPercent = 100;
  }

  /// Playback stopped: the next tick starts a new stretch of playing time. The position is kept,
  /// so a seek made while paused is still seen as one when playback resumes.
  void paused() {
    _lastTickAt = null;
  }

  /// A seek the student did not make - the interactive video sending them back to a marker. It
  /// is not a skip, whichever way it goes.
  void repositioned(Duration position) {
    _lastPosition = position;
    _lastTickAt = null;
  }

  void focusLost(Duration position) {
    _pendingEvents.add({'type': 'focus_loss', 'at': position.inMilliseconds / 1000});
    _lastTickAt = null;
  }

  /// Whether anything new is waiting: a further point, a second of playing, an event.
  bool get hasPending =>
      maxPercent > _sentPercent || _pendingWatchedSeconds >= 1 || _pendingEvents.isNotEmpty;

  /// Whether 100 % has been reached and not reported yet - sent at once, not after the throttle.
  bool get completionPending => maxPercent >= 100 && _sentPercent < 100;

  /// The report to send, and the pending state emptied. The fraction of a second stays pending:
  /// flooring every report would lose a second in every five.
  VideoWatchReport? takeReport() {
    if (!hasPending) return null;

    final seconds = _pendingWatchedSeconds.floor();
    final report = VideoWatchReport(
      percent: maxPercent,
      watchedSeconds: seconds,
      events: List.of(_pendingEvents),
    );

    _sentPercent = maxPercent;
    _pendingWatchedSeconds -= seconds;
    _pendingEvents.clear();

    return report;
  }
}
