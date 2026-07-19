import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_thread.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'compose_message_screen.dart';

/// A single thread's messages (design 3i) - older messages collapsed (tap to expand), the latest
/// always open, expandable recipients row, Répondre/Transférer in a bottom bar. "Transférer" has
/// no backend endpoint of its own (there's no forward concept server-side) - it just opens
/// ComposeMessageScreen pre-filled with the original subject/body and no recipients, which is a
/// perfectly ordinary new thread once sent.
class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen(
      {super.key, required this.threadId, required this.subject});

  final int threadId;
  final String subject;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _messagingService = MessagingService();

  MessageThreadDetail? _thread;
  bool _loading = true;
  String? _error;
  bool _recipientsExpanded = false;
  final Set<int> _expandedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final thread =
          await _messagingService.fetchThread(token, widget.threadId);
      if (mounted) {
        setState(() {
          _thread = thread;
          _loading = false;
          if (thread.messages.isNotEmpty) {
            _expandedMessageIds.add(thread.messages.last.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openReply() async {
    final thread = _thread;
    if (thread == null) return;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ReplySheet(threadId: thread.id, messagingService: _messagingService),
    );

    if (sent ?? false) _load();
  }

  Future<void> _openForward() async {
    final thread = _thread;
    if (thread == null || thread.messages.isEmpty) return;

    final original = thread.messages.last;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposeMessageScreen(
          prefillSubject: 'Tr : ${thread.subject}',
          prefillBody:
              '\n\n---- Message transféré ----\n${original.plainTextBody}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppNavBar(
              title: widget.subject,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Text('‹',
                      style: TextStyle(
                          fontSize: 19,
                          color: Color(0xFFCFDDE9),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar:
          _thread?.canReply ?? false ? _buildActionBar() : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.redTx)),
        ),
      );
    }

    final thread = _thread!;
    final messages = thread.messages;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (thread.recipientNames.isNotEmpty) _buildRecipientsRow(thread),
        if (thread.recipientNames.isNotEmpty) const SizedBox(height: 10),
        for (var i = 0; i < messages.length; i++) ...[
          _buildMessageCard(messages[i], isLast: i == messages.length - 1),
          if (i != messages.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRecipientsRow(MessageThreadDetail thread) {
    final label = thread.audienceLabel ?? thread.recipientNames.first;
    final extra = thread.audienceLabel != null
        ? thread.recipientNames.length
        : thread.recipientNames.length - 1;

    return GestureDetector(
      onTap: extra > 0
          ? () => setState(() => _recipientsExpanded = !_recipientsExpanded)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                children: [
                  const TextSpan(text: 'À : '),
                  TextSpan(text: label),
                  if (extra > 0)
                    TextSpan(
                      text:
                          '  + $extra destinataire${extra > 1 ? 's' : ''} ${_recipientsExpanded ? '▴' : '▾'}',
                      style: const TextStyle(
                          color: AppColors.brand, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            if (_recipientsExpanded) ...[
              const SizedBox(height: 6),
              Text(
                thread.recipientNames.join(', '),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.text, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(MessageItem message, {required bool isLast}) {
    final expanded = _expandedMessageIds.contains(message.id);

    if (!expanded) {
      return InkWell(
        onTap: () => setState(() => _expandedMessageIds.add(message.id)),
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: .75,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _buildAvatar(message.author),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(message.author,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.ink))),
                          Text(_formatDateTime(message.sentAt),
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.faint)),
                        ],
                      ),
                      Text(
                        message.plainTextBody.split('\n').first,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.faint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: isLast
          ? null
          : () => setState(() => _expandedMessageIds.remove(message.id)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(message.author),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(message.author,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.ink))),
                        Text(_formatDateTime(message.sentAt),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.faint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(message.plainTextBody,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.text, height: 1.5)),
            ),
            if (message.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        message.attachments.map(_buildAttachmentChip).toList()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String author) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
          color: AppColors.blueBg, borderRadius: BorderRadius.circular(9)),
      alignment: Alignment.center,
      child: Text(_initialsOf(author),
          style: const TextStyle(
              color: AppColors.blueTx,
              fontWeight: FontWeight.bold,
              fontSize: 12.5)),
    );
  }

  String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildAttachmentChip(MessageAttachment attachment) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(attachment.url),
          mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.blueBg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 14, color: AppColors.blueTx),
            const SizedBox(width: 4),
            Text(attachment.label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blueTx,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Text('Ouvrir',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openReply,
                icon: const Icon(Icons.reply, size: 17),
                label: const Text('Répondre'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openForward,
                icon: const Icon(Icons.forward, size: 17),
                label: const Text('Transférer'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blueTx,
                    side: const BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Modal reply composer, opened from the thread's "Répondre" button - deliberately lighter than
/// full-screen ComposeMessageScreen since a reply has no audience/subject to pick.
class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.threadId, required this.messagingService});

  final int threadId;
  final MessagingService messagingService;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _bodyController = TextEditingController();
  final List<PendingAttachment> _attachments = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
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
    });
  }

  Future<void> _send() async {
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
      await widget.messagingService.reply(token, widget.threadId,
          body: _bodyController.text.trim(), attachments: _attachments);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(
          18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répondre',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.ink)),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!,
                style: const TextStyle(color: AppColors.redTx, fontSize: 12.5)),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _bodyController,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(hintText: 'Votre réponse…'),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _attachments
                  .map((a) => Chip(
                        label: Text(a.filename,
                            style: const TextStyle(fontSize: 11.5)),
                        onDeleted: () => setState(() => _attachments.remove(a)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Joindre'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blueTx,
                    side: const BorderSide(color: AppColors.border)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
