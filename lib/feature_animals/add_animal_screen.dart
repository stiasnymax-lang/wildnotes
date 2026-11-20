import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../utils/messages.dart';
import 'animal.dart';
import 'animal_form.dart';
import '../utils/responsive.dart';

/// Neues Tier anlegen (früher AddAnimalActivity).
/// Optional mit vorausgefüllter Gehege-Nummer (aus der Gehegeansicht).
class AddAnimalScreen extends StatelessWidget {
  const AddAnimalScreen({super.key, this.initialEnclosureNr});

  final int? initialEnclosureNr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Animal')),
      body: ContentWidth(
        child: AnimalForm(
          submitLabel: 'Create Animal',
          initialEnclosureNr: initialEnclosureNr,
          onSubmit: (name, info, enclosureNr) async {
            final animals = OrgScope.of(context).animals;
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            try {
              await animals.add(
                Animal.toMap(name: name, info: info, enclosureNr: enclosureNr),
              );
              messenger.showMessage('Tier gespeichert!');
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
