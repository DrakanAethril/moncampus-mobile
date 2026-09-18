import 'package:flutter_test/flutter_test.dart';
import 'package:moncampus_mobile/models/video_watch_tracking.dart';

/// The watch tracking of the mobile player, replayed position by position - the three cases the web
/// player is checked against (seek mid-playback, pause-drag-play, full watching), plus the detail
/// the teacher reads.
void main() {
  const total = Duration(seconds: 30);
  final start = DateTime(2026, 9, 18, 10);

  /// Plays from [from] to [to] (seconds), one tick every 250 ms of both media and wall clock.
  DateTime play(VideoWatchTracking tracking, double from, double to, DateTime clock) {
    var at = clock;
    for (var s = from; s <= to + 1e-9; s += .25) {
      tracking.tick(Duration(milliseconds: (s * 1000).round()), total, now: at);
      at = at.add(const Duration(milliseconds: 250));
    }

    return at;
  }

  test('a jump mid-playback is recorded as a skip and earns nothing', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    var clock = play(tracking, 0, 4, start);
    clock = play(tracking, 20, 22, clock);

    expect(tracking.maxPercent, 13);
    final report = tracking.takeReport()!;
    expect(report.events, [
      {'type': 'skip', 'from': 4.0, 'to': 20.0},
    ]);
  });

  test('pausing, dragging and playing on is a skip too', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    final clock = play(tracking, 0, 5, start);
    tracking.paused();
    play(tracking, 25, 26, clock.add(const Duration(seconds: 10)));

    expect(tracking.maxPercent, 16);
    expect(tracking.takeReport()!.events.single['type'], 'skip');
  });

  test('going back, or jumping inside what was watched, skips nothing', () {
    final tracking = VideoWatchTracking(initialPercent: 50);
    var clock = play(tracking, 0, 2, start);
    clock = play(tracking, 12, 13, clock);
    play(tracking, 1, 2, clock);

    expect(tracking.takeReport()!.events, isEmpty);
  });

  test('a full watching reaches 100 and counts the time played', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    play(tracking, 0, 30, start);

    expect(tracking.maxPercent, 100);
    expect(tracking.completionPending, isTrue);
    final report = tracking.takeReport()!;
    expect(report.watchedSeconds, 30);
    expect(tracking.completionPending, isFalse);
  });

  test('time spent paused is not counted as playing', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    final clock = play(tracking, 0, 3, start);
    tracking.paused();
    play(tracking, 3, 6, clock.add(const Duration(minutes: 5)));

    expect(tracking.takeReport()!.watchedSeconds, 6);
  });

  test('a loss of focus is reported with where the video stopped', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    play(tracking, 0, 7, start);
    tracking.takeReport();
    tracking.focusLost(const Duration(milliseconds: 7250));

    expect(tracking.takeReport()!.events, [
      {'type': 'focus_loss', 'at': 7.25},
    ]);
    expect(tracking.takeReport(), isNull);
  });

  test('a marker sending the student elsewhere is not a skip', () {
    final tracking = VideoWatchTracking(initialPercent: 0);
    final clock = play(tracking, 0, 3, start);
    tracking.repositioned(const Duration(seconds: 10));
    play(tracking, 10, 11, clock);

    expect(tracking.takeReport()!.events, isEmpty);
  });
}
