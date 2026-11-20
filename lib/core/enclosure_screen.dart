import 'package:material_ui/material_ui.dart';

import '../feature_animals/add_animal_screen.dart';
import '../feature_animals/animal.dart';
import '../feature_animals/animal_list_tile.dart';
import '../org/org_session.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';

/// Alle Tiere eines Geheges (früher EnclosureActivity).
/// Der Gehege-Name wird aus der Collection "enclosures" geladen, damit das
/// Gehege auch angezeigt wird, wenn noch keine Tiere vorhanden sind.
class EnclosureScreen extends StatelessWidget {
  const EnclosureScreen({super.key, required this.enclosureNr});

  final int enclosureNr;

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    final fallbackTitle = 'Gehege $enclosureNr';

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder(
          stream: session.enclosures
              .where('enclosureNr', isEqualTo: enclosureNr)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            final name = docs.isEmpty
                ? null
                : docs.first.data()['name'] as String?;
            return Text(name ?? fallbackTitle);
          },
        ),
      ),
      floatingActionButton: session.can(OrgPermission.animalsEdit)
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddAnimalScreen(initialEnclosureNr: enclosureNr),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tier'),
            )
          : null,
      body: ContentWidth(
        child: StreamBuilder(
          stream: session.animals
              .where('enclosureNr', isEqualTo: enclosureNr)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EmptyView(
                'Fehler beim Laden: ${errorText(snapshot.error!)}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final animals = snapshot.data!.docs.map(Animal.fromDoc).toList();
            if (animals.isEmpty) {
              return const _EmptyView('Keine Tiere in diesem Gehege.');
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: animals.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => AnimalListTile(animal: animals[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
