import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_cue.dart';
import '../models/video_watch_tracking.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import 'video_cue_overlay.dart';

/// One video file of a Watching travail, inside the consultation sheet (créas 5A).
///
/// The mobile twin of the web's video_watch_controller.js, and it has to stay one. The rules -
/// contiguity rather than position, crediting resumed from what the server knows, and the detail
/// the teacher reads (playing time, skips, losses of focus) - live in [VideoWatchTracking], where a
/// test can replay them; this widget feeds it the playhead.
///
/// The video must not run while the student is elsewhere: the moment the app leaves the foreground
/// (another app, the notification shade, the phone locked), a playing video is paused and the pause
/// recorded - the web pauses on the page losing the focus, and this is that rule on a phone.
///
/// Reporting is throttled to ~5s of playback; pausing, reaching the end, leaving the app and
/// disposing all flush.
///
/// [onPosition] is what the interactive video hangs off: the cue overlay watches the playhead
/// through it rather than opening a second subscription on the same controller.
class WorkVideoPlayer extends StatefulWidget {
  const WorkVideoPlayer({
    super.key,
    required this.file,
    required this.onProgress,
    this.assignmentId,
    this.cues = const [],
    this.onCueAnswered,
  });

  final WorkVideoFile file;

  /// Reports the watching: the furthest point reached, plus the detail gathered since the last
  /// report. Called only when there is something new.
  final void Function(VideoWatchReport report) onProgress;

  /// The travail this file belongs to - only needed to answer a marker.
  final int? assignmentId;

  /// The interactive video's markers, when this travail has any (créas 5B). Empty for a plain
  /// watching travail, and the overlay then never builds.
  final List<VideoCuePoint> cues;

  /// Called once a marker has been answered, so the caller can refresh the list.
  final void Function(int cueId)? onCueAnswered;

  @override
  State<WorkVideoPlayer> createState() => _WorkVideoPlayerState();
}

class _WorkVideoPlayerState extends State<WorkVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  late final VideoWatchTracking _tracking;
  DateTime _lastReportedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _failed = false;
  bool _loading = false;

  /// Set when the video was paused because the app left the foreground, and cleared on the next
  /// play - what the caption below the bar says.
  bool _pausedForFocus = false;

  /// The playhead as last reported, handed to the marker overlay - it is what decides whether a
  /// marker was walked onto or skipped past.
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _tracking = VideoWatchTracking(initialPercent: widget.file.percent);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flush();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  /// `inactive` arrives first on any departure, `paused` after it; only a playing video is paused
  /// and recorded, so the second one finds it already stopped and adds nothing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
      _tracking.focusLost(controller.value.position);
      controller.pause();
      if (mounted) setState(() => _pausedForFocus = true);
    }

    _flush();
  }

  /// Loaded on the first tap: a sheet holding several files must not stream them all at once over
  /// a school network.
  Future<void> _toggle() async {
    final controller = _controller;

    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        // Replaying a finished file starts it over rather than doing nothing.
        if (controller.value.position >= controller.value.duration) {
          await controller.seekTo(Duration.zero);
        }
        if (mounted) setState(() => _pausedForFocus = false);
        await controller.play();
      }

      return;
    }

    setState(() => _loading = true);
    final created = VideoPlayerController.networkUrl(Uri.parse(widget.file.url));

    try {
      await created.initialize();
    } catch (_) {
      await created.dispose();
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }

      return;
    }

    created.addListener(_onTick);
    if (!mounted) {
      await created.dispose();

      return;
    }

    setState(() {
      _controller = created;
      _loading = false;
    });
    await created.play();
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;
    _position = value.position;
    _playing = value.isPlaying;

    if (!value.isPlaying) {
      _tracking.paused();
      _flush();
      if (mounted) setState(() {});

      return;
    }

    _tracking.tick(value.position, value.duration);
    if (mounted) setState(() {});

    if (DateTime.now().difference(_lastReportedAt) < const Duration(seconds: 5) &&
        !_tracking.completionPending) {
      return;
    }

    _flush();
  }

  /// Nothing to send when nothing is new - no further point, under a second played, no event.
  void _flush() {
    final report = _tracking.takeReport();
    if (report == null) return;

    _lastReportedAt = DateTime.now();
    widget.onProgress(report);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final playing = ready && controller.value.isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: ready ? controller.value.aspectRatio : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.black),
                if (ready) VideoPlayer(controller),
                if (_loading) const CircularProgressIndicator(color: Colors.white),
                if (!_loading)
                  GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: playing
                          ? const SizedBox.shrink()
                          : Icon(
                              _failed ? Icons.error_outline : Icons.play_circle_fill,
                              size: 54,
                              color: Colors.white.withOpacity(0.92),
                            ),
                    ),
                  ),
                // Over the picture, never beside it: the question is about what is on screen.
                if (widget.cues.isNotEmpty && widget.assignmentId != null && ready)
                  VideoCueOverlay(
                    assignmentId: widget.assignmentId!,
                    fileId: widget.file.id,
                    cues: widget.cues,
                    position: _position,
                    playing: _playing,
                    onPause: () => controller.pause(),
                    onResume: () => controller.play(),
                    onSeek: (to) {
                      // Sent back by a marker: not a skip, whichever way it goes.
                      _tracking.repositioned(to);
                      controller.seekTo(to);
                    },
                    onAnswered: widget.onCueAnswered ?? (_) {},
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFont.sans(
                              size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _tracking.maxPercent / 100,
                          minHeight: 4,
                          backgroundColor: AppColors.rule,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                      if (_pausedForFocus) ...[
                        const SizedBox(height: 5),
                        Text(
                          "Lecture mise en pause : l'application n'était plus au premier plan.",
                          style: AppFont.sans(size: 11, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _failed ? 'Indisponible' : '${_tracking.maxPercent} %',
                  style: AppFont.sans(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
