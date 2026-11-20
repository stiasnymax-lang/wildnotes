import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_appointments/appointment.dart';
import '../feature_appointments/appointment_tile.dart';
import '../org/org_session.dart';
import '../org/org_widgets.dart';
import '../utils/messages.dart';
import 'settings_screen.dart';
import '../utils/responsive.dart';

/// Home Screen – Startpunkt nach dem Login (früher HomeActivity).
/// Zeigt überfällige, heutige und bevorstehende Termine.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _streamOrgId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    if (_streamOrgId != session.orgId) {
      _streamOrgId = session.orgId;
      _stream = session.appointments
          .where('done', isEqualTo: false)
          .snapshots();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session.organization.name),
        actions: [
          IconButton(
            tooltip: 'Konto',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ContentWidth(
        child: StreamBuilder(
          stream: _stream,
          builder: (context, snapshot) {
            final now = DateTime.now();
            final open =
                snapshot.data?.docs.map(Appointment.fromDoc).toList() ?? [];
            open.sort((a, b) => a.start.compareTo(b.start));

            List<Appointment> withStatus(AppointmentStatus s) =>
                open.where((a) => a.statusAt(now) == s).toList();
            final overdue = withStatus(AppointmentStatus.overdue);
            final today = withStatus(AppointmentStatus.today);
            final upcoming = withStatus(AppointmentStatus.upcoming)
                .where((a) => a.start.difference(now).inDays < 7)
                .toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Willkommen in Wildnotes',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (snapshot.hasError)
                  ListTile(title: Text(errorText(snapshot.error!)))
                else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (overdue.isNotEmpty) ...[
                    const SectionHeader('Überfällig'),
                    for (final a in overdue)
                      AppointmentTile(appointment: a, showDate: true),
                  ],
                  const SectionHeader('Heute'),
                  if (today.isEmpty)
                    const ListTile(
                      title: Text('Heute stehen keine Termine an.'),
                    )
                  else
                    for (final a in today) AppointmentTile(appointment: a),
                  const SectionHeader('Nächste 7 Tage'),
                  if (upcoming.isEmpty)
                    const ListTile(title: Text('Keine bevorstehenden Termine.'))
                  else
                    for (final a in upcoming)
                      AppointmentTile(appointment: a, showDate: true),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
