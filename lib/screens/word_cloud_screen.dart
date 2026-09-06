import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_cloud.dart';
import '../services/auth_service.dart';
import '../services/word_cloud_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Answering a « Nuage de mots » on the phone - the counterpart of the web's
/// templates/word_cloud/student.html.twig, screen for screen.
///
/// It is the same three things in the same order: the question, as many boxes as words are left,
/// and « Vos propositions » underneath. Nothing else - no access code and no QR code, which the
/// design took out on both sides: the class the cloud is asking is already known.
///
/// The screen decides nothing. Every limit it shows - the period, the quota, the length - is the
/// server's, and a refusal comes back as an ordinary answer naming which rule said no. What is
/// enforced here is only what saves a round trip: an empty box is not sent, and the field stops at
/// the character ceiling the API stated.
class WordCloudScreen extends StatefulWidget {
  const WordCloudScreen({super.key, required this.cloudId, required this.cloudName});

  final int cloudId;
  final String cloudName;

  @override
  State<WordCloudScreen> createState() => _WordCloudScreenState();
}

class _WordCloudScreenState extends State<WordCloudScreen> {
  final _service = WordCloudService();

  WordCloudState? _cloud;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// One controller per visible box, rebuilt whenever the quota moves.
  List<TextEditingController> _controllers = const [];

  /// True once something has been sent, so the home screen knows to refresh its banner.
  bool _sentSomething = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final cloud = await _service.fetchCloud(token, widget.cloudId);
      if (!mounted) return;
      setState(() {
        _cloud = cloud;
        _loading = false;
      });
      _rebuildBoxes(cloud);
    } on WordCloudException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    }
  }

  void _rebuildBoxes(WordCloudState cloud) {
    for (final controller in _controllers) {
      controller.dispose();
    }

    setState(() {
      _controllers = List.generate(
        cloud.canSubmit ? cloud.boxCount : 0,
        (_) => TextEditingController(),
      );
    });
  }

  Future<void> _send() async {
    final token = context.read<AuthService>().token;
    final cloud = _cloud;
    if (token == null || cloud == null || _sending) return;

    final words = _controllers
        .map((controller) => controller.text.trim())
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return;

    setState(() => _sending = true);

    try {
      final result = await _service.submit(token, cloud.id, words);
      if (!mounted) return;

      setState(() {
        _cloud = result.state;
        _sending = false;
        _sentSomething = _sentSomething || result.accepted.isNotEmpty;
      });
      _rebuildBoxes(result.state);

      // The refusals are named one by one rather than counted: « un mot refusé » tells nobody which
      // one to rewrite, and the server already worded each reason.
      final message = result.refusals.isEmpty
          ? (result.accepted.length > 1 ? 'Vos mots ont été envoyés.' : 'Votre mot a été envoyé.')
          : result.refusals.map((refusal) => '« ${refusal.word} » : ${refusal.message}').join('\n');

      _say(message, ok: result.refusals.isEmpty);
    } on WordCloudException catch (exception) {
      if (!mounted) return;
      setState(() => _sending = false);
      _say(exception.message, ok: false);
    }
  }

  void _say(String message, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: AppFont.sans(size: 13, color: Colors.white)),
      backgroundColor: ok ? AppColors.navy : AppColors.lateInk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            AppHeader(
              user: user,
              child: AppHeaderTitleRow(
                title: _cloud?.name ?? widget.cloudName,
                onBack: () => Navigator.of(context).pop(_sentSomething),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(error,
              textAlign: TextAlign.center,
              style: AppFont.sans(size: 13, color: AppColors.muted)),
        ),
      );
    }

    final cloud = _cloud;
    if (cloud == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Card(
          children: [
            Text(cloud.question,
                style: AppFont.spectral(size: 17, weight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 14),
            if (cloud.canSubmit) ..._form(cloud) else _closedNotice(cloud),
            if (cloud.ownWords.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('VOS PROPOSITIONS',
                  style: AppFont.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.faint,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [for (final word in cloud.ownWords) _OwnWordChip(word: word)],
              ),
            ],
          ],
        ),
        // Only when the teacher asked for it. Drawn from the words the server already weighted, so
        // the phone and the board show the same cloud.
        if (cloud.cloud != null) ...[
          const SizedBox(height: 14),
          _Card(
            children: [
              Text('LE NUAGE DE LA CLASSE',
                  style: AppFont.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.faint,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _Cloud(words: cloud.cloud!),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _form(WordCloudState cloud) => [
        for (var index = 0; index < _controllers.length; index++) ...[
          TextField(
            controller: _controllers[index],
            maxLength: cloud.maxCharacters,
            textInputAction:
                index == _controllers.length - 1 ? TextInputAction.done : TextInputAction.next,
            onSubmitted: (_) => index == _controllers.length - 1 ? _send() : null,
            style: AppFont.sans(size: 14, weight: FontWeight.w600, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Mot ${index + 1}…',
              hintStyle: AppFont.sans(size: 14, color: AppColors.faint),
              filled: true,
              fillColor: AppColors.surface,
              // The counter is hidden: the ceiling is a guard rail, not a target, and a « 0/30 »
              // under every box turns writing one word into filling a form.
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.brand),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              disabledBackgroundColor: AppColors.chevron,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_sending ? 'Envoi…' : 'Envoyer',
                style: AppFont.sans(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ];

  /// Why the boxes are gone. The server refuses regardless - this only explains.
  Widget _closedNotice(WordCloudState cloud) {
    final message = cloud.isScheduled
        ? 'Ce nuage n’est pas encore ouvert.'
        : cloud.isClosed
            ? 'Les soumissions sont closes.'
            : 'Vous avez envoyé tous vos mots.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: AppFont.sans(size: 13, color: AppColors.muted)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// One of this student's own words. A refused one is struck through rather than hidden: it left the
/// cloud, not the record, and a word that simply vanished would leave somebody wondering.
class _OwnWordChip extends StatelessWidget {
  const _OwnWordChip({required this.word});

  final WordCloudOwnWord word;

  @override
  Widget build(BuildContext context) {
    final ink = word.rejected ? AppColors.lateInk : AppColors.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: word.rejected ? AppColors.lateBg : AppColors.surfaceAlt,
        border: Border.all(color: word.rejected ? AppColors.lateBorder : AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        word.text,
        style: AppFont.sans(
          size: 12.5,
          weight: FontWeight.w600,
          color: ink,
        ).copyWith(decoration: word.rejected ? TextDecoration.lineThrough : null),
      ),
    );
  }
}

/// The class's cloud, sized by the server.
///
/// The four rungs map onto the handoff's light palette; three of them are already app tokens, and
/// « or foncé » is the one shade the app has no name for - AppColors.goldInk is a different value
/// for a different job (a pill's ink), so the exact hex is written here rather than borrowed.
class _Cloud extends StatelessWidget {
  const _Cloud({required this.words});

  static const _top = Color(0xFF9A7729);

  final List<WordCloudWord> words;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Text('Aucun mot pour le moment.',
          style: AppFont.sans(size: 13, color: AppColors.faint));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final word in words)
          Text(
            word.word,
            style: AppFont.spectral(
              // Halved from the web's 15-44: those sizes are for a 1 140 px reading column, and a
              // 44 px word would take a phone's whole width on its own.
              size: word.size * 0.6,
              weight: FontWeight.w600,
              color: _colorOf(word.step),
            ),
          ),
      ],
    );
  }

  Color _colorOf(String step) => switch (step) {
        'top' => _top,
        'strong' => AppColors.navy,
        'mid' => AppColors.text,
        _ => AppColors.faint,
      };
}
