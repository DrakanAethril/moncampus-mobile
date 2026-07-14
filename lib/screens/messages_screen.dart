import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_thread.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../theme/app_theme.dart';
import 'message_thread_screen.dart';

/// Messages tab (design 3e) - inbox/sent/archived folder switcher + thread list. Browsing only,
/// same scope decision as the backend (App\Controller\Api\MessagesController) - no compose button
/// yet (the design's "✎" FAB has nothing to open to).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.onUnreadChanged});

  /// Called after returning from a thread (which marks it read server-side) so MainShell's tab
  /// badge can catch up.
  final VoidCallback? onUnreadChanged;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messagingService = MessagingService();

  String _folder = MessagingService.folderInbox;
  List<MessageThreadSummary>? _threads;
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final threads = await _messagingService.fetchThreads(token, folder: _folder);
      if (mounted) {
        setState(() {
          _threads = threads;
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

  void _selectFolder(String folder) {
    if (folder == _folder) return;
    setState(() => _folder = folder);
    _load();
  }

  Future<void> _openThread(MessageThreadSummary thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MessageThreadScreen(threadId: thread.id, subject: thread.subject)),
    );
    widget.onUnreadChanged?.call();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Messagerie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFolderChip(MessagingService.folderInbox, 'Réception'),
              const SizedBox(width: 6),
              _buildFolderChip(MessagingService.folderSent, 'Envoyés'),
              const SizedBox(width: 6),
              _buildFolderChip(MessagingService.folderArchived, 'Archivés'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderChip(String folder, String label) {
    final isSelected = folder == _folder;

    return GestureDetector(
      onTap: () => _selectFolder(folder),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.navy : const Color(0xFFBCD4E6),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.redTx)),
          ),
        ],
      );
    }

    final threads = _threads ?? [];

    if (threads.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Aucun message.', style: TextStyle(color: AppColors.faint))),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: threads.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildThreadRow(threads[index]),
    );
  }

  Widget _buildThreadRow(MessageThreadSummary thread) {
    final initials = _initialsOf(thread.counterpart);

    return InkWell(
      onTap: () => _openThread(thread),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: thread.unread ? AppColors.blueBg.withOpacity(0.4) : Colors.transparent,
          border: thread.unread ? const Border(left: BorderSide(color: AppColors.brand, width: 3)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.goldBg,
              child: Text(initials, style: const TextStyle(color: AppColors.goldTx, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.counterpart,
                          style: TextStyle(fontWeight: thread.unread ? FontWeight.bold : FontWeight.normal, fontSize: 14, color: AppColors.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_formatTime(thread.lastMessageAt), style: const TextStyle(fontSize: 11.5, color: AppColors.faint)),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    thread.subject,
                    style: TextStyle(
                      fontWeight: thread.unread ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    thread.snippet,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;

    if (isToday) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
  }
}
