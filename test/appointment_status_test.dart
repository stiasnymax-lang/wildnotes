import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_tiergarto/feature_animals/animal.dart';
import 'package:flutter_application_tiergarto/feature_appointments/appointment.dart';
import 'package:flutter_application_tiergarto/org/organization.dart';

Appointment _appointment(
  DateTime start, {
  bool done = false,
  List<String> animals = const [],
}) => Appointment(
  id: 'a${start.millisecondsSinceEpoch}',
  subject: 'Test',
  description: '',
  start: start,
  end: start.add(const Duration(hours: 1)),
  animalNames: {for (final id in animals) id: id},
  participantEmails: const {},
  done: done,
);

void main() {
  final now = DateTime(2026, 11, 20, 12);

  group('Terminstatus', () {
    test('heute → rot', () {
      final a = _appointment(DateTime(2026, 11, 20, 15));
      expect(a.statusAt(now), AppointmentStatus.today);
    });

    test('heute, aber Uhrzeit schon vorbei → trotzdem heute', () {
      final a = _appointment(DateTime(2026, 11, 20, 8));
      expect(a.statusAt(now), AppointmentStatus.today);
    });

    test('in der Zukunft → bevorstehend', () {
      final a = _appointment(DateTime(2026, 11, 23, 9));
      expect(a.statusAt(now), AppointmentStatus.upcoming);
    });

    test('vergangen und offen → überfällig', () {
      final a = _appointment(DateTime(2026, 11, 18, 9));
      expect(a.statusAt(now), AppointmentStatus.overdue);
    });

    test('erledigt → erledigt, egal wann', () {
      final a = _appointment(DateTime(2026, 11, 20, 15), done: true);
      expect(a.statusAt(now), AppointmentStatus.done);
    });
  });

  group('Gehege-Ampel', () {
    const animals = [
      Animal(id: 'leo', name: 'Leo', info: '', enclosureNr: 1),
      Animal(id: 'mia', name: 'Mia', info: '', enclosureNr: 1),
      Animal(id: 'kiki', name: 'Kiki', info: '', enclosureNr: 2),
      Animal(id: 'bob', name: 'Bob', info: '', enclosureNr: 3),
      Animal(id: 'ohne', name: 'Ohne', info: ''),
    ];

    test('höchste Dringlichkeit gewinnt pro Gehege', () {
      final statuses = computeEnclosureStatuses(
        animals: animals,
        now: now,
        appointments: [
          _appointment(DateTime(2026, 11, 25), animals: ['leo']),
          _appointment(DateTime(2026, 11, 20, 16), animals: ['mia']),
          _appointment(DateTime(2026, 11, 22), animals: ['kiki']),
          _appointment(DateTime(2026, 11, 10), done: true, animals: ['kiki']),
          _appointment(DateTime(2026, 11, 10), done: true, animals: ['bob']),
        ],
      );
      expect(statuses, {
        1: EnclosureStatus.due,
        2: EnclosureStatus.upcoming,
        3: EnclosureStatus.ok,
      });
    });

    test('Gehege ohne Termine und Tiere ohne Gehege fehlen', () {
      final statuses = computeEnclosureStatuses(
        animals: animals,
        now: now,
        appointments: [
          _appointment(DateTime(2026, 11, 22), animals: ['ohne', 'gelöscht']),
        ],
      );
      expect(statuses, isEmpty);
    });
  });

  group('Rollen', () {
    test('Standardrollen: Inhaber/Admin alles, Betrachter nichts', () {
      expect(
        kDefaultRoles[kOwnerRoleId]!.permissions,
        OrgPermission.values.toSet(),
      );
      expect(kDefaultRoles['admin']!.permissions, OrgPermission.values.toSet());
      expect(kDefaultRoles['viewer']!.permissions, isEmpty);
      expect(
        kDefaultRoles['keeper']!.permissions,
        isNot(contains(OrgPermission.membersManage)),
      );
    });

    test('Rolle übersteht Speichern und Laden', () {
      final role = kDefaultRoles['keeper']!;
      final restored = OrgRole.fromMap(role.id, role.toMap());
      expect(restored.name, role.name);
      expect(restored.permissions, role.permissions);
      expect(restored.builtIn, isTrue);
    });

    test('unbekannte Berechtigungen werden ignoriert', () {
      final role = OrgRole.fromMap('x', {
        'name': 'X',
        'permissions': ['animals.edit', 'gibt.es.nicht'],
      });
      expect(role.permissions, {OrgPermission.animalsEdit});
    });

    test('E-Mail wird normalisiert', () {
      expect(
        normalizeEmail('  Max.Muster@Example.DE '),
        'max.muster@example.de',
      );
    });
  });
}
