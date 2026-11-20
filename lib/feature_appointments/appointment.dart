import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_animals/animal.dart';

/// Ein Termin (organizations/{orgId}/appointments/{id}).
///
/// Teilnehmer sind Personen (Mitglieder der Organisation) und Tiere.
/// Über das Feld `animalIds` werden Termine auch beim Tier angezeigt.
class Appointment {
  const Appointment({
    required this.id,
    required this.subject,
    required this.description,
    required this.start,
    required this.end,
    required this.animalNames,
    required this.participantEmails,
    this.done = false,
    this.doneByEmail,
  });

  final String id;
  final String subject;
  final String description;
  final DateTime start;
  final DateTime end;

  /// Beteiligte Tiere: ID → Name (Name zum Zeitpunkt des Speicherns).
  final Map<String, String> animalNames;

  /// Beteiligte Personen: UID → E-Mail.
  final Map<String, String> participantEmails;

  final bool done;
  final String? doneByEmail;

  Iterable<String> get animalIds => animalNames.keys;

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final start = (data['start'] as Timestamp?)?.toDate() ?? DateTime(2000);
    return Appointment(
      id: doc.id,
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      start: start,
      end: (data['end'] as Timestamp?)?.toDate() ?? start,
      animalNames: _stringMap(data['animalNames']),
      participantEmails: _stringMap(data['participantEmails']),
      done: data['done'] as bool? ?? false,
      doneByEmail: data['doneByEmail'] as String?,
    );
  }

  /// Felder für Anlegen/Bearbeiten (ohne Erledigt-Status).
  static Map<String, Object> toMap({
    required String subject,
    required String description,
    required DateTime start,
    required DateTime end,
    required Map<String, String> animalNames,
    required Map<String, String> participantEmails,
  }) => {
    'subject': subject,
    'description': description,
    'start': Timestamp.fromDate(start),
    'end': Timestamp.fromDate(end),
    'animalIds': animalNames.keys.toList(),
    'animalNames': animalNames,
    'participantIds': participantEmails.keys.toList(),
    'participantEmails': participantEmails,
  };

  AppointmentStatus statusAt(DateTime now) {
    if (done) return AppointmentStatus.done;
    if (isSameDay(start, now)) return AppointmentStatus.today;
    if (start.isBefore(now)) return AppointmentStatus.overdue;
    return AppointmentStatus.upcoming;
  }

  /// z. B. "10:00 – 11:30"
  String get timeRange {
    final f = DateFormat.Hm('de');
    return '${f.format(start)} – ${f.format(end)}';
  }

  /// z. B. "Mo., 24. Nov. 2026, 10:00 – 11:30"
  String get dateTimeLabel =>
      '${DateFormat('EE, d. MMM y', 'de').format(start)}, $timeRange';

  static Map<String, String> _stringMap(Object? value) =>
      (value as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {};
}

/// Status eines einzelnen Termins.
enum AppointmentStatus {
  /// Erledigt (abgehakt)
  done('Erledigt', Colors.green, Icons.check_circle),

  /// Heute fällig
  today('Heute', Colors.red, Icons.notifications_active),

  /// Liegt in der Vergangenheit, aber nicht erledigt
  overdue('Überfällig', Colors.red, Icons.warning_amber),

  /// Steht bevor
  upcoming('Bevorstehend', Colors.amber, Icons.schedule);

  const AppointmentStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Ampelstatus eines Geheges auf der Karte. Der höchste [severity]-Wert
/// aller Termine der Tiere im Gehege gewinnt.
enum EnclosureStatus {
  /// Alle Termine erledigt – alles okay (grün)
  ok(1, Colors.green, 'Alles erledigt'),

  /// Mindestens ein Termin steht bevor (gelb)
  upcoming(2, Colors.amber, 'Termin bevorstehend'),

  /// Mindestens ein Termin ist heute oder überfällig (rot)
  due(3, Colors.red, 'Termin heute / überfällig');

  const EnclosureStatus(this.severity, this.color, this.label);

  final int severity;
  final Color color;
  final String label;

  static EnclosureStatus fromAppointment(AppointmentStatus status) =>
      switch (status) {
        AppointmentStatus.done => ok,
        AppointmentStatus.upcoming => upcoming,
        AppointmentStatus.today || AppointmentStatus.overdue => due,
      };
}

/// Berechnet für jedes Gehege den Ampelstatus. Gehege ohne Termine
/// (bzw. ohne Tiere mit Terminen) sind nicht in der Map enthalten.
Map<int, EnclosureStatus> computeEnclosureStatuses({
  required Iterable<Animal> animals,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  final enclosureOfAnimal = {
    for (final a in animals)
      if (a.enclosureNr != null) a.id: a.enclosureNr!,
  };

  final result = <int, EnclosureStatus>{};
  for (final appointment in appointments) {
    final status = EnclosureStatus.fromAppointment(appointment.statusAt(now));
    for (final animalId in appointment.animalIds) {
      final enclosureNr = enclosureOfAnimal[animalId];
      if (enclosureNr == null) continue;
      final current = result[enclosureNr];
      if (current == null || status.severity > current.severity) {
        result[enclosureNr] = status;
      }
    }
  }
  return result;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
