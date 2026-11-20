import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein Event (Protokolleintrag) eines Tieres,
/// gespeichert unter organizations/{orgId}/animals/{animalId}/events/{eventId}.
class Event {
  const Event({
    required this.id,
    required this.name,
    required this.info,
    required this.date,
  });

  final String id;
  final String name;
  final String info;
  final String date;

  factory Event.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Event(
      id: doc.id,
      name: data['name'] as String? ?? '',
      info: data['info'] as String? ?? '',
      date: data['date'] as String? ?? '',
    );
  }

  static Map<String, Object> toMap({
    required String name,
    required String info,
    required String date,
  }) => {'name': name, 'info': info, 'date': date};
}
