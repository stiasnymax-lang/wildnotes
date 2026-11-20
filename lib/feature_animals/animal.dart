import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein Tier (organizations/{orgId}/animals/{id}).
class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.info,
    this.enclosureNr,
  });

  /// Firestore Document-ID
  final String id;
  final String name;
  final String info;
  final int? enclosureNr;

  factory Animal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Animal(
      id: doc.id,
      name: data['name'] as String? ?? '',
      info: data['info'] as String? ?? '',
      enclosureNr: parseEnclosureNr(data['enclosureNr']),
    );
  }

  /// Daten für Firestore (ohne ID, die steckt im Dokumentpfad).
  static Map<String, Object> toMap({
    required String name,
    required String info,
    required int enclosureNr,
  }) => {'name': name, 'info': info, 'enclosureNr': enclosureNr};

  /// Einfache Suche über Name, Info und Gehege-Nr. (wie AnimalAdapter.filter).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        info.toLowerCase().contains(q) ||
        (enclosureNr?.toString() ?? '').contains(q);
  }
}

/// enclosureNr ist in Firestore meist als Number gespeichert,
/// zur Sicherheit wird auch ein String akzeptiert.
int? parseEnclosureNr(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
