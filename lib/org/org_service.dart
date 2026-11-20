import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'organization.dart';

/// Schreibende Aktionen rund um Organisationen, Mitglieder und Einladungen.
class OrgService {
  OrgService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _org(String orgId) =>
      _db.collection('organizations').doc(orgId);

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  static String _emailOf(User user) => normalizeEmail(user.email ?? '');

  // ---------------------------------------------------------------------
  // Organisation anlegen / wechseln / verlassen
  // ---------------------------------------------------------------------

  /// Legt eine neue Organisation an; der Benutzer wird Inhaber.
  static Future<String> createOrganization({
    required User user,
    required String name,
  }) async {
    final orgRef = _db.collection('organizations').doc();
    final batch = _db.batch()
      ..set(orgRef, {
        'name': name,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'roles': {
          for (final role in kDefaultRoles.values) role.id: role.toMap(),
        },
      })
      ..set(orgRef.collection('members').doc(user.uid), {
        'email': _emailOf(user),
        'role': kOwnerRoleId,
        'joinedAt': FieldValue.serverTimestamp(),
      })
      ..set(_userDoc(user.uid).collection('memberships').doc(orgRef.id), {
        'orgName': name,
        'joinedAt': FieldValue.serverTimestamp(),
      })
      ..set(_userDoc(user.uid), {
        'email': _emailOf(user),
        'activeOrgId': orgRef.id,
      }, SetOptions(merge: true));
    await batch.commit();
    return orgRef.id;
  }

  /// Wechselt die aktive Organisation (`null` = Auswahlseite anzeigen).
  static Future<void> selectOrganization(User user, String? orgId) =>
      _userDoc(user.uid).set({
        'email': _emailOf(user),
        'activeOrgId': orgId,
      }, SetOptions(merge: true));

  static Future<void> renameOrganization(String orgId, String name) =>
      _org(orgId).update({'name': name});

  /// Organisation verlassen (nicht für den Inhaber).
  static Future<void> leaveOrganization(User user, String orgId) async {
    // Zuerst die aktive Organisation abwählen, damit die App nicht
    // "Zugriff verloren" meldet.
    await selectOrganization(user, null);
    final batch = _db.batch()
      ..delete(_org(orgId).collection('members').doc(user.uid))
      ..delete(_userDoc(user.uid).collection('memberships').doc(orgId));
    await batch.commit();
  }

  // ---------------------------------------------------------------------
  // Einladungen
  // ---------------------------------------------------------------------

  /// Lädt eine E-Mail-Adresse in die Organisation ein. Die Einladung
  /// erscheint beim Empfänger nach dem Login automatisch in der App.
  static Future<void> invite({
    required String orgId,
    required String orgName,
    required String email,
    required String roleId,
    required User invitedBy,
  }) async {
    final normalized = normalizeEmail(email);
    final existing = await _org(orgId)
        .collection('members')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const OrgException('Diese Person ist bereits Mitglied.');
    }

    await _org(orgId).collection('invitations').doc(normalized).set({
      'email': normalized,
      'orgId': orgId,
      'orgName': orgName,
      'role': roleId,
      'invitedByEmail': _emailOf(invitedBy),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> revokeInvitation(String orgId, String email) =>
      _org(orgId).collection('invitations').doc(email).delete();

  /// Offene Einladungen für den eingeloggten Benutzer (alle Organisationen).
  static Stream<List<Invitation>> myInvitations(User user) => _db
      .collectionGroup('invitations')
      .where('email', isEqualTo: _emailOf(user))
      .snapshots()
      .map((s) => s.docs.map(Invitation.fromDoc).toList());

  /// Einladung annehmen: Mitglied werden und Organisation aktivieren.
  static Future<void> acceptInvitation(User user, Invitation inv) async {
    final orgRef = _org(inv.orgId);
    final batch = _db.batch()
      ..set(orgRef.collection('members').doc(user.uid), {
        'email': _emailOf(user),
        'role': inv.roleId,
        'joinedAt': FieldValue.serverTimestamp(),
      })
      ..delete(orgRef.collection('invitations').doc(inv.email))
      ..set(_userDoc(user.uid).collection('memberships').doc(inv.orgId), {
        'orgName': inv.orgName,
        'joinedAt': FieldValue.serverTimestamp(),
      })
      ..set(_userDoc(user.uid), {
        'email': _emailOf(user),
        'activeOrgId': inv.orgId,
      }, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> declineInvitation(Invitation inv) =>
      revokeInvitation(inv.orgId, inv.email);

  // ---------------------------------------------------------------------
  // Mitglieder
  // ---------------------------------------------------------------------

  static Future<void> setMemberRole(String orgId, String uid, String roleId) =>
      _org(orgId).collection('members').doc(uid).update({'role': roleId});

  static Future<void> removeMember(String orgId, String uid) =>
      _org(orgId).collection('members').doc(uid).delete();

  /// Organisationen, in denen der Benutzer Mitglied ist (orgId → Name).
  static Stream<Map<String, String>> myMemberships(User user) =>
      _userDoc(user.uid)
          .collection('memberships')
          .snapshots()
          .map(
            (s) => {
              for (final d in s.docs)
                d.id: d.data()['orgName'] as String? ?? '',
            },
          );

  /// Entfernt einen veralteten Eintrag aus der eigenen Organisationsliste.
  static Future<void> forgetMembership(User user, String orgId) =>
      _userDoc(user.uid).collection('memberships').doc(orgId).delete();

  // ---------------------------------------------------------------------
  // Rollen
  // ---------------------------------------------------------------------

  static Future<void> saveRole(String orgId, OrgRole role) =>
      _org(orgId).update({'roles.${role.id}': role.toMap()});

  static Future<void> deleteRole(String orgId, String roleId) async {
    final members = await _org(orgId)
        .collection('members')
        .where('role', isEqualTo: roleId)
        .limit(1)
        .get();
    if (members.docs.isNotEmpty) {
      throw const OrgException(
        'Die Rolle ist noch Mitgliedern zugewiesen. '
        'Bitte zuerst deren Rolle ändern.',
      );
    }
    await _org(orgId).update({'roles.$roleId': FieldValue.delete()});
  }

  // ---------------------------------------------------------------------
  // Datenübernahme aus der alten App
  // ---------------------------------------------------------------------

  static final Map<String, Future<bool>> _legacyAccess = {};

  /// Ob dieses Konto die Daten der alten App lesen darf. Laut
  /// Sicherheitsregeln ist das nur das Konto des Projektinhabers; für alle
  /// anderen wird die Übernahme gar nicht erst angeboten.
  static Future<bool> hasLegacyAccess(User user) =>
      _legacyAccess.putIfAbsent(user.uid, () async {
        try {
          await _db.collection('animals').limit(1).get();
          return true;
        } on FirebaseException {
          return false;
        }
      });

  /// Kopiert Tiere (inkl. Events) und Gehege aus den bisherigen
  /// Top-Level-Collections in die Organisation. Die alten Daten bleiben
  /// unverändert; Dokument-IDs werden beibehalten, ein erneuter Import
  /// überschreibt also nur und erzeugt keine Duplikate.
  ///
  /// Liefert die Anzahl der übernommenen Tiere.
  static Future<int> importLegacyData(String orgId) async {
    final orgRef = _org(orgId);
    final writer = _BatchWriter(_db);

    final animals = await _db.collection('animals').get();
    for (final animal in animals.docs) {
      final target = orgRef.collection('animals').doc(animal.id);
      await writer.set(target, animal.data());
      final events = await animal.reference.collection('events').get();
      for (final event in events.docs) {
        await writer.set(
          target.collection('events').doc(event.id),
          event.data(),
        );
      }
    }

    final enclosures = await _db.collection('enclosures').get();
    for (final enclosure in enclosures.docs) {
      await writer.set(
        orgRef.collection('enclosures').doc(enclosure.id),
        enclosure.data(),
      );
    }

    await writer.commit();
    return animals.docs.length;
  }
}

/// Fehler mit einer Meldung, die direkt angezeigt werden kann.
class OrgException implements Exception {
  const OrgException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Schreibt viele Dokumente in Batches (Firestore erlaubt max. 500 pro Batch).
class _BatchWriter {
  _BatchWriter(this._db);

  final FirebaseFirestore _db;
  late WriteBatch _batch = _db.batch();
  int _count = 0;

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    _batch.set(ref, data);
    if (++_count >= 400) await commit();
  }

  Future<void> commit() async {
    if (_count == 0) return;
    await _batch.commit();
    _batch = _db.batch();
    _count = 0;
  }
}
