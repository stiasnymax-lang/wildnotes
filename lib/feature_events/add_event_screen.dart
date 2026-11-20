import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../utils/messages.dart';
import 'event.dart';
import 'event_form.dart';
import '../utils/responsive.dart';

/// Neues Event für ein Tier anlegen (früher AddEventActivity).
/// Gespeichert wird unter organizations/{orgId}/animals/{animalId}/events.
class AddEventScreen extends StatelessWidget {
  const AddEventScreen({super.key, required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Event')),
      body: ContentWidth(
        child: EventForm(
          submitLabel: 'Add Event',
          onSubmit: (name, info, date) async {
            final events = OrgScope.of(context).eventsOf(animalId);
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            try {
              await events.add(Event.toMap(name: name, info: info, date: date));
              messenger.showMessage('Event gespeichert!');
              navigator.pop();
              return true;
            } catch (e) {
              messenger.showMessage(
                'Fehler beim Speichern: ${errorText(e)}',
                long: true,
              );
              return false;
            }
          },
        ),
      ),
    );
  }
}
