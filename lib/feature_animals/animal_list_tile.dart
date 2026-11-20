import 'package:material_ui/material_ui.dart';

import 'animal.dart';
import 'animal_screen.dart';

/// Listeneintrag für ein Tier (früher item_animal.xml / AnimalAdapter).
/// Ein Tipp öffnet die Detailansicht des Tieres.
class AnimalListTile extends StatelessWidget {
  const AnimalListTile({super.key, required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        animal.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (animal.info.isNotEmpty) Text(animal.info),
          Text(
            'Gehege: ${animal.enclosureNr ?? '-'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnimalScreen(animalId: animal.id)),
      ),
    );
  }
}
