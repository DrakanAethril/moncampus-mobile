import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_live_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_live_service.dart';
import '../theme/app_theme.dart';

/// Mobile counterpart to program/quiz_live_play.html.twig / quiz_live_play_controller.js -
/// waiting room / countdown / question (shape+color only, never text - confirmed product
/// decision) / reveal / podium, all driven by one Mercure SSE subscription plus periodic local
/// countdown ticks anchored on server timestamps (never a client-reported elapsed time).
class QuizLivePlayScreen extends StatefulWidget {
  const QuizLivePlayScreen({super.key, required this.sessionId, required this.connection});

  final int sessionId;
  final QuizLiveConnection connection;

  @override
  State<QuizLivePlayScreen> createState() => _QuizLivePlayScreenState();
}

class _QuizLivePlayScreenState extends State<QuizLivePlayScreen> {
  final _quizLiveService = QuizLiveService();

  late QuizLiveConnection _connection;
  late QuizLiveState _state;
  StreamSubscription<QuizLiveState>? _subscription;
  Timer? _tickTimer;
  Timer? _reconnectTimer;

  bool _answered = false;
  int? _selectedShapeIndex;
  int _remainingSeconds = 0;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _connection = widget.connection;
    _state = widget.connection.state;
    _startTick();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tickTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _quizLiveService
        .subscribe(
      mercurePublicUrl: _connection.mercurePublicUrl,
      topic: _connection.playersTopic,
      mercureToken: _connection.mercureToken,
    )
        .listen(
      _applyState,
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  }

  void _scheduleReconnect() {
    if (_cancelled || !mounted) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      final token = context.read<AuthService>().token;
      if (token == null || !mounted) return;

      try {
        final fresh = await _quizLiveService.fetchState(token, widget.sessionId);
        if (!mounted) return;
        setState(() {
          _connection = fresh;
        });
        _applyState(fresh.state);
        _subscribe();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  void _applyState(QuizLiveState state) {
    if (!mounted) return;

    if ('question-opened' == state.type) {
      _answered = false;
      _selectedShapeIndex = null;
    }
    if ('session-cancelled' == state.type) {
      _cancelled = true;
    }

    setState(() => _state = state);
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;

      final anchor = 'countdown-started' == _state.type ? _state.serverTime : _state.phaseStartedAt;
      final durationSeconds = 'countdown-started' == _state.type ? _state.countdownSeconds : _state.secondsPerQuestion;

      if (anchor == null || durationSeconds == null) return;

      final deadline = anchor.add(Duration(seconds: durationSeconds));
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;

      setState(() => _remainingSeconds = remaining > 0 ? (remaining / 1000).ceil() : 0);
    });
  }

  Future<void> _submitAnswer(QuizLiveAnswerOption option) async {
    if (_answered) return;

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _answered = true;
      _selectedShapeIndex = option.shapeIndex;
    });

    try {
      await _quizLiveService.submitAnswer(token, widget.sessionId, option.answerId);
    } catch (_) {
      // The tap already locked the UI - a failed POST just means no points this round, not worth
      // surfacing an error mid-game (same "silent background failure" convention as
      // MainShell._refreshUnreadCount()).
    }
  }

  // No `collection` package dependency in this project - a manual lookup instead of .firstOrNull.
  QuizLiveLeaderboardEntry? _findMyEntry(List<QuizLiveLeaderboardEntry>? entries) {
    if (entries == null) return null;
    for (final entry in entries) {
      if (entry.participantId == _connection.participantId) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2438),
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    switch (_state.type) {
      case 'countdown-started':
        return _buildCountdown();
      case 'question-opened':
        return _buildQuestion();
      case 'reveal':
        return _buildReveal();
      case 'session-finished':
        return _buildFinished();
      case 'session-cancelled':
        return _buildCancelled();
      case 'lobby':
      default:
        return _buildLobby();
    }
  }

  Widget _buildLobby() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
          const SizedBox(height: 16),
          const Text("Tu es dans la salle d'attente", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(
            _state.participantCount != null ? '${_state.participantCount} connectés' : '',
            style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "La première question s'affichera automatiquement au lancement.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7D99B0), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LE CONCOURS COMMENCE', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 3)),
          const SizedBox(height: 22),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x40C9A04E), width: 5)),
            alignment: Alignment.center,
            child: Text('$_remainingSeconds', style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final answers = _state.answers ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              const Text('CONCOURS', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const Spacer(),
              Text('Q ${(_state.questionIndex ?? 0) + 1}/${_state.totalQuestions ?? '?'}', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFF12344D), shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2.5)),
                alignment: Alignment.center,
                child: Text('$_remainingSeconds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: answers
                  .map((option) => Expanded(child: _buildShapeButton(option)))
                  .toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _answered ? '✓ Réponse envoyée' : ' ',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7D99B0), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildShapeButton(QuizLiveAnswerOption option) {
    final selected = _answered && _selectedShapeIndex == option.shapeIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: _colorFor(option.color),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _answered ? null : () => _submitAnswer(option),
          child: Container(
            decoration: selected ? BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 3)) : null,
            alignment: Alignment.center,
            child: Opacity(
              opacity: _answered && !selected ? 0.55 : 1,
              child: Text(_glyphFor(option.shape), style: const TextStyle(fontSize: 34, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final mine = _findMyEntry(_state.leaderboard);
    final resultLabel = _selectedShapeIndex == null
        ? ''
        : (_selectedShapeIndex == _state.correctShapeIndex ? '✓ Bonne réponse' : '✗ Mauvaise réponse');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(resultLabel, style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 18),
          Text('${mine?.score ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Ton classement : ${mine != null ? '#${mine.rank}' : '—'}', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFinished() {
    final mine = _findMyEntry(_state.finalLeaderboard);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('RÉSULTATS DU CONCOURS', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 3)),
          const SizedBox(height: 18),
          Text(mine != null ? '#${mine.rank}' : '—', style: const TextStyle(color: AppColors.gold, fontSize: 60, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${mine?.score ?? 0} pts', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 15)),
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: TextButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
            child: const Text('Retour au Quiz'),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelled() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Le concours a été annulé.', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: TextButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
            child: const Text('Retour au Quiz'),
          ),
        ],
      ),
    );
  }
}

Color _colorFor(String color) => switch (color) {
      'blue' => AppColors.brand,
      'gold' => AppColors.gold,
      'green' => const Color(0xFF2E7D4F),
      'red' => AppColors.redTx,
      _ => AppColors.brand,
    };

String _glyphFor(String shape) => switch (shape) {
      'triangle' => '▲',
      'square' => '■',
      'circle' => '●',
      'diamond' => '◆',
      _ => '',
    };
