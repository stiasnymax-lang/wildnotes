import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../utils/messages.dart';
import 'event.dart';
import 'event_form.dart';
import '../utils/responsive.dart';

/// Bestehendes Event bearbeiten (früher EditEventActivity).
class EditEventScreen extends StatefulWidget {
  const EditEventScreen({
    super.key,
    required this.animalId,
    required this.eventId,
  });

  final String animalId;
  final String eventId;

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late final DocumentReference<Map<String, dynamic>> _doc = OrgScope.of(context)
      .eventsOf(widget.animalId)
      .doc(widget.eventId);
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _load = _doc.get();

  Future<bool> _update(String name, String info, String date) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _doc.update(Event.toMap(name: name, info: info, date: date));
      messenger.showMessage('Event aktualisiert!');
      navigator.pop();
      return true;
    } catch (e) {
      messenger.showMessage(
        'Fehler beim Speichern: ${errorText(e)}',
        long: true,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
      body: ContentWidth(
        child: FutureBuilder(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Fehler beim Laden: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Event nicht gefunden'));
            }

            final event = Event.fromDoc(snapshot.data!);
            return EventForm(
              submitLabel: 'Speichern',
              initialName: event.name,
              initialInfo: event.info,
              initialDate: event.date,
              onSubmit: _update,
            );
          },
        ),
      ),
    );
  }
}
