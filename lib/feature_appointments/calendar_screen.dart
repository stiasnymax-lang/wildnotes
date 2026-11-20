import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';
import 'appointment.dart';
import 'appointment_form_screen.dart';
import 'appointment_tile.dart';
import 'month_calendar.dart';

/// Terminkalender: Monatsansicht und die Termine des gewählten Tages.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime.now();
  DateTime _selected = dateOnly(DateTime.now());

  String? _streamOrgId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _appointments(
    OrgSession session,
  ) {
    if (_streamOrgId != session.orgId) {
      _streamOrgId = session.orgId;
      _stream = session.appointments.snapshots();
    }
    return _stream;
  }

  void _goToToday() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _month = today;
      _selected = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          TextButton(onPressed: _goToToday, child: const Text('Heute')),
        ],
      ),
      floatingActionButton: session.can(OrgPermission.appointmentsEdit)
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppointmentFormScreen(initialDate: _selected),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Termin'),
            )
          : null,
      body: StreamBuilder(
        stream: _appointments(session),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }
          final all =
              snapshot.data?.docs.map(Appointment.fromDoc).toList() ?? [];
          final ofDay = all.where((a) => isSameDay(a.start, _selected)).toList()
            ..sort((a, b) => a.start.compareTo(b.start));

          final calendar = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MonthCalendar(
              month: _month,
              selectedDay: _selected,
              appointments: all,
              onDaySelected: (day) => setState(() => _selected = day),
              onMonthChanged: (month) => setState(() => _month = month),
            ),
          );
          final dayList = [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                DateFormat('EEEE, d. MMMM y', 'de').format(_selected),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ofDay.isEmpty)
              const ListTile(title: Text('Keine Termine an diesem Tag.'))
            else
              for (final a in ofDay) AppointmentTile(appointment: a),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              // Breiter Bildschirm: Kalender links, Tagesliste rechts
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 420,
                      child: ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: [calendar],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: dayList,
                      ),
                    ),
                  ],
                );
              }
              // Handy: alles untereinander
              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  ContentWidth(child: calendar),
                  const Divider(),
                  ...dayList,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
