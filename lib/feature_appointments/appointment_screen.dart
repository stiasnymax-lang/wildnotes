import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_animals/animal_screen.dart';
import '../org/org_session.dart';
import '../org/org_widgets.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import 'appointment.dart';
import 'appointment_form_screen.dart';
import '../utils/responsive.dart';

/// Detailansicht eines Termins: abhaken, bearbeiten, löschen.
class AppointmentScreen extends StatelessWidget {
  const AppointmentScreen({super.key, required this.appointmentId});

  final String appointmentId;

  Future<void> _setDone(BuildContext context, bool done) async {
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.appointments.doc(appointmentId).update({
        'done': done,
        'doneAt': done ? FieldValue.serverTimestamp() : null,
        'doneByEmail': done ? session.member.email : null,
      });
      messenger.showMessage(done ? 'Als erledigt markiert' : 'Wieder geöffnet');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Termin löschen?',
      message: 'Der Termin wird endgültig gelöscht.',
    );
    if (!ok || !context.mounted) return;
    final doc = OrgScope.of(context).appointments.doc(appointmentId);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await doc.delete();
      messenger.showMessage('Termin gelöscht');
      navigator.pop();
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    final canEdit = session.can(OrgPermission.appointmentsEdit);
    final canComplete = session.can(OrgPermission.appointmentsComplete);
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder(
      stream: session.appointments.doc(appointmentId).snapshots(),
      builder: (context, snapshot) {
        final doc = snapshot.data;
        final appointment = doc != null && doc.exists
            ? Appointment.fromDoc(doc)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Termin'),
            actions: [
              if (canEdit && appointment != null) ...[
                IconButton(
                  tooltip: 'Bearbeiten',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AppointmentFormScreen(existing: appointment),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context),
                ),
              ],
            ],
          ),
          body: ContentWidth(
            child: () {
              if (snapshot.hasError) {
                return Center(child: Text(errorText(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (appointment == null) {
                return const Center(child: Text('Termin nicht gefunden'));
              }

              final status = appointment.statusAt(DateTime.now());
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.subject,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          avatar: Icon(status.icon, color: status.color),
                          label: Text(
                            appointment.done && appointment.doneByEmail != null
                                ? 'Erledigt von ${appointment.doneByEmail}'
                                : status.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(appointment.dateTimeLabel),
                  ),
                  if (appointment.description.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.notes),
                      title: Text(appointment.description),
                    ),
                  const SectionHeader('Personen'),
                  if (appointment.participantEmails.isEmpty)
                    const ListTile(title: Text('Keine Personen eingetragen.'))
                  else
                    for (final email in appointment.participantEmails.values)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(email),
                      ),
                  const SectionHeader('Tiere'),
                  if (appointment.animalNames.isEmpty)
                    const ListTile(title: Text('Keine Tiere eingetragen.'))
                  else
                    for (final entry in appointment.animalNames.entries)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.pets),
                        title: Text(entry.value),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AnimalScreen(animalId: entry.key),
                          ),
                        ),
                      ),
                  if (canComplete)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: appointment.done
                          ? OutlinedButton.icon(
                              onPressed: () => _setDone(context, false),
                              icon: const Icon(Icons.undo),
                              label: const Text('Wieder öffnen'),
                            )
                          : FilledButton.icon(
                              onPressed: () => _setDone(context, true),
                              icon: const Icon(Icons.check),
                              label: const Text('Als erledigt markieren'),
                            ),
                    ),
                ],
              );
            }(),
          ),
        );
      },
    );
  }
}
