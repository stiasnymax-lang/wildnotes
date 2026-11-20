import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_animals/add_animal_screen.dart';
import '../feature_animals/animal.dart';
import '../feature_animals/animal_list_tile.dart';
import '../org/org_session.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';

/// Bibliothek/Übersicht aller Tiere mit Suchleiste (früher LibraryActivity).
/// Gefiltert wird nach Name, Info und Gehege-Nr.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  // Stream nur bei Organisationswechsel neu erzeugen, nicht bei jeder Suche.
  String? _streamOrgId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _animals(OrgSession session) {
    if (_streamOrgId != session.orgId) {
      _streamOrgId = session.orgId;
      _stream = session.animals.snapshots();
    }
    return _stream;
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Tiere')),
      floatingActionButton: session.can(OrgPermission.animalsEdit)
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddAnimalScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tier'),
            )
          : null,
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                hintText: 'Suchen (Name, Info, Gehege)',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: _animals(session),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Fehler beim Laden: ${errorText(snapshot.error!)}',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final animals =
                      snapshot.data!.docs
                          .map(Animal.fromDoc)
                          .where((a) => a.matches(_query))
                          .toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                  if (animals.isEmpty) {
                    return const Center(child: Text('Keine Tiere gefunden.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: animals.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        AnimalListTile(animal: animals[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
