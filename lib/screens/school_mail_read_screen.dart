import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../models/school_mail.dart';
import '../services/auth_service.dart';
import '../services/school_mail_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import 'school_mail_compose_screen.dart';
import 'school_mail_screen.dart' show ApplicationChip;

/// Reading a mail (design_handoff_mobile 5c): compact back bar, the subject in Spectral, the
/// démarche chip, who wrote it, the body, its attachments, and the fixed Répondre / Transférer bar.
class SchoolMailReadScreen extends StatefulWidget {
  const SchoolMailReadScreen({super.key, required this.messageId});

  final int messageId;

  @override
  State<SchoolMailReadScreen> createState() => _SchoolMailReadScreenState();
}

class _SchoolMailReadScreenState extends State<SchoolMailReadScreen> {
  final _service = SchoolMailService();

  SchoolMailDetail? _detail;
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
      final detail = await _service.fetchMessage(token, widget.messageId);
      if (mounted) setState(() => _detail = detail);
    } on SchoolMailException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de contacter le serveur.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppNavBar(
            title: 'Courrier école',
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const AppIcon(AppIcons.chevronLeft,
                  size: 18, color: AppColors.headerLight, strokeWidth: 2.2),
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: AppFont.sans(
                              size: 13, color: AppColors.muted)),
                    ),
                  )
                : detail == null
                    ? const Center(child: CircularProgressIndicator())
                    : _body(detail),
          ),
          if (detail != null) _actionBar(detail),
        ],
      ),
    );
  }

  Widget _body(SchoolMailDetail detail) {
    final message = detail.message;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          message.subject ?? '(sans objet)',
          style: AppFont.spectral(size: 18, color: AppColors.ink, height: 1.3),
        ),
        if (message.application != null) ...[
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: ApplicationChip(name: message.application!, large: true),
          ),
        ],
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.only(bottom: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: AppColors.blueSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  message.initials,
                  style: AppFont.sans(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: AppColors.brandStrong),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.name,
                      style: AppFont.sans(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.3),
                    ),
                    Text(
                      '${message.address} · ${FrenchDate.short(message.date)} · ${FrenchDate.time(message.date)}',
                      style: AppFont.sans(
                          size: 11.5, color: AppColors.faint, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Text(
          detail.body,
          style: AppFont.sans(size: 13.5, color: AppColors.text, height: 1.7),
        ),
        for (final attachment in detail.attachments) ...[
          const SizedBox(height: 13),
          _AttachmentCard(attachment: attachment),
        ],
      ],
    );
  }

  Widget _actionBar(SchoolMailDetail detail) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openCompose(detail, forward: false),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: AppFont.sans(size: 13.5, weight: FontWeight.w600),
              ),
              icon: const AppIcon(AppIcons.reply,
                  size: 15, color: Colors.white, strokeWidth: 2.2),
              label: const Text('Répondre'),
            ),
          ),
          const SizedBox(width: 9),
          OutlinedButton(
            onPressed: () => _openCompose(detail, forward: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandStrong,
              side: const BorderSide(color: AppColors.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Transférer',
                style: AppFont.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCompose(SchoolMailDetail detail,
      {required bool forward}) async {
    final message = detail.message;
    final subject = message.subject ?? '';

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SchoolMailComposeScreen(
        // A reply goes back to the sender and stays threaded onto the mail it answers; a forward
        // starts from the same text with the recipient still to be named.
        replyToId: forward ? null : message.id,
        recipient: forward ? null : message.address,
        subject: forward
            ? (subject.startsWith('Tr : ') ? subject : 'Tr : $subject')
            : (subject.startsWith('Re : ') ? subject : 'Re : $subject'),
        quotedBody: forward ? detail.body : null,
        application: message.application,
      ),
    ));
  }
}

class _AttachmentCard extends StatefulWidget {
  const _AttachmentCard({required this.attachment});

  final MailAttachment attachment;

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  bool _busy = false;

  Future<void> _open() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);

    try {
      final file =
          await SchoolMailService().downloadAttachment(token, widget.attachment);
      await OpenFilex.open(file.path);
    } on SchoolMailException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.attachment.kind == 'PDF';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPdf ? AppColors.lateBg : AppColors.blueSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.attachment.kind,
              style: AppFont.sans(
                size: 9.5,
                weight: FontWeight.w700,
                color: isPdf ? AppColors.lateInk : AppColors.brandStrong,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.sans(
                      size: 13, weight: FontWeight.w600, color: AppColors.ink),
                ),
                Text(widget.attachment.sizeLabel,
                    style:
                        AppFont.sans(size: 11.5, color: AppColors.faint)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          GestureDetector(
            onTap: _busy ? null : _open,
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Ouvrir',
                    style: AppFont.sans(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.brandStrong)),
          ),
        ],
      ),
    );
  }
}
