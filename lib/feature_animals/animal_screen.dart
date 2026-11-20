import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_appointments/appointment.dart';
import '../feature_appointments/appointment_form_screen.dart';
import '../feature_appointments/appointment_tile.dart';
import '../feature_events/add_event_screen.dart';
import '../feature_events/event.dart';
import '../feature_events/event_screen.dart';
import '../org/org_session.dart';
import '../org/org_widgets.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import 'animal.dart';
import 'edit_animal_screen.dart';
import '../utils/responsive.dart';

/// Detailansicht eines Tieres mit Terminen und Protokoll-Events
/// (früher AnimalActivity). Die Daten werden live aus Firestore gelesen,
/// Änderungen erscheinen daher sofort.
class AnimalScreen extends StatelessWidget {
  const AnimalScreen({super.key, required this.animalId});

  final String animalId;

  Future<void> _deleteAnimal(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Tier löschen?',
      message:
          'Das Tier und alle zugehörigen Events werden endgültig '
          'gelöscht.',
    );
    if (!ok || !context.mounted) return;

    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // Firestore löscht Subcollections nicht automatisch mit,
      // daher werden die Events zuerst entfernt.
      final batch = FirebaseFirestore.instance.batch();
      final events = await session.eventsOf(animalId).get();
      for (final doc in events.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(session.animals.doc(animalId));
      await batch.commit();

      messenger.showMessage('Animal gelöscht');
      navigator.pop();
    } catch (e) {
      messenger.showMessage('Fehler beim Löschen: ${errorText(e)}', long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    final textTheme = Theme.of(context).textTheme;
    final canEditAnimal = session.can(OrgPermission.animalsEdit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tier'),
        actions: [
          if (canEditAnimal) ...[
            IconButton(
              tooltip: 'Edit Animal',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditAnimalScreen(animalId: animalId),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Delete Animal',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteAnimal(context),
            ),
          ],
        ],
      ),
      body: ContentWidth(
        child: StreamBuilder(
          stream: session.animals.doc(animalId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Fehler beim Laden des Tiers: ${errorText(snapshot.error!)}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Tier nicht gefunden'));
            }

            final animal = Animal.fromDoc(snapshot.data!);
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animal.name,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(animal.info),
                      const SizedBox(height: 8),
                      Text('Gehege: ${animal.enclosureNr ?? ''}'),
                    ],
                  ),
                ),
                SectionHeader(
                  'Termine',
                  trailing: session.can(OrgPermission.appointmentsEdit)
                      ? TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AppointmentFormScreen(
                                initialAnimalIds: [animalId],
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Termin'),
                        )
                      : null,
                ),
                _AppointmentList(animalId: animalId),
                SectionHeader(
                  'Events',
                  trailing: session.can(OrgPermission.eventsEdit)
                      ? TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEventScreen(animalId: animalId),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Event'),
                        )
                      : null,
                ),
                _EventList(animalId: animalId),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Termine, an denen das Tier teilnimmt: offene zuerst (nach Datum),
/// danach erledigte (neueste zuerst).
class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    return StreamBuilder(
      stream: session.appointments
          .where('animalIds', arrayContains: animalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(title: Text(errorText(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final all = snapshot.data!.docs.map(Appointment.fromDoc).toList();
        final open = all.where((a) => !a.done).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        final done = all.where((a) => a.done).toList()
          ..sort((a, b) => b.start.compareTo(a.start));

        if (all.isEmpty) {
          return const ListTile(title: Text('Keine Termine.'));
        }
        return Column(
          children: [
            for (final a in [...open, ...done])
              AppointmentTile(appointment: a, showDate: true),
          ],
        );
      },
    );
  }
}

/// Liste der Events eines Tieres (früher EventAdapter / item_event.xml).
class _EventList extends StatelessWidget {
  const _EventList({required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    return StreamBuilder(
      stream: session.eventsOf(animalId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text('Fehler beim Laden: ${errorText(snapshot.error!)}'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final events = snapshot.data!.docs.map(Event.fromDoc).toList();
        if (events.isEmpty) {
          return const ListTile(title: Text('Noch keine Events vorhanden.'));
        }

        return Column(
          children: [
            for (final event in events)
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(
                  event.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(event.date),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EventScreen(animalId: animalId, eventId: event.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
