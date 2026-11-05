import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_live_state.dart';
import '../services/auth_service.dart';
import '../services/quiz_live_service.dart';
import '../theme/app_theme.dart';

/// Mobile counterpart to program/quiz_live_play.html.twig / quiz_live_play_controller.js -
/// waiting room / countdown / « regardez le tableau » / question (shape+color only, never text -
/// confirmed product decision) / own verdict / own rank / podium, all driven by one Mercure SSE
/// subscription plus periodic local countdown ticks anchored on server timestamps (never a
/// client-reported elapsed time).
///
/// How a question is answered depends on its `kind`: one tap sends a choice or a vote; several
/// shapes are ticked, or tapped in order, then « Valider »; a number is slid or typed; a word is
/// typed. The server checks the shape of every answer anyway.
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
  final List<int> _picked = [];
  double? _sliderValue;
  final _numberController = TextEditingController();
  final _textController = TextEditingController();
  int _remainingSeconds = 0;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _connection = widget.connection;
    _state = widget.connection.state;
    if ('question-opened' == _state.type) {
      _prepareQuestion(_state);
    }
    _startTick();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tickTimer?.cancel();
    _reconnectTimer?.cancel();
    _numberController.dispose();
    _textController.dispose();
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

    final isNewQuestion = 'question-opened' == state.type && ('question-opened' != _state.type || state.questionIndex != _state.questionIndex);
    if (isNewQuestion) {
      _prepareQuestion(state);
    } else if ('question-opened' == state.type && state.answered == true) {
      _answered = true;
    }
    if ('session-cancelled' == state.type) {
      _cancelled = true;
    }

    setState(() => _state = state);
  }

  /// A fresh question: nothing picked, the slider in the middle - like Kahoot's, the ends would
  /// read as an answer - and, for a phone reloaded after answering, nothing offered again.
  void _prepareQuestion(QuizLiveState state) {
    _picked.clear();
    _numberController.clear();
    _textController.clear();
    final range = state.range;
    _sliderValue = range == null ? null : range.min + ((range.max - range.min) / 2 / range.step).round() * range.step;
    _answered = state.answered == true;
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

      setState(() {
        _remainingSeconds = remaining > 0 ? (remaining / 1000).ceil() : 0;
        // Out of time: the server refuses the answer anyway, the screen stops offering it.
        if ('question-opened' == _state.type && remaining <= 0) _answered = true;
      });
    });
  }

  Future<void> _send(Map<String, Object> answer) async {
    if (_answered) return;

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _answered = true);

    try {
      await _quizLiveService.submitAnswer(token, widget.sessionId, answer);
    } catch (_) {
      // The tap already locked the UI - a failed POST just means no points this round, not worth
      // surfacing an error mid-game (same "silent background failure" convention as
      // MainShell._refreshUnreadCount()).
    }
  }

  // A shape: sent at once for a choice, ticked for a QCM multiple, numbered for an order.
  void _tap(QuizLiveAnswerOption option) {
    if (_answered) return;

    switch (_state.kind) {
      case 'multi':
        setState(() => _picked.contains(option.answerId) ? _picked.remove(option.answerId) : _picked.add(option.answerId));
      case 'order':
        if (!_picked.contains(option.answerId)) setState(() => _picked.add(option.answerId));
      default:
        setState(() => _picked
          ..clear()
          ..add(option.answerId));
        _send({'answerIds': [option.answerId]});
    }
  }

  bool get _canValidate {
    if (_answered) return false;
    return switch (_state.kind) {
      'multi' => _picked.isNotEmpty,
      'order' => _picked.length == (_state.answers?.length ?? 0),
      'number' => _state.range != null || double.tryParse(_numberController.text.replaceAll(',', '.')) != null,
      'text' => _textController.text.trim().isNotEmpty,
      _ => false,
    };
  }

  void _validate() {
    if (!_canValidate) return;

    switch (_state.kind) {
      case 'multi':
        _send({'answerIds': List<int>.of(_picked)});
      case 'order':
        _send({'order': List<int>.of(_picked)});
      case 'number':
        final value = _state.range != null ? _sliderValue : double.tryParse(_numberController.text.replaceAll(',', '.'));
        if (value != null) _send({'value': value});
      case 'text':
        _send({'text': _textController.text.trim()});
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
      case 'question-reading':
        return _buildReading();
      case 'question-opened':
        return _buildQuestion();
      case 'results':
        return _buildResults();
      case 'scoreboard':
        return _buildScoreboard();
      case 'session-finished':
        return _buildFinished();
      case 'session-cancelled':
        return _buildCancelled();
      case 'lobby':
      default:
        return _buildLobby();
    }
  }

  String get _counter => '${(_state.questionIndex ?? 0) + 1}/${_state.totalQuestions ?? '?'}';

  String get _hint {
    if (_state.isVote == true) return 'Votez pour une proposition';
    return switch (_state.kind) {
      'multi' => 'Plusieurs bonnes réponses : cochez-les, puis validez',
      'order' => 'Touchez les formes dans le bon ordre, puis validez',
      'number' => 'Choisissez la valeur, puis validez',
      'text' => 'Tapez votre réponse, puis validez',
      _ => 'Touchez la bonne forme',
    };
  }

  Widget _buildReading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('QUESTION $_counter', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 3)),
          const SizedBox(height: 18),
          const Text('Regardez le tableau', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_hint, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
          ),
        ],
      ),
    );
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
    final kind = _state.kind ?? 'choice';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              const Text('CONCOURS', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const Spacer(),
              Text('Q $_counter', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFF12344D), shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2.5)),
                alignment: Alignment.center,
                // Untimed question (its own "Illimité" mode, or a quiz with no default): the tick
                // has nothing to count down and the teacher is the one who moves on, so the badge
                // says so instead of showing the 0 the counter is still sitting on.
                child: Text(
                  null == _state.secondsPerQuestion ? '∞' : '$_remainingSeconds',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(_hint, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: switch (kind) {
              'number' => _buildNumber(),
              'text' => _buildText(),
              _ => _buildShapes(),
            },
          ),
        ),
        if ('choice' != kind)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                if ('order' == kind) ...[
                  TextButton(
                    onPressed: _answered ? null : () => setState(_picked.clear),
                    style: TextButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                    child: const Text('Recommencer'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _canValidate ? _validate : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF12344D)),
                    child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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

  // Two columns as soon as there are more than four shapes, like Kahoot's six.
  Widget _buildShapes() {
    final answers = _state.answers ?? const [];
    if (answers.length <= 4) {
      return Column(children: answers.map((option) => Expanded(child: _buildShapeButton(option))).toList());
    }

    final rows = <Widget>[];
    for (var i = 0; i < answers.length; i += 2) {
      rows.add(Expanded(
        child: Row(
          children: [
            Expanded(child: _buildShapeButton(answers[i])),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < answers.length ? _buildShapeButton(answers[i + 1]) : const SizedBox.shrink()),
          ],
        ),
      ));
    }

    return Column(children: rows);
  }

  Widget _buildShapeButton(QuizLiveAnswerOption option) {
    final at = _picked.indexOf(option.answerId);
    final selected = at >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: _colorFor(option.color),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _answered ? null : () => _tap(option),
          child: Container(
            decoration: selected ? BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 3)) : null,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _answered && !selected ? 0.55 : 1,
                  child: Text(_glyphFor(option.shape), style: const TextStyle(fontSize: 34, color: Colors.white)),
                ),
                // The place a shape was tapped at, for a remise en ordre.
                if ('order' == _state.kind && selected)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Text('${at + 1}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumber() {
    final range = _state.range;
    final unit = (_state.unit ?? '').isEmpty ? '' : ' ${_state.unit}';

    if (range == null) {
      return Center(
        child: TextField(
          controller: _numberController,
          enabled: !_answered,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
          decoration: InputDecoration(suffixText: unit.trim(), suffixStyle: const TextStyle(color: Color(0xFF9DB4C6))),
        ),
      );
    }

    final value = _sliderValue ?? range.min;
    final divisions = ((range.max - range.min) / range.step).round();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_formatNumber(value)}$unit',
          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        Slider(
          value: value.clamp(range.min, range.max),
          min: range.min,
          max: range.max,
          divisions: divisions > 0 && divisions <= 100000 ? divisions : null,
          activeColor: AppColors.gold,
          onChanged: _answered ? null : (next) => setState(() => _sliderValue = next),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatNumber(range.min), style: const TextStyle(color: Color(0xFF9DB4C6))),
            Text(_formatNumber(range.max), style: const TextStyle(color: Color(0xFF9DB4C6))),
          ],
        ),
      ],
    );
  }

  Widget _buildText() {
    return Center(
      child: TextField(
        controller: _textController,
        enabled: !_answered,
        maxLength: 200,
        autocorrect: false,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.send,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _validate(),
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(counterText: ''),
      ),
    );
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2).replaceAll('.', ',');

  // The verdict comes from the server, under this phone's participant id - it survives a
  // reconnect, which a choice remembered on this screen did not.
  Widget _buildResults() {
    final mine = _findMyEntry(_state.leaderboard);
    final outcome = _state.outcomes?['${_connection.participantId}'];
    final isVote = _state.isVote == true;

    final String label;
    final Color color;
    if (outcome == null || !outcome.answered) {
      label = 'Pas de réponse';
      color = const Color(0xFFFF9B8F);
    } else if (isVote) {
      label = '✓ Vote enregistré';
      color = AppColors.gold;
    } else if (outcome.correct == true) {
      label = '✓ Bonne réponse';
      color = const Color(0xFF7FD99A);
    } else {
      label = '✗ Mauvaise réponse';
      color = const Color(0xFFFF9B8F);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          if (!isVote) ...[
            const SizedBox(height: 10),
            Text('+ ${outcome?.points ?? 0} points', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 18)),
          ],
          const SizedBox(height: 18),
          Text('${mine?.score ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Ton classement : ${mine != null ? '#${mine.rank}' : '—'}', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    final mine = _findMyEntry(_state.leaderboard);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('CLASSEMENT', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 3)),
          const SizedBox(height: 18),
          Text(mine != null ? '#${mine.rank}' : '—', style: const TextStyle(color: AppColors.gold, fontSize: 60, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${mine?.score ?? 0} pts', style: const TextStyle(color: Color(0xFF9DB4C6), fontSize: 15)),
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
      'purple' => const Color(0xFF7A4FB5),
      'teal' => const Color(0xFF1D8584),
      _ => AppColors.brand,
    };

String _glyphFor(String shape) => switch (shape) {
      'triangle' => '▲',
      'square' => '■',
      'circle' => '●',
      'diamond' => '◆',
      'pentagon' => '⬟',
      'triangle-down' => '▼',
      _ => '',
    };
