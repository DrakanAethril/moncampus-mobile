import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/school_mail.dart';
import '../services/auth_service.dart';
import '../services/school_mail_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/sheet_picker.dart';

/// Writing a mail (design_handoff_mobile 5d): Annuler / Nouveau mail / Envoyer, the sender address
/// that cannot be changed, the recipient, the subject, the body, and the default signature shown
/// greyed out under it - it is appended server-side at send time, so it is never editable here.
///
/// The démarche row is the one addition to the mockup: every school mail belongs to one (principe
/// 6, and the gold chip of 5b/5c reads it), and a reply inherits the démarche of the mail it
/// answers - it is only asked for when starting from scratch.
class SchoolMailComposeScreen extends StatefulWidget {
  const SchoolMailComposeScreen({
    super.key,
    this.replyToId,
    this.recipient,
    this.subject,
    this.quotedBody,
    this.application,
  });

  final int? replyToId;
  final String? recipient;
  final String? subject;
  final String? quotedBody;
  final String? application;

  @override
  State<SchoolMailComposeScreen> createState() =>
      _SchoolMailComposeScreenState();
}

class _SchoolMailComposeScreenState extends State<SchoolMailComposeScreen> {
  final _service = SchoolMailService();
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  ComposeMeta? _meta;
  String? _application;
  final List<File> _attachments = [];
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _toController.text = widget.recipient ?? '';
    _subjectController.text = widget.subject ?? '';
    _application = widget.application;
    if (widget.quotedBody != null) {
      _bodyController.text = '\n\n----------\n${widget.quotedBody}';
    }
    _loadMeta();
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final meta = await _service.fetchComposeMeta(token);
      if (mounted) setState(() => _meta = meta);
    } catch (_) {
      // The screen still works without it: only the address and the signature preview are missing.
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    setState(() => _attachments.addAll(
        result.paths.whereType<String>().map(File.new)));
  }

  Future<void> _pickApplication() async {
    final names = _meta?.applications ?? const <String>[];
    final labels = [...names, 'Nouvelle candidature…'];

    final picked = await showSheetPicker(
      context,
      labels: labels,
      selectedIndex: names.indexOf(_application ?? ''),
    );

    if (picked == null || !mounted) return;

    if (picked < names.length) {
      setState(() => _application = names[picked]);
      return;
    }

    final created = await _askApplicationName();
    if (created != null && mounted) setState(() => _application = created);
  }

  Future<String?> _askApplicationName() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Candidature',
            style: AppFont.spectral(size: 17, color: AppColors.navy)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom de l\'entreprise'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler',
                style: AppFont.sans(size: 13, color: AppColors.faint)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text('Valider',
                style: AppFont.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong)),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final to = _toController.text.trim();
    final subject = _subjectController.text.trim();
    final application = _application?.trim() ?? '';

    if (to.isEmpty || subject.isEmpty || application.isEmpty) {
      setState(() => _error = application.isEmpty
          ? 'Rattachez ce mail à une candidature.'
          : 'Destinataire et objet sont nécessaires.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _service.send(
        token,
        to: to,
        subject: subject,
        body: _bodyController.text,
        application: application,
        replyToId: widget.replyToId,
        attachments: _attachments,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SchoolMailException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de contacter le serveur.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppNavBar(
            title: widget.replyToId != null ? 'Réponse' : 'Nouveau mail',
            centerTitle: true,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text('Annuler',
                  style: AppFont.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.headerLight)),
            ),
            trailing: GestureDetector(
              onTap: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Envoyer',
                            style: AppFont.sans(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppColors.gold)),
                        const SizedBox(width: 6),
                        const AppIcon(AppIcons.send,
                            size: 14,
                            color: AppColors.gold,
                            strokeWidth: 2.2),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lateBg,
                      border: Border.all(color: AppColors.lateBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: AppFont.sans(
                            size: 12.5, color: AppColors.lateInk)),
                  ),
                _FieldRow(
                  label: 'De',
                  child: Text(
                    _meta?.address ?? '',
                    style: AppFont.sans(size: 13.5, color: AppColors.text),
                  ),
                ),
                _FieldRow(
                  label: 'À',
                  child: widget.recipient != null
                      ? _RecipientChip(label: widget.recipient!)
                      : TextField(
                          controller: _toController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: _fieldDecoration('adresse@entreprise.fr'),
                          style: AppFont.sans(
                              size: 13.5, color: AppColors.ink),
                        ),
                ),
                _FieldRow(
                  label: 'Objet',
                  child: TextField(
                    controller: _subjectController,
                    decoration: _fieldDecoration("Objet du mail"),
                    style: AppFont.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                ),
                _FieldRow(
                  label: 'Cand.',
                  child: GestureDetector(
                    onTap: _pickApplication,
                    child: _application == null
                        ? Text('Rattacher à une candidature',
                            style: AppFont.sans(
                                size: 13.5, color: AppColors.faint))
                        : _RecipientChip(label: _application!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 0),
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    minLines: 8,
                    keyboardType: TextInputType.multiline,
                    decoration: _fieldDecoration('Votre message'),
                    style: AppFont.sans(
                        size: 13.5, color: AppColors.text, height: 1.7),
                  ),
                ),
                if ((_meta?.signature ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: Text(
                      // The em dash is the usual signature delimiter, drawn here as in the
                      // reference; what follows it is the signature the server will append.
                      '—\n${_meta!.signature}',
                      style: AppFont.sans(
                          size: 12.5, color: AppColors.faint, height: 1.6),
                    ),
                  ),
              ],
            ),
          ),
          _attachmentBar(),
        ],
      ),
    );
  }

  Widget _attachmentBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          18, 8, 18, 16 + MediaQuery.of(context).padding.bottom),
      color: AppColors.surface,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final file in _attachments)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.paperclip,
                      size: 12, color: AppColors.text),
                  const SizedBox(width: 7),
                  Text(file.path.split('/').last,
                      style:
                          AppFont.sans(size: 12, color: AppColors.text)),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: () => setState(() => _attachments.remove(file)),
                    child: const AppIcon(AppIcons.close,
                        size: 11, color: AppColors.faint, strokeWidth: 2.4),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _pickAttachments,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.chevron,
                    style: BorderStyle.solid,
                    width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+ Joindre',
                  style: AppFont.sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.brandStrong)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: hint,
        hintStyle: AppFont.sans(size: 13.5, color: AppColors.faint),
      );
}

/// One labelled row of the compose header, ruled off from the next.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: AppFont.sans(size: 13.5, color: AppColors.faint)),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppFont.sans(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.brandStrong),
        ),
      ),
    );
  }
}
