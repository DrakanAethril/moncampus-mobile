import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_thread.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';

/// A single thread's messages (design 3e drill-down, not separately mocked). Read-only - no reply
/// composer yet, matching the backend's scope decision even when canReply is true.
class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({super.key, required this.threadId, required this.subject});

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    try {
      final thread = await _messagingService.fetchThread(token, widget.threadId);
      if (mounted) {
        setState(() {
          _thread = thread;
          _loading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: _buildBody(),
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
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.redTx)),
        ),
      );
    }

    final messages = _thread!.messages;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildMessageCard(messages[index]),
    );
  }

  Widget _buildMessageCard(MessageItem message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(message.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink)),
              ),
              Text(_formatDateTime(message.sentAt), style: const TextStyle(fontSize: 11.5, color: AppColors.faint)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.plainTextBody, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4)),
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.attachments.map(_buildAttachmentChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentChip(MessageAttachment attachment) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(attachment.url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 14, color: AppColors.blueTx),
            const SizedBox(width: 4),
            Text(attachment.label, style: const TextStyle(fontSize: 12, color: AppColors.blueTx, fontWeight: FontWeight.w600)),
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
