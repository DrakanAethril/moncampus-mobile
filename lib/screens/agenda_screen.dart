import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agenda_event.dart';
import '../services/agenda_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Agenda tab (design 3d) - events grouped by day, upcoming/past toggle. Now backed by the real
/// AgendaEvent/SignupList backend features (App\Controller\Api\AgendaController) - see
/// [[project_mobile_app_ldap_jwt_progress]] for why this used to be a placeholder.
///
/// The design's "+" FAB (create event) is deliberately left out: creating an event is a
/// staff/teacher-only action with its own audience picker, attachment, etc. - a whole screen this
/// pass doesn't build, same "don't ship a button with nothing to open" reasoning as the Messages
/// tab's compose FAB.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _agendaService = AgendaService();

  bool _showPast = false;
  List<AgendaEvent>? _events;
  bool _loading = true;
  String? _error;

  static const _weekdayAbbrev = [
    'lun',
    'mar',
    'mer',
    'jeu',
    'ven',
    'sam',
    'dim'
  ];
  static const _monthNames = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

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
      final events = await _agendaService.fetchEvents(token, past: _showPast);
      if (mounted) {
        setState(() {
          _events = events;
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

  void _selectTab(bool showPast) {
    if (showPast == _showPast) return;
    setState(() => _showPast = showPast);
    _load();
  }

  Future<void> _openEvent(AgendaEvent event) async {
    // A callback rather than threading the update through the sheet's pop-return value: the
    // register/unregister button never closes the sheet (the user keeps seeing the updated count
    // in place), so the only way the sheet closes is a manual swipe/tap-outside, which always pops
    // with a null result regardless of what happened inside.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgendaEventSheet(
        event: event,
        agendaService: _agendaService,
        onSignupListChanged: (updated) {
          if (!mounted) return;
          setState(() {
            _events = _events
                ?.map((e) => e.id == event.id ? _withSignupList(e, updated) : e)
                .toList();
          });
        },
      ),
    );
  }

  AgendaEvent _withSignupList(
          AgendaEvent event, SignupListSummary signupList) =>
      AgendaEvent(
        id: event.id,
        title: event.title,
        description: event.description,
        startAt: event.startAt,
        endAt: event.endAt,
        location: event.location,
        audienceLabel: event.audienceLabel,
        signupList: signupList,
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    // top: false - AppHeader applies the status bar inset itself (see its docblock).
    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppHeader(user: user, child: _buildToggleRow()),
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

  Widget _buildToggleRow() {
    return Row(
      children: [
        const Text('Agenda',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabChip('À venir', !_showPast),
              _buildTabChip('Passés', _showPast),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => _selectTab(label == 'Passés'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: selected ? AppColors.gold : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.navy : const Color(0xFFBCD4E6),
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
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.redTx)),
          ),
        ],
      );
    }

    final events = _events ?? [];

    if (events.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                _showPast
                    ? 'Aucun événement passé.'
                    : 'Aucun événement à venir.',
                style: const TextStyle(color: AppColors.faint),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isFirstOfDay =
            index == 0 || !_isSameDay(events[index - 1].startAt, event.startAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfDay) _buildDateHeader(event.startAt, index > 0),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildEventCard(event),
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateHeader(DateTime date, bool addTopSpacing) {
    return Padding(
      padding: EdgeInsets.only(top: addTopSpacing ? 10 : 0, bottom: 8),
      child: Text(
        '${_weekdayAbbrev[date.weekday - 1][0].toUpperCase()}${_weekdayAbbrev[date.weekday - 1].substring(1)} '
        '${date.day} ${_monthNames[date.month - 1]}',
        style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.faint,
            letterSpacing: .5),
      ),
    );
  }

  Widget _buildEventCard(AgendaEvent event) {
    return InkWell(
      onTap: () => _openEvent(event),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateChip(event.startAt),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(_timeAndLocation(event),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildBadge(event.audienceLabel, AppColors.blueBg,
                          AppColors.blueTx),
                      if (event.signupList != null)
                        _buildBadge(
                          '${event.signupList!.registrationCount} inscrit${event.signupList!.registrationCount > 1 ? 's' : ''}',
                          AppColors.goldBg,
                          AppColors.goldTx,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        border: Border.all(color: AppColors.goldBg),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_weekdayAbbrev[date.weekday - 1],
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldTx)),
          Text('${date.day}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldTx)),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: foreground)),
    );
  }

  String _timeAndLocation(AgendaEvent event) {
    final start = _formatTime(event.startAt);
    final end = event.endAt != null ? _formatTime(event.endAt!) : null;
    final time = end != null ? '$start – $end' : start;

    return [time, event.location].whereType<String>().join(' · ');
  }

  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}h${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Bottom sheet shown when an event is tapped - full description plus the sign-up list block
/// (register/unregister) when one is attached. Calls [onSignupListChanged] on every successful
/// register/unregister so the list screen can patch its in-memory copy live, without waiting for
/// the sheet to close (see AgendaScreen._openEvent's docblock for why this isn't a pop-return
/// value instead).
class _AgendaEventSheet extends StatefulWidget {
  const _AgendaEventSheet(
      {required this.event,
      required this.agendaService,
      required this.onSignupListChanged});

  final AgendaEvent event;
  final AgendaService agendaService;
  final ValueChanged<SignupListSummary> onSignupListChanged;

  @override
  State<_AgendaEventSheet> createState() => _AgendaEventSheetState();
}

class _AgendaEventSheetState extends State<_AgendaEventSheet> {
  late SignupListSummary? _signupList = widget.event.signupList;
  bool _submitting = false;
  String? _error;

  Future<void> _toggleRegistration() async {
    final token = context.read<AuthService>().token;
    final signupList = _signupList;
    if (token == null || signupList == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final updated = signupList.canRegister
          ? await widget.agendaService.register(token, signupList.id)
          : await widget.agendaService.unregister(token, signupList.id);
      if (mounted) setState(() => _signupList = updated);
      widget.onSignupListChanged(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(event.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(_fullDateTime(event),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            if (event.location != null) ...[
              const SizedBox(height: 2),
              Text(event.location!,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(event.description!,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.text, height: 1.4)),
            ],
            if (_signupList != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _buildSignupListBlock(_signupList!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignupListBlock(SignupListSummary signupList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.how_to_reg_outlined,
                size: 18, color: AppColors.brand),
            const SizedBox(width: 8),
            Text(
              '${signupList.registrationCount} inscrit${signupList.registrationCount > 1 ? 's' : ''}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.ink),
            ),
            if (!signupList.registrationOpen) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Inscriptions closes',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.redTx)),
        ],
        if (signupList.canRegister || signupList.canUnregister) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: signupList.canRegister
                ? ElevatedButton(
                    onPressed: _submitting ? null : _toggleRegistration,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text("S'inscrire"),
                  )
                : OutlinedButton(
                    onPressed: _submitting ? null : _toggleRegistration,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.redTx,
                        side: const BorderSide(color: AppColors.border)),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Se désinscrire'),
                  ),
          ),
        ],
      ],
    );
  }

  String _fullDateTime(AgendaEvent event) {
    final date =
        '${event.startAt.day.toString().padLeft(2, '0')}/${event.startAt.month.toString().padLeft(2, '0')}/${event.startAt.year}';
    final start =
        '${event.startAt.hour.toString().padLeft(2, '0')}h${event.startAt.minute.toString().padLeft(2, '0')}';
    final end = event.endAt != null
        ? ' – ${event.endAt!.hour.toString().padLeft(2, '0')}h${event.endAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return '$date · $start$end';
  }
}
