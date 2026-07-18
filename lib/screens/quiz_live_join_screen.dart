import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/quiz_live_service.dart';
import '../theme/app_theme.dart';
import 'quiz_live_play_screen.dart';

/// Mobile counterpart to program/quiz_live_join.html.twig - display-name form, then pushes
/// [QuizLivePlayScreen] on success. Code-less: reached only from the Home screen's "Concours en
/// cours" banner (see quiz_live_active_session on HomeScreen), never a typed room code.
class QuizLiveJoinScreen extends StatefulWidget {
  const QuizLiveJoinScreen({super.key, required this.sessionId, required this.quizName, required this.hostName});

  final int sessionId;
  final String quizName;
  final String hostName;

  @override
  State<QuizLiveJoinScreen> createState() => _QuizLiveJoinScreenState();
}

class _QuizLiveJoinScreenState extends State<QuizLiveJoinScreen> {
  final _quizLiveService = QuizLiveService();
  late final TextEditingController _nameController;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user?.greetingName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final token = context.read<AuthService>().token;
    if (token == null || _nameController.text.trim().isEmpty) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final connection = await _quizLiveService.join(token, widget.sessionId, _nameController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizLivePlayScreen(sessionId: widget.sessionId, connection: connection),
        ),
      );
    } catch (e) {
      setState(() {
        _joining = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre le concours')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONCOURS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(widget.quizName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 3),
              Text('Lancé par ${widget.hostName}', style: const TextStyle(fontSize: 12.5, color: AppColors.faint)),
              const SizedBox(height: 24),
              const Text('Nom de participant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
              const SizedBox(height: 6),
              TextField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 4),
              const Text(
                "Par défaut : le nom de votre compte — c'est ce nom qui s'affiche au classement",
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.redTx)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _joining ? null : _join,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy),
                  child: _joining
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Rejoindre la salle d'attente"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
