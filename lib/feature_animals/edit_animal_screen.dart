import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../org/org_session.dart';
import '../utils/messages.dart';
import 'animal.dart';
import 'animal_form.dart';
import '../utils/responsive.dart';

/// Bestehendes Tier bearbeiten (früher EditAnimalActivity).
class EditAnimalScreen extends StatefulWidget {
  const EditAnimalScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<EditAnimalScreen> createState() => _EditAnimalScreenState();
}

class _EditAnimalScreenState extends State<EditAnimalScreen> {
  late final DocumentReference<Map<String, dynamic>> _doc = OrgScope.of(context)
      .animals
      .doc(widget.animalId);
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _load = _doc.get();

  Future<bool> _update(String name, String info, int enclosureNr) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _doc.update(
        Animal.toMap(name: name, info: info, enclosureNr: enclosureNr),
      );
      messenger.showMessage('Tier aktualisiert!');
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
      appBar: AppBar(title: const Text('Edit Animal')),
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
            final doc = snapshot.data!;
            if (!doc.exists) {
              return const Center(child: Text('Tier nicht gefunden'));
            }

            final animal = Animal.fromDoc(doc);
            return AnimalForm(
              submitLabel: 'Speichern',
              initialName: animal.name,
              initialInfo: animal.info,
              initialEnclosureNr: animal.enclosureNr,
              onSubmit: _update,
            );
          },
        ),
      ),
    );
  }
}
