import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/message_thread.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// New message (design 3h) - recipient chips with autocomplete (users +, for teachers/staff,
/// classes), subject, body, attachments. [prefillSubject]/[prefillBody] back the "Transférer"
/// action on MessageThreadScreen (a forward has no backend endpoint of its own - see that
/// screen's docblock - it's just compose pre-filled with the original content, recipients left
/// empty for the sender to pick again).
class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen(
      {super.key, this.prefillSubject, this.prefillBody});

  final String? prefillSubject;
  final String? prefillBody;

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _messagingService = MessagingService();
  final _recipientQueryController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  final List<RecipientCandidate> _recipients = [];
  final List<PendingAttachment> _attachments = [];
  List<RecipientCandidate> _suggestions = [];
  Timer? _debounce;
  bool _searching = false;
  bool _sending = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectController.text = widget.prefillSubject ?? '';
    _bodyController.text = widget.prefillBody ?? '';
    _recipientQueryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recipientQueryController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _recipientQueryController.text.trim();
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _searching = true);
    try {
      final results = await _messagingService.searchRecipients(token, query);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
      // Silent - a failed suggestion fetch just leaves the list empty, not worth an error banner.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addRecipient(RecipientCandidate candidate) {
    setState(() {
      if (!_recipients
          .any((r) => r.type == candidate.type && r.id == candidate.id)) {
        _recipients.add(candidate);
        _dirty = true;
      }
      _recipientQueryController.clear();
      _suggestions = [];
    });
  }

  void _removeRecipient(RecipientCandidate candidate) {
    setState(() => _recipients
        .removeWhere((r) => r.type == candidate.type && r.id == candidate.id));
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        if (file.bytes != null) {
          _attachments
              .add(PendingAttachment(filename: file.name, bytes: file.bytes!));
        }
      }
      _dirty = true;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _attachments.add(PendingAttachment(filename: picked.name, bytes: bytes));
      _dirty = true;
    });
  }

  Future<void> _send() async {
    if (_recipients.isEmpty) {
      setState(() => _error = 'Choisissez au moins un destinataire.');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _error = "L'objet est requis.");
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      setState(() => _error = 'Le message ne peut pas être vide.');
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _messagingService.compose(
        token,
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        recipients: _recipients,
        attachments: _attachments,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppNavBar(
              title: 'Nouveau message',
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: const Text('Annuler',
                    style: TextStyle(
                        color: Color(0xFFBCD4E6),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
              ),
              trailing: GestureDetector(
                onTap: _sending ? null : _send,
                child: Text(
                  'Envoyer',
                  style: TextStyle(
                      color: _sending ? AppColors.faint : AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5),
                ),
              ),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                color: AppColors.redBg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.redTx, fontSize: 12.5)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildRecipientsAndSubject(),
                  const SizedBox(height: 12),
                  _buildBodyCard(),
                  const SizedBox(height: 12),
                  _buildActionsRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsAndSubject() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                const Text('À :',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.faint)),
                for (final recipient in _recipients)
                  _buildRecipientChip(recipient),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _recipientQueryController,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Ajouter…'),
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          if (_searching || _suggestions.isNotEmpty) ...[
            const Divider(height: 1),
            ..._suggestions.map(_buildSuggestionRow),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                  border: InputBorder.none, isDense: true, labelText: 'Objet'),
              onChanged: (_) => _dirty = true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientChip(RecipientCandidate recipient) {
    final isProgram = recipient.isProgram;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isProgram ? AppColors.purpleBg : AppColors.blueBg,
        border: Border.all(
            color: isProgram ? AppColors.purpleBg : const Color(0xFFC6DDF0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isProgram ? '${recipient.label} (élèves)' : recipient.label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isProgram ? AppColors.purpleTx : AppColors.blueTx),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () => _removeRecipient(recipient),
            child: const Icon(Icons.close, size: 13, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(RecipientCandidate candidate) {
    final isProgram = candidate.isProgram;

    return InkWell(
      onTap: () => _addRecipient(candidate),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isProgram ? AppColors.purpleBg : AppColors.blueBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                isProgram ? Icons.groups_outlined : Icons.person_outline,
                size: 15,
                color: isProgram ? AppColors.purpleTx : AppColors.blueTx,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.ink)),
                  Text(candidate.sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _bodyController,
            maxLines: null,
            minLines: 6,
            decoration: const InputDecoration(
                border: InputBorder.none, hintText: 'Votre message…'),
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.ink, height: 1.5),
            onChanged: (_) => _dirty = true,
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.map(_buildAttachmentChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentChip(PendingAttachment attachment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.blueBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 14, color: AppColors.blueTx),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              attachment.filename,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.blueTx,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _attachments.remove(attachment)),
            child: const Icon(Icons.close, size: 13, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.attach_file, size: 16),
          label: const Text('Joindre'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blueTx,
              side: const BorderSide(color: AppColors.border)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_camera_outlined, size: 16),
          label: const Text('Photo'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blueTx,
              side: const BorderSide(color: AppColors.border)),
        ),
        const Spacer(),
        if (_dirty)
          const Text('Brouillon enregistré',
              style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
      ],
    );
  }
}
