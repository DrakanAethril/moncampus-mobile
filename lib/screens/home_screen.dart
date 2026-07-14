import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/lesson_session.dart';
import '../services/auth_service.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';

/// Home tab (design 3a) - brand header, greeting, next-class card, and today's mini schedule
/// ("Ma journée"). The design's gold "Annonces" banner and separate "Agenda" preview card are
/// left out: there's no Announcement/Event entity on the backend to back them with real data (see
/// [[project_mobile_app_ldap_jwt_progress]] for that gap), and this app doesn't invent fake data.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onViewTimetable});

  final VoidCallback? onViewTimetable;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _timetableService = TimetableService();

  List<LessonSession>? _todaySessions;
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

    try {
      final sessions = await _timetableService.fetchWeek(token, from: monday, to: sunday);
      final today = DateTime(now.year, now.month, now.day);
      final todaySessions = sessions.where((session) => _isSameDay(session.day, today)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (mounted) {
        setState(() {
          _todaySessions = todaySessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
                  if (_nextSession != null) ...[
                    _buildNextSessionCard(_nextSession!),
                    const SizedBox(height: 14),
                  ],
                  _buildTodayCard(),
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
}

/// Shared by HomeScreen and TimetableScreen - both color-code session cards from the API's hex
/// string (App\Controller\Api\TimetableController::color()).
Color parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '');

  return Color(int.parse('FF$cleaned', radix: 16));
}
