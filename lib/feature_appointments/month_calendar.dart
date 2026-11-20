import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'appointment.dart';

/// Einfacher Monatskalender (Montag als Wochenbeginn). Unter jedem Tag
/// werden bis zu drei farbige Punkte für die Termine des Tages gezeigt.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.appointments,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  /// Beliebiger Tag im angezeigten Monat.
  final DateTime month;
  final DateTime selectedDay;
  final List<Appointment> appointments;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Montag = 0
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;

    final byDay = <DateTime, List<Appointment>>{};
    for (final a in appointments) {
      byDay.putIfAbsent(dateOnly(a.start), () => []).add(a);
    }

    final weekdays = List.generate(
      7,
      (i) => DateFormat.E('de').format(DateTime(2024, 1, 1 + i)), // 1.1.24 = Mo
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Vorheriger Monat',
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM('de').format(first),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Nächster Monat',
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            for (var i = 0; i < cells; i++)
              if (i < leading || i >= leading + daysInMonth)
                const SizedBox.shrink()
              else
                _DayCell(
                  day: DateTime(month.year, month.month, i - leading + 1),
                  isToday: isSameDay(
                    DateTime(month.year, month.month, i - leading + 1),
                    now,
                  ),
                  isSelected: isSameDay(
                    DateTime(month.year, month.month, i - leading + 1),
                    selectedDay,
                  ),
                  appointments:
                      byDay[DateTime(
                        month.year,
                        month.month,
                        i - leading + 1,
                      )] ??
                      const [],
                  now: now,
                  onTap: onDaySelected,
                ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.appointments,
    required this.now,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<Appointment> appointments;
  final DateTime now;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dots = appointments.take(3).map((a) => a.statusAt(now).color);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onTap(day),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? scheme.primary : null,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected ? scheme.onPrimary : null,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in dots)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
