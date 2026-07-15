import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agenda_event.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/lesson_session.dart';
import '../services/agenda_service.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';

/// Home tab (design 3a) - brand header, greeting, announcement banner, next-class card, today's
/// mini schedule ("Ma journée"), and an upcoming-events preview ("Agenda"). The design's banner
/// and Agenda preview used to be left out for lack of a backend Announcement/Event entity - both
/// now exist (App\Controller\Api\AnnouncementController, App\Controller\Api\AgendaController), see
/// [[project_mobile_app_ldap_jwt_progress]] for that history.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onViewTimetable, this.onViewAgenda});

  final VoidCallback? onViewTimetable;
  final VoidCallback? onViewAgenda;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _timetableService = TimetableService();
  final _announcementService = AnnouncementService();
  final _agendaService = AgendaService();

  List<LessonSession>? _todaySessions;
  List<Announcement>? _announcements;
  List<AgendaEvent>? _upcomingEvents;
  bool _loading = true;

  static const _weekdayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _monthNames = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    setState(() => _loading = true);

    // Independent widgets, independent failures - one card not loading shouldn't blank the
    // others (unlike TimetableScreen's single-source dependency).
    final results = await Future.wait([
      _timetableService.fetchWeek(token, from: monday, to: sunday).catchError((_) => <LessonSession>[]),
      _announcementService.fetchAnnouncements(token).catchError((_) => <Announcement>[]),
      _agendaService.fetchEvents(token).catchError((_) => <AgendaEvent>[]),
    ]);

    if (!mounted) return;

    final today = DateTime(now.year, now.month, now.day);
    final todaySessions = (results[0] as List<LessonSession>).where((session) => _isSameDay(session.day, today)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    setState(() {
      _todaySessions = todaySessions;
      _announcements = results[1] as List<Announcement>;
      _upcomingEvents = results[2] as List<AgendaEvent>;
      _loading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  LessonSession? get _nextSession {
    final sessions = _todaySessions;
    if (sessions == null) return null;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    for (final session in sessions) {
      final parts = session.endTime.split(':');
      final endMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (endMinutes >= nowMinutes) return session;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadToday,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildGreeting(user),
                  const SizedBox(height: 16),
                  if (_announcements != null && _announcements!.isNotEmpty) ...[
                    _buildAnnouncementBanner(_announcements!.first),
                    const SizedBox(height: 14),
                  ],
                  if (_nextSession != null) ...[
                    _buildNextSessionCard(_nextSession!),
                    const SizedBox(height: 14),
                  ],
                  _buildTodayCard(),
                  if (_upcomingEvents != null && _upcomingEvents!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildAgendaCard(_upcomingEvents!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppUser? user) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Text('B', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Institution Beaupeyrat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              Text('depuis 1634', style: TextStyle(color: Color(0xFF7D99B0), fontSize: 10, letterSpacing: .5)),
            ],
          ),
          const Spacer(),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.gold,
            child: Text(
              user?.initials ?? '?',
              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(AppUser? user) {
    final now = DateTime.now();
    final formatted = '${_weekdayNames[now.weekday - 1]} ${now.day} ${_monthNames[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatted.toUpperCase(),
          style: const TextStyle(fontSize: 12, color: AppColors.faint, fontWeight: FontWeight.w600, letterSpacing: .5),
        ),
        const SizedBox(height: 2),
        Text(
          'Bonjour ${user?.firstname ?? user?.username ?? ''}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.navy),
        ),
      ],
    );
  }

  Widget _buildAnnouncementBanner(Announcement announcement) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldStrong]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('!', style: TextStyle(color: Color(0xFFE8C574), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.navy),
                children: [
                  TextSpan(text: announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '  '),
                  TextSpan(text: announcement.plainTextBody.split('\n').first),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSessionCard(LessonSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.brand]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROCHAIN COURS',
            style: TextStyle(color: Color(0xFFBCD4E6), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .5),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Text(
                [session.room, session.teacher].whereType<String>().join(' · '),
                style: const TextStyle(color: Color(0xFFBCD4E6), fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('Ma journée', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onViewTimetable,
                  child: const Text(
                    'Emploi du temps →',
                    style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (_todaySessions == null || _todaySessions!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun cours aujourd\'hui.', style: TextStyle(color: AppColors.faint)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: _todaySessions!.map(_buildSessionRow).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(LessonSession session) {
    final color = parseHexColor(session.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(
                '${session.startTime}–${session.endTime}',
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 11.5, color: color),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
                  if (session.room != null || session.teacher != null)
                    Text(
                      [session.room, session.teacher].whereType<String>().join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaCard(List<AgendaEvent> events) {
    final preview = events.take(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('Agenda', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onViewAgenda,
                  child: const Text(
                    'Tout voir →',
                    style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: preview.map(_buildAgendaPreviewRow).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaPreviewRow(AgendaEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Text(_weekdayAbbrev(event.startAt), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.goldTx)),
                Text('${event.startAt.day}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldTx)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
                Text(
                  [_formatTime(event.startAt), event.location].whereType<String>().join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayAbbrev(DateTime date) => const ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'][date.weekday - 1];

  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}h${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Shared by HomeScreen and TimetableScreen - both color-code session cards from the API's hex
/// string (App\Controller\Api\TimetableController::color()).
Color parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '');

  return Color(int.parse('FF$cleaned', radix: 16));
}
