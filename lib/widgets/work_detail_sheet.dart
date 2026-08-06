import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/work_item.dart';
import '../screens/work_screen.dart' show WorkTag;
import '../services/auth_service.dart';
import '../services/work_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/french_date.dart';

/// Opens the consultation sheet of one travail (design_handoff_mobile 4c).
Future<void> showWorkDetailSheet(BuildContext context, WorkItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (_) => WorkDetailSheet(item: item),
  );
}

/// The travail as the phone shows it: the brief, the deposits it asks for and its attachments -
/// all in consultation. Every deposit still awaited carries the "Dépôt sur le web" pill instead of
/// the web's "Déposer" button (handoff, principe 3), and nothing on this sheet writes anything.
class WorkDetailSheet extends StatefulWidget {
  const WorkDetailSheet({super.key, required this.item});

  final WorkItem item;

  @override
  State<WorkDetailSheet> createState() => _WorkDetailSheetState();
}

class _WorkDetailSheetState extends State<WorkDetailSheet> {
  final _workService = WorkService();

  WorkDetail? _detail;
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
      final detail = await _workService.fetchDetail(token, widget.item.id);
      if (mounted) setState(() => _detail = detail);
    } on WorkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de contacter le serveur.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail?.item ?? widget.item;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _header(item),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header(WorkItem item) {
    final meta = [
      if (item.subject != null && item.subject!.isNotEmpty) item.subject!,
      if (item.teacher != null && item.teacher!.isNotEmpty) item.teacher!,
    ].join(' — ');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppFont.spectral(size: 16.5, color: AppColors.ink)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      style:
                          AppFont.sans(size: 12.5, color: AppColors.faint)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: AppIcon(AppIcons.close,
                    size: 15, color: AppColors.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        child: Text(_error!,
            style: AppFont.sans(size: 13, color: AppColors.muted)),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final description = detail.description?.trim() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty)
            Text(
              description,
              style: AppFont.sans(
                  size: 13.5, color: AppColors.text, height: 1.65),
            ),
          if (detail.expectations.isNotEmpty) ...[
            if (description.isNotEmpty) const SizedBox(height: 15),
            _SectionLabel(
                label: 'Dépôts demandés · ${detail.expectations.length}'),
            for (final expectation in detail.expectations) ...[
              const SizedBox(height: 8),
              _ExpectationRow(expectation: expectation),
            ],
          ],
          if (detail.attachments.isNotEmpty) ...[
            const SizedBox(height: 15),
            _SectionLabel(
                label: 'Pièces jointes · ${detail.attachments.length}'),
            for (final attachment in detail.attachments) ...[
              const SizedBox(height: 8),
              _AttachmentRow(attachment: attachment),
            ],
          ],
          if (detail.givenAt != null) ...[
            const SizedBox(height: 15),
            Text(
              'Donné le ${FrenchDate.short(detail.givenAt!)}',
              style: AppFont.sans(size: 12, color: AppColors.faint),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppFont.sans(
        size: 11.5,
        weight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: .4,
      ),
    );
  }
}

/// One line of "Dépôts demandés": green once handed in, otherwise its constraints and the pill
/// that says where the file goes.
class _ExpectationRow extends StatelessWidget {
  const _ExpectationRow({required this.expectation});

  final WorkExpectation expectation;

  @override
  Widget build(BuildContext context) {
    final submitted = expectation.submitted;

    return Container(
      decoration: BoxDecoration(
        color: submitted ? AppColors.doneSurface : AppColors.surface,
        border: Border.all(
            color: submitted ? AppColors.doneBorder : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        expectation.name,
                        style: AppFont.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ),
                    if (submitted) ...[
                      const SizedBox(width: 8),
                      const WorkTag(label: 'Rendu'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _meta(),
                  style: AppFont.sans(size: 11.5, color: AppColors.faint),
                ),
              ],
            ),
          ),
          if (!submitted) ...[
            const SizedBox(width: 11),
            const _WebDepositPill(),
          ],
        ],
      ),
    );
  }

  String _meta() {
    if (expectation.submitted) {
      return [
        if (expectation.fileName != null) expectation.fileName!,
        if (expectation.submittedAt != null)
          'rendu le ${FrenchDate.short(expectation.submittedAt!)}',
      ].join(' · ');
    }

    return [
      if (expectation.constraints.isNotEmpty) expectation.constraints,
      if (expectation.dueDate != null) FrenchDate.short(expectation.dueDate!),
      if (expectation.dueDate != null) FrenchDate.time(expectation.dueDate!),
    ].join(' · ');
  }
}

/// "Dépôt sur le web" - where the web's "Déposer" button sits, saying why there is no button.
class _WebDepositPill extends StatelessWidget {
  const _WebDepositPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.laptop,
              size: 11, color: AppColors.brandStrong, strokeWidth: 2.4),
          const SizedBox(width: 5),
          Text(
            'Dépôt sur le web',
            style: AppFont.sans(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.brandStrong),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final WorkAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final isPdf = attachment.kind.toUpperCase() == 'PDF';

    return Container(
      decoration: BoxDecoration(
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
              attachment.kind,
              style: AppFont.sans(
                size: 9.5,
                weight: FontWeight.w700,
                color: isPdf ? AppColors.lateInk : AppColors.brandStrong,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              attachment.label,
              overflow: TextOverflow.ellipsis,
              style: AppFont.sans(
                  size: 13, weight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
          if (attachment.url != null) ...[
            const SizedBox(width: 11),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(attachment.url!),
                  mode: LaunchMode.externalApplication),
              child: Text(
                'Ouvrir',
                style: AppFont.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: AppColors.brandStrong),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
