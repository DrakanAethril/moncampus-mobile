import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/work_item.dart';
import '../theme/app_theme.dart';

/// One audio file of a Listening travail, inside the consultation sheet
/// (design_handoff_enregistrements_audio).
///
/// The mobile twin of the web's audio_listen_controller.js, and it must stay one: the handoff asks
/// for the same progress events and the same completion rule whichever player the student used. The
/// two rules that live here are therefore the same two:
///
///  1. "Le seek en avant ne compte pas comme écouté." What is tracked is not the position but the
///     furthest point reached CONTIGUOUSLY: an event only counts when the playhead is still within
///     reach of what has already been heard. Jumping ahead - mid-playback or by pausing, dragging
///     and playing on, which looks perfectly ordinary event by event - lands beyond that point and
///     earns nothing until the student comes back and listens through the gap. Rewinding costs
///     nothing: replaying covers ground already credited, and crediting resumes on passing the
///     furthest point.
///
///  2. Crediting resumes from what the server already knows, not from zero: a student who listened
///     to half yesterday would otherwise never reach 100% without replaying the whole file in one
///     go.
///
/// Reporting is throttled to ~5s of playback rather than every position event, and pausing, reaching
/// the end and leaving the sheet all flush what has been heard - the tail would otherwise be lost,
/// which on a short file is the difference between "écouté" and "à moitié écouté".
class WorkAudioPlayer extends StatefulWidget {
  const WorkAudioPlayer({
    super.key,
    required this.file,
    required this.onProgress,
  });

  final WorkAudioFile file;

  /// Reports the furthest point reached, as a percentage. Called only when it has moved.
  final void Function(int percent) onProgress;

  @override
  State<WorkAudioPlayer> createState() => _WorkAudioPlayerState();
}

class _WorkAudioPlayerState extends State<WorkAudioPlayer> {
  final _player = AudioPlayer();

  /// How far ahead of the furthest point heard an event may land and still count. Wide enough for
  /// the gap between two position events, which do not fire on a fixed beat; far short of a seek.
  static const _contiguityTolerance = Duration(milliseconds: 1500);

  late int _maxPercent;
  late int _sentPercent;
  Duration? _creditedPosition;
  DateTime _lastReportedAt = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _maxPercent = widget.file.percent;
    _sentPercent = widget.file.percent;

    _positionSubscription = _player.positionStream.listen(_onPosition);
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (!state.playing || state.processingState == ProcessingState.completed) {
        _flush();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _flush();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// The source is only loaded on the first tap: a sheet holding several files must not fetch them
  /// all at once over a school network.
  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();

      return;
    }

    if (!_ready) {
      try {
        await _player.setUrl(widget.file.url);
        _ready = true;
      } catch (_) {
        if (mounted) setState(() => _failed = true);

        return;
      }
    }

    // Replaying a finished file starts it over rather than doing nothing.
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }

    await _player.play();
  }

  void _onPosition(Duration position) {
    final total = _player.duration;
    if (total == null || total.inMilliseconds == 0 || !_player.playing) return;

    // Rule 2: what was already credited, expressed in this file's own milliseconds. Only knowable
    // once the duration is, hence here rather than in initState().
    _creditedPosition ??= Duration(
        milliseconds: total.inMilliseconds * _maxPercent ~/ 100);

    // Rule 1: a position beyond what has been heard, plus the tolerance, was jumped to.
    if (position > _creditedPosition! + _contiguityTolerance) return;

    if (position > _creditedPosition!) _creditedPosition = position;

    final credited = _creditedPosition!;
    final percent = credited.inMilliseconds * 100 ~/ total.inMilliseconds;
    if (percent > _maxPercent) _maxPercent = percent;

    // The last fraction of a second rarely produces an event: a file played to the very end must
    // reach 100, or no travail would ever complete.
    if (total - credited <= const Duration(milliseconds: 250)) _maxPercent = 100;

    if (mounted) setState(() {});

    if (DateTime.now().difference(_lastReportedAt) < const Duration(seconds: 5) &&
        _maxPercent < 100) {
      return;
    }

    _flush();
  }

  /// Nothing to send when the furthest point reached has already been reported: the server-side
  /// ratchet would ignore it anyway.
  void _flush() {
    if (_maxPercent <= _sentPercent) return;

    _lastReportedAt = DateTime.now();
    _sentPercent = _maxPercent;
    widget.onProgress(_maxPercent);
  }

  @override
  Widget build(BuildContext context) {
    final done = _maxPercent >= 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _failed ? null : _toggle,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    _player.playing ? Icons.pause : Icons.play_arrow,
                    size: 17,
                    color: AppColors.brandStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.sans(
                      size: 13, weight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.file.duration,
                style: AppFont.sans(size: 12, color: AppColors.faint),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _maxPercent / 100,
              minHeight: 6,
              backgroundColor: AppColors.rule,
              valueColor: AlwaysStoppedAnimation<Color>(
                  done ? AppColors.doneInk : AppColors.brand),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _failed
                ? "Ce fichier n'a pas pu être chargé."
                : (done
                    ? 'Écouté'
                    : (_maxPercent > 0 ? 'Écouté $_maxPercent %' : 'Non écouté')),
            style: AppFont.sans(
                size: 11.5,
                weight: FontWeight.w600,
                color: _failed ? AppColors.lateInk : AppColors.muted),
          ),
        ],
      ),
    );
  }
}
