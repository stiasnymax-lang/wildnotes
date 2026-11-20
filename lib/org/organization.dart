import 'package:cloud_firestore/cloud_firestore.dart';

/// Einzelne Berechtigungen, die einer Rolle zugewiesen werden können.
/// Lesen dürfen alle Mitglieder einer Organisation.
///
/// Die [key]s werden genauso in Firestore gespeichert und in den
/// Sicherheitsregeln (firestore.rules) geprüft.
enum OrgPermission {
  animalsEdit(
    'animals.edit',
    'Tiere verwalten',
    'Tiere anlegen, bearbeiten und löschen',
  ),
  eventsEdit(
    'events.edit',
    'Protokoll verwalten',
    'Events zu Tieren anlegen, bearbeiten und löschen',
  ),
  appointmentsEdit(
    'appointments.edit',
    'Termine verwalten',
    'Termine anlegen, bearbeiten und löschen',
  ),
  appointmentsComplete(
    'appointments.complete',
    'Termine abhaken',
    'Termine als erledigt markieren oder wieder öffnen',
  ),
  membersManage(
    'members.manage',
    'Mitglieder verwalten',
    'Mitglieder einladen, entfernen und ihre Rolle ändern',
  ),
  rolesManage(
    'roles.manage',
    'Rollen & Organisation verwalten',
    'Rollen anlegen, Berechtigungen ändern, Organisation umbenennen',
  );

  const OrgPermission(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  static OrgPermission? fromKey(String key) {
    for (final p in values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// ID der Inhaber-Rolle. Der Inhaber hat immer alle Rechte.
const String kOwnerRoleId = 'owner';

/// Eine Rolle mit ihren Berechtigungen.
class OrgRole {
  const OrgRole({
    required this.id,
    required this.name,
    required this.permissions,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final Set<OrgPermission> permissions;

  /// Standardrollen können nicht gelöscht werden.
  final bool builtIn;

  bool get isOwner => id == kOwnerRoleId;

  factory OrgRole.fromMap(String id, Map<String, dynamic> map) {
    final keys = (map['permissions'] as List?)?.cast<String>() ?? const [];
    return OrgRole(
      id: id,
      name: map['name'] as String? ?? id,
      permissions: keys.map(OrgPermission.fromKey).nonNulls.toSet(),
      builtIn: map['builtIn'] as bool? ?? false,
    );
  }

  Map<String, Object> toMap() => {
    'name': name,
    'permissions': [for (final p in permissions) p.key],
    'builtIn': builtIn,
  };

  OrgRole copyWith({String? name, Set<OrgPermission>? permissions}) => OrgRole(
    id: id,
    name: name ?? this.name,
    permissions: permissions ?? this.permissions,
    builtIn: builtIn,
  );
}

/// Rollen, mit denen jede neue Organisation startet.
final Map<String, OrgRole> kDefaultRoles = {
  kOwnerRoleId: OrgRole(
    id: kOwnerRoleId,
    name: 'Inhaber',
    permissions: OrgPermission.values.toSet(),
    builtIn: true,
  ),
  'admin': OrgRole(
    id: 'admin',
    name: 'Administrator',
    permissions: OrgPermission.values.toSet(),
    builtIn: true,
  ),
  'keeper': const OrgRole(
    id: 'keeper',
    name: 'Tierpfleger',
    permissions: {
      OrgPermission.animalsEdit,
      OrgPermission.eventsEdit,
      OrgPermission.appointmentsEdit,
      OrgPermission.appointmentsComplete,
    },
    builtIn: true,
  ),
  'viewer': const OrgRole(
    id: 'viewer',
    name: 'Betrachter',
    permissions: {},
    builtIn: true,
  ),
};

/// Eine Organisation (z. B. ein Zoo oder Tierpark).
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.roles,
  });

  final String id;
  final String name;
  final String ownerId;
  final Map<String, OrgRole> roles;

  factory Organization.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rolesMap = (data['roles'] as Map?)?.cast<String, dynamic>() ?? {};
    return Organization(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      roles: {
        for (final e in rolesMap.entries)
          e.key: OrgRole.fromMap(
            e.key,
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
    );
  }

  String roleName(String roleId) => roles[roleId]?.name ?? roleId;

  /// Rollen sortiert: Standardrollen zuerst, dann eigene Rollen alphabetisch.
  List<OrgRole> get sortedRoles {
    const order = [kOwnerRoleId, 'admin', 'keeper', 'viewer'];
    int rank(OrgRole r) {
      final i = order.indexOf(r.id);
      return i == -1 ? order.length : i;
    }

    return roles.values.toList()..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.name.compareTo(b.name);
    });
  }

  /// Rollen, die man beim Einladen oder Zuweisen vergeben kann.
  List<OrgRole> get assignableRoles =>
      sortedRoles.where((r) => !r.isOwner).toList();
}

/// Ein Mitglied einer Organisation
/// (organizations/{orgId}/members/{uid}).
class Member {
  const Member({required this.uid, required this.email, required this.roleId});

  final String uid;
  final String email;
  final String roleId;

  bool get isOwner => roleId == kOwnerRoleId;

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Member(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      roleId: data['role'] as String? ?? 'viewer',
    );
  }
}

/// Eine offene Einladung (organizations/{orgId}/invitations/{email}).
class Invitation {
  const Invitation({
    required this.email,
    required this.orgId,
    required this.orgName,
    required this.roleId,
    required this.invitedByEmail,
  });

  final String email;
  final String orgId;
  final String orgName;
  final String roleId;
  final String invitedByEmail;

  factory Invitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Invitation(
      email: data['email'] as String? ?? doc.id,
      orgId: data['orgId'] as String? ?? '',
      orgName: data['orgName'] as String? ?? '',
      roleId: data['role'] as String? ?? 'viewer',
      invitedByEmail: data['invitedByEmail'] as String? ?? '',
    );
  }
}

/// E-Mail-Adressen werden immer klein geschrieben gespeichert,
/// damit Einladungen unabhängig von der Schreibweise gefunden werden.
String normalizeEmail(String email) => email.trim().toLowerCase();
