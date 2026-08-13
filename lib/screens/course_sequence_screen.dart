import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/course_space.dart';
import '../services/auth_service.dart';
import '../services/course_space_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// One séquence: its séances, and under each the resources this student may open.
///
/// Mirrors course_space/sequence.html.twig. A resource is opened in two steps on purpose - the app
/// asks the server for its address, which is also the moment the opening is recorded. There is no
/// address in the listing to launch directly, and that is deliberate: « listée » and « ouverte » are
/// two different facts, and an access condition downstream reads the second.
class CourseSequenceScreen extends StatefulWidget {
  const CourseSequenceScreen({
    super.key,
    required this.programId,
    required this.sequenceId,
    required this.title,
  });

  final int programId;
  final int sequenceId;
  final String title;

  @override
  State<CourseSequenceScreen> createState() => _CourseSequenceScreenState();
}

class _CourseSequenceScreenState extends State<CourseSequenceScreen> {
  final _service = CourseSpaceService();

  CourseSequencePage? _page;
  bool _loading = true;
  String? _error;

  /// The resource whose address is being fetched - one spinner on the row that was tapped, rather
  /// than a screen-wide one that would hide the list.
  int? _opening;

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
      final page = await _service.fetchSequence(token, widget.programId, widget.sequenceId);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(CourseResource resource) async {
    final token = context.read<AuthService>().token;
    if (token == null || resource.locked || _opening != null) return;

    setState(() => _opening = resource.id);

    try {
      final url = await _service.openResource(token, resource.id);
      if (!mounted) return;

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // The row's "déjà ouverte" mark is now stale - the server has just recorded the opening.
      if (mounted) await _load();
    } on CourseSpaceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            user: context.watch<AuthService>().currentUser,
            child: AppHeaderTitleRow(
              title: _page?.title ?? widget.title,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: AppFont.sans(size: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final page = _page;
    if (page == null || page.seances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "Aucune séance n'est encore ouverte dans cette séquence.",
            textAlign: TextAlign.center,
            style: AppFont.sans(size: 13, color: AppColors.muted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final seance in page.seances) ...[
            _SeanceCard(
              seance: seance,
              openingId: _opening,
              onOpen: _open,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SeanceCard extends StatelessWidget {
  const _SeanceCard({required this.seance, required this.openingId, required this.onOpen});

  final CourseSeance seance;
  final int? openingId;
  final ValueChanged<CourseResource> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.rule)),
            ),
            child: Row(
              children: [
                Text('${seance.order}',
                    style: AppFont.sans(size: 12, weight: FontWeight.w700, color: AppColors.gold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(seance.title,
                      style: AppFont.sans(
                          size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                ),
              ],
            ),
          ),
          if (seance.resources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text('Aucun document pour cette séance.',
                  style: AppFont.sans(size: 12, color: AppColors.muted)),
            )
          else
            for (final resource in seance.resources)
              _ResourceRow(
                resource: resource,
                busy: openingId == resource.id,
                onOpen: () => onOpen(resource),
              ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.resource, required this.busy, required this.onOpen});

  final CourseResource resource;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: resource.locked ? null : onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                resource.locked
                    ? Icons.lock_outline
                    : (resource.isUpload ? Icons.description_outlined : Icons.link),
                size: 16,
                color: resource.locked ? AppColors.muted : AppColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.label,
                    style: AppFont.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: resource.locked ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  if (resource.locked)
                    for (final reason in resource.lockedReasons) ...[
                      const SizedBox(height: 4),
                      Text(reason, style: AppFont.sans(size: 11.5, color: AppColors.muted)),
                    ]
                  else if (resource.opened) ...[
                    const SizedBox(height: 3),
                    Text('Déjà consulté', style: AppFont.sans(size: 11, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
