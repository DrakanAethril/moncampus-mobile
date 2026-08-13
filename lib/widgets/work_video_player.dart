import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_cue.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import 'video_cue_overlay.dart';

/// One video file of a Watching travail, inside the consultation sheet (créas 5A).
///
/// The mobile twin of the web's video_watch_controller.js, and it has to stay one: the same
/// crediting rule whichever player the student used, or the same student would be "à moitié" on one
/// screen and "vu" on the other. The two rules are the audio player's, one medium over:
///
///  1. **Contiguity, not position.** What is tracked is the furthest point reached *without
///     jumping*. An event only counts when the playhead is still within reach of what has already
///     been watched; skipping ahead - mid-playback, or by pausing, dragging and playing on - lands
///     beyond it and earns nothing until the student comes back and watches through the gap.
///     Rewinding costs nothing.
///
///  2. **Crediting resumes from what the server knows**, not from zero.
///
/// Reporting is throttled to ~5s of playback; pausing, reaching the end and disposing all flush.
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

  /// Reports the furthest point reached, as a percentage. Called only when it has moved.
  final void Function(int percent) onProgress;

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

class _WorkVideoPlayerState extends State<WorkVideoPlayer> {
  VideoPlayerController? _controller;

  /// How far ahead of the furthest point watched an event may land and still count. Wide enough for
  /// the gap between two position ticks, far short of a seek.
  static const _contiguityTolerance = Duration(milliseconds: 1500);

  late int _maxPercent;
  late int _sentPercent;
  Duration? _creditedPosition;
  DateTime _lastReportedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _failed = false;
  bool _loading = false;

  /// The playhead as last reported, handed to the marker overlay - it is what decides whether a
  /// marker was walked onto or skipped past.
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _maxPercent = widget.file.percent;
    _sentPercent = widget.file.percent;
  }

  @override
  void dispose() {
    _flush();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
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
      _flush();
      if (mounted) setState(() {});

      return;
    }

    final total = value.duration;
    if (total.inMilliseconds == 0) return;

    // Rule 2: what was already credited, in this file's own milliseconds. Only knowable once the
    // duration is, hence here rather than in initState().
    _creditedPosition ??= Duration(milliseconds: total.inMilliseconds * _maxPercent ~/ 100);

    // Rule 1: a position beyond what has been watched, plus the tolerance, was jumped to.
    if (value.position > _creditedPosition! + _contiguityTolerance) {
      if (mounted) setState(() {});

      return;
    }

    if (value.position > _creditedPosition!) _creditedPosition = value.position;

    final credited = _creditedPosition!;
    final percent = credited.inMilliseconds * 100 ~/ total.inMilliseconds;
    if (percent > _maxPercent) _maxPercent = percent;

    // The last fraction of a second rarely produces an event: a file watched to the very end must
    // reach 100, or no travail would ever complete.
    if (total - credited <= const Duration(milliseconds: 250)) _maxPercent = 100;

    if (mounted) setState(() {});

    if (DateTime.now().difference(_lastReportedAt) < const Duration(seconds: 5) && _maxPercent < 100) {
      return;
    }

    _flush();
  }

  /// Nothing to send when the furthest point reached has already been reported - the server-side
  /// ratchet would ignore it anyway.
  void _flush() {
    if (_maxPercent <= _sentPercent) return;

    _sentPercent = _maxPercent;
    _lastReportedAt = DateTime.now();
    widget.onProgress(_maxPercent);
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
                    onSeek: (to) => controller.seekTo(to),
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
                          value: _maxPercent / 100,
                          minHeight: 4,
                          backgroundColor: AppColors.rule,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _failed ? 'Indisponible' : '$_maxPercent %',
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
