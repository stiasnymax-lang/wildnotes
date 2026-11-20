import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import 'edit_event_screen.dart';
import 'event.dart';
import '../utils/responsive.dart';

/// Detailansicht eines Events (früher EventActivity).
/// Von hier aus kann das Event bearbeitet oder gelöscht werden.
class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.animalId, required this.eventId});

  final String animalId;
  final String eventId;

  Future<void> _deleteEvent(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Event löschen?',
      message: 'Das Event wird endgültig gelöscht.',
    );
    if (!ok || !context.mounted) return;

    final doc = OrgScope.of(context).eventsOf(animalId).doc(eventId);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await doc.delete();
      messenger.showMessage('Event gelöscht');
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
    final canEdit = session.can(OrgPermission.eventsEdit);

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: ContentWidth(
        child: StreamBuilder(
          stream: session.eventsOf(animalId).doc(eventId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Fehler beim Laden: ${errorText(snapshot.error!)}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Event nicht gefunden'));
            }

            final event = Event.fromDoc(snapshot.data!);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  event.name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(event.date, style: textTheme.titleSmall),
                const SizedBox(height: 16),
                Text(event.info),
                if (canEdit) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditEventScreen(
                                animalId: animalId,
                                eventId: eventId,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Event'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteEvent(context),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Event'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
