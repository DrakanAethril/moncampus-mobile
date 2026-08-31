import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/school_mail.dart';
import '../services/auth_service.dart';
import '../services/school_mail_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';
import '../widgets/app_header.dart';
import 'school_mail_compose_screen.dart';
import 'school_mail_read_screen.dart';

/// Courrier pro (design_handoff_mobile 5a/5b), opened from the app bar's envelope and never from
/// the tab bar (principe 5).
///
/// Locked box: a centred message and nothing else - no button, no retry, no explanation of what to
/// do next, because there is nothing the student can do; it is a teacher's validation that opens
/// it.
class SchoolMailScreen extends StatefulWidget {
  const SchoolMailScreen({super.key});

  @override
  State<SchoolMailScreen> createState() => _SchoolMailScreenState();
}

class _SchoolMailScreenState extends State<SchoolMailScreen> {
  final _service = SchoolMailService();

  SchoolMailbox? _mailbox;
  bool _loading = true;
  String? _error;
  int _tab = 0;

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
      final mailbox = await _service.fetchFolder(token, sent: _tab == 1);
      if (mounted) setState(() => _mailbox = mailbox);
    } on SchoolMailException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de contacter le serveur.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final mailbox = _mailbox;
    final locked = mailbox?.locked ?? false;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            user: user,
            title: 'Courrier pro',
            mail: MailButtonState.active,
            onMailTap: () => Navigator.of(context).pop(),
            onAvatarTap: () => Navigator.of(context).pop(),
            titleTrailing: locked || mailbox?.address == null
                ? null
                : Text(
                    mailbox!.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AppFont.sans(
                        size: 11.5, color: AppColors.headerLight),
                  ),
            filters: locked || mailbox == null
                ? null
                : HeaderFilters(
                    labels: [
                      mailbox.unread > 0
                          ? 'Reçus · ${mailbox.unread}'
                          : 'Reçus',
                      'Envoyés',
                    ],
                    selectedIndex: _tab,
                    onSelected: (index) {
                      setState(() => _tab = index);
                      _load();
                    },
                  ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: locked || !(mailbox?.canSend ?? false)
          ? null
          : FloatingActionButton(
              onPressed: _compose,
              backgroundColor: AppColors.brand,
              shape: const CircleBorder(),
              child: const AppIcon(AppIcons.pencil,
                  size: 21, color: Colors.white),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading && _mailbox == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _CenteredMessage(title: 'Courrier indisponible', text: _error!);
    }

    final mailbox = _mailbox;
    if (mailbox == null || mailbox.locked) return const _LockedBox();

    if (mailbox.messages.isEmpty) {
      return _CenteredMessage(
        title: _tab == 0 ? 'Aucun mail reçu' : 'Aucun mail envoyé',
        text: '',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: mailbox.messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (_, index) => _MailRow(
          message: mailbox.messages[index],
          onTap: () => _open(mailbox.messages[index]),
        ),
      ),
    );
  }

  Future<void> _open(SchoolMailMessage message) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SchoolMailReadScreen(messageId: message.id),
    ));
    if (mounted) await _load();
  }

  Future<void> _compose() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const SchoolMailComposeScreen(),
    ));
    if ((sent ?? false) && mounted) await _load();
  }
}

/// 5a - the box is not open yet.
class _LockedBox extends StatelessWidget {
  const _LockedBox();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: AppIcons.lock,
      title: "Votre boîte n'est pas encore activée",
      text:
          "Elle sera débloquée après validation de votre postulation d'entraînement par un enseignant.",
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.text, this.icon});

  final String title;
  final String text;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: AppColors.neutralBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: AppIcon(icon!,
                      size: 26, color: AppColors.faint, strokeWidth: 1.8),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFont.spectral(size: 17, color: AppColors.navy),
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppFont.sans(
                      size: 13, color: AppColors.muted, height: 1.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One mail in the list (5b): coloured initials, who wrote and when, the subject, one line of the
/// body, a paperclip when it carries files, the démarche chip, and the blue dot while unread.
class _MailRow extends StatelessWidget {
  const _MailRow({required this.message, required this.onTap});

  final SchoolMailMessage message;
  final VoidCallback onTap;

  /// Unread mails get a coloured avatar, read ones the neutral tint - the same reading order as
  /// the row's own background.
  static const _avatarColors = <(Color, Color)>[
    (AppColors.blueSoft, AppColors.brandStrong),
    (AppColors.chipPurpleBg, AppColors.chipPurpleInk),
    (AppColors.chipTealBg, AppColors.chipTealInk),
    (AppColors.chipGoldBg, AppColors.chipGoldInk),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = message.unread;
    final (avatarBg, avatarInk) = unread
        ? _avatarColors[message.name.hashCode.abs() % _avatarColors.length]
        : (AppColors.neutralBg, AppColors.muted);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unread ? AppColors.surface : AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: avatarBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                message.initials,
                style: AppFont.sans(
                    size: 12, weight: FontWeight.w700, color: avatarInk),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          message.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFont.sans(
                            size: 13.5,
                            weight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                            color: unread ? AppColors.ink : AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dateLabel(message.date),
                        style: AppFont.sans(
                          size: 11,
                          weight: FontWeight.w600,
                          color:
                              unread ? AppColors.brandStrong : AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                  if (message.subject != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      message.subject!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFont.sans(
                        size: 12.5,
                        weight: unread ? FontWeight.w600 : FontWeight.w400,
                        color: unread ? AppColors.ink : AppColors.text,
                      ),
                    ),
                  ],
                  if (message.preview != null &&
                      message.preview!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.preview!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFont.sans(
                                size: 12, color: AppColors.faint),
                          ),
                        ),
                        if (message.hasAttachments) ...[
                          const SizedBox(width: 8),
                          const AppIcon(AppIcons.paperclip,
                              size: 12, color: AppColors.faint),
                        ],
                      ],
                    ),
                  ],
                  if (message.application != null) ...[
                    const SizedBox(height: 6),
                    ApplicationChip(name: message.application!),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                    color: AppColors.brand, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The hour for today's mail, the day for this month's, the full short date beyond - as in the
  /// reference list.
  static String _dateLabel(DateTime date) {
    final now = DateTime.now();

    if (FrenchDate.isSameDay(date, now)) return FrenchDate.time(date);
    if (date.year == now.year && date.month == now.month) {
      return FrenchDate.dayAndNumber(date);
    }

    return FrenchDate.short(date);
  }
}

/// The gold "Candidature · Entreprise" chip (5b/5c).
class ApplicationChip extends StatelessWidget {
  const ApplicationChip({super.key, required this.name, this.large = false});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 9 : 8, vertical: large ? 3 : 2),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Candidature · $name',
        style: AppFont.sans(
            size: large ? 11 : 10.5,
            weight: FontWeight.w600,
            color: AppColors.goldInk),
      ),
    );
  }
}
