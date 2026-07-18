import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_session.dart';
import '../services/auth_service.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'home_screen.dart' show parseHexColor;

/// Timetable tab (design 3c) - week day selector + the selected day's sessions. Fetches the whole
/// week once (TimetableController already returns a date range) and filters client-side per tap,
/// rather than re-fetching per day.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _timetableService = TimetableService();

  static const _weekdayShort = [
    'lun',
    'mar',
    'mer',
    'jeu',
    'ven',
    'sam',
    'dim'
  ];
  static const _weekdayFull = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche'
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

  late DateTime _weekStart;
  late DateTime _selectedDay;
  List<LessonSession>? _weekSessions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    _selectedDay = today;
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions = await _timetableService.fetchWeek(token,
          from: _weekStart, to: _weekStart.add(const Duration(days: 6)));
      if (mounted) {
        setState(() {
          _weekSessions = sessions;
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

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _selectedDay = _weekStart;
    });
    _loadWeek();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<LessonSession> get _daySessions {
    final sessions = _weekSessions;
    if (sessions == null) return [];

    final filtered = sessions
        .where((session) => _isSameDay(session.day, _selectedDay))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return SafeArea(
      child: Column(
        children: [
          AppHeader(user: user, child: _buildWeekSelector()),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadWeek,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Emploi du temps',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => _changeWeek(-1),
              icon: const Icon(Icons.chevron_left, color: Color(0xFF7D99B0)),
            ),
            Expanded(
              child: Row(
                children: List.generate(5, (index) {
                  final day = _weekStart.add(Duration(days: index));
                  final isSelected = _isSameDay(day, _selectedDay);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _weekdayShort[index],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.navy
                                    : const Color(0xFF7D99B0),
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected ? AppColors.navy : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            IconButton(
              onPressed: () => _changeWeek(1),
              icon: const Icon(Icons.chevron_right, color: Color(0xFF7D99B0)),
            ),
          ],
        ),
      ],
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

    final sessions = _daySessions;
    final summary =
        '${_weekdayFull[_selectedDay.weekday - 1]} ${_selectedDay.day} ${_monthNames[_selectedDay.month - 1]}'
        ' · ${sessions.length} cours';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(summary.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.faint,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: Text('Aucun cours ce jour-là.',
                    style: TextStyle(color: AppColors.faint))),
          )
        else
          ..._buildSessionCards(sessions),
      ],
    );
  }

  List<Widget> _buildSessionCards(List<LessonSession> sessions) {
    final widgets = <Widget>[];

    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];

      if (i > 0) {
        final previousEnd = _minutesOf(sessions[i - 1].endTime);
        final currentStart = _minutesOf(session.startTime);
        if (currentStart - previousEnd >= 60) {
          widgets.add(_buildBreakDivider());
        }
      }

      widgets.add(_buildSessionCard(session));
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  int _minutesOf(String time) {
    final parts = time.split(':');

    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Widget _buildBreakDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Pause déjeuner',
                style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(LessonSession session) {
    final color = parseHexColor(session.color);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
            margin: const EdgeInsets.only(right: 12),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${session.startTime}\n${session.endTime}',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                  height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppColors.ink)),
                if (session.room != null || session.teacher != null)
                  Text(
                    [session.room, session.teacher]
                        .whereType<String>()
                        .join(' · '),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
