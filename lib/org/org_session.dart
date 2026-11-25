import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'organization.dart';

enum OrgSessionStatus { signedOut, loading, noOrganization, ready, error }

/// Hält den eingeloggten Benutzer, seine aktive Organisation und seine
/// Mitgliedschaft (inkl. Rolle) und hört live auf Änderungen.
///
/// Alle Daten der App (Tiere, Gehege, Termine, ...) liegen unterhalb von
/// organizations/{orgId}. Die passenden Collections liefert diese Klasse.
class OrgSession extends ChangeNotifier {
  OrgSession._();

  static final OrgSession instance = OrgSession._();

  /// Navigator der App – wird gebraucht, um bei Verlust des Zugriffs
  /// alle geöffneten Seiten zu schließen.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orgSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;

  OrgSessionStatus _status = OrgSessionStatus.loading;
  User? _user;
  bool _userDocLoaded = false;
  String? _activeOrgId;
  Organization? _org;
  Member? _member;
  bool _orgLoaded = false;
  bool _memberLoaded = false;
  bool _orgFromCache = false;
  bool _memberFromCache = false;

  /// Fehlermeldung, wenn [status] == [OrgSessionStatus.error].
  String? errorMessage;

  /// Hinweis für den Benutzer, z. B. wenn er aus einer Organisation
  /// entfernt wurde.
  String? notice;

  OrgSessionStatus get status => _status;
  User? get user => _user;

  /// Nur gültig, wenn [status] == [OrgSessionStatus.ready].
  Organization get organization => _org!;
  Member get member => _member!;
  String get orgId => _org!.id;

  bool get isReady => _status == OrgSessionStatus.ready;

  /// Startet die Sitzung (einmalig in main()).
  void init() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  // ---------------------------------------------------------------------
  // Berechtigungen
  // ---------------------------------------------------------------------

  bool can(OrgPermission permission) {
    final org = _org;
    final member = _member;
    if (!isReady || org == null || member == null) return false;
    if (member.isOwner || member.uid == org.ownerId) return true;
    return org.roles[member.roleId]?.permissions.contains(permission) ?? false;
  }

  bool get isOwner => isReady && _member!.isOwner;

  // ---------------------------------------------------------------------
  // Collections der aktiven Organisation
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> get orgRef =>
      _db.collection('organizations').doc(orgId);

  CollectionReference<Map<String, dynamic>> get animals =>
      orgRef.collection('animals');

  CollectionReference<Map<String, dynamic>> eventsOf(String animalId) =>
      animals.doc(animalId).collection('events');

  CollectionReference<Map<String, dynamic>> get enclosures =>
      orgRef.collection('enclosures');

  CollectionReference<Map<String, dynamic>> get appointments =>
      orgRef.collection('appointments');

  CollectionReference<Map<String, dynamic>> get members =>
      orgRef.collection('members');

  CollectionReference<Map<String, dynamic>> get invitations =>
      orgRef.collection('invitations');

  // ---------------------------------------------------------------------
  // Interne Logik
  // ---------------------------------------------------------------------

  /// Lädt alles neu (z. B. nach einem Netzwerk- oder App-Check-Fehler).
  void retry() => _onAuth(_user);

  void _onAuth(User? user) {
    _userSub?.cancel();
    _cancelOrg();
    _user = user;
    _userDocLoaded = false;
    _activeOrgId = null;
    notice = null;
    errorMessage = null;

    if (user == null) {
      _setStatus(OrgSessionStatus.signedOut);
      return;
    }

    _setStatus(OrgSessionStatus.loading);
    _userSub = _db.collection('users').doc(user.uid).snapshots().listen((doc) {
      final orgId = doc.data()?['activeOrgId'] as String?;
      if (!_userDocLoaded ||
          orgId != _activeOrgId ||
          _status == OrgSessionStatus.error) {
        _userDocLoaded = true;
        _switchTo(orgId);
      }
    }, onError: (Object e) => _fail(e));
  }

  void _switchTo(String? orgId) {
    _cancelOrg();
    _activeOrgId = orgId;
    errorMessage = null;

    if (orgId == null) {
      _setStatus(OrgSessionStatus.noOrganization);
      return;
    }

    _setStatus(OrgSessionStatus.loading);
    final orgRef = _db.collection('organizations').doc(orgId);

    _orgSub = orgRef.snapshots().listen((doc) {
      _org = doc.exists ? Organization.fromDoc(doc) : null;
      _orgLoaded = true;
      _orgFromCache = doc.metadata.isFromCache;
      _evaluate(orgId);
    }, onError: (Object e) => _checkMembershipAfterError(orgId, e));
    _memberSub = orgRef
        .collection('members')
        .doc(_user!.uid)
        .snapshots()
        .listen((doc) {
          _member = doc.exists ? Member.fromDoc(doc) : null;
          _memberLoaded = true;
          _memberFromCache = doc.metadata.isFromCache;
          _evaluate(orgId);
        }, onError: (Object e) => _checkMembershipAfterError(orgId, e));
  }

  void _evaluate(String orgId) {
    if (_activeOrgId != orgId || !_orgLoaded || !_memberLoaded) return;
    if (_org == null || _member == null) {
      // Nur auf eine Antwort des Servers verlassen, nicht auf den Cache.
      final confirmed =
          (_org == null && !_orgFromCache) ||
          (_member == null && !_memberFromCache);
      if (confirmed) _lostAccess(orgId);
      return;
    }
    notice = null;
    errorMessage = null;
    _setStatus(OrgSessionStatus.ready);
  }

  /// Nach einem Lesefehler prüfen, ob die Mitgliedschaft wirklich weg ist
  /// (dann "kein Zugriff mehr") oder ob es nur ein vorübergehendes Problem
  /// ist (dann Fehleranzeige mit "Erneut versuchen" – es wird nichts
  /// gelöscht oder abgewählt).
  Future<void> _checkMembershipAfterError(String orgId, Object error) async {
    if (_activeOrgId != orgId) return;
    try {
      final member = await _db
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc(_user!.uid)
          .get(const GetOptions(source: Source.server));
      if (_activeOrgId != orgId) return;
      if (!member.exists) {
        _lostAccess(orgId);
        return;
      }
    } catch (_) {
      // Server nicht erreichbar oder App Check fehlgeschlagen
    }
    _fail(error);
  }

  void _fail(Object error) {
    final wasReady = _status == OrgSessionStatus.ready;
    _cancelOrg();
    errorMessage = _describe(error);
    _setStatus(OrgSessionStatus.error);
    if (wasReady) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  static String _describe(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Zugriff verweigert (permission-denied). Das kann an einer '
              'fehlgeschlagenen App-Check-Prüfung oder an fehlenden Rechten '
              'liegen.',
        'unavailable' =>
          'Der Server ist gerade nicht erreichbar. Bitte Internetverbindung '
              'prüfen.',
        _ => '${error.message ?? 'Unbekannter Fehler'} (${error.code})',
      };
    }
    return error.toString();
  }

  /// Die Organisation existiert nicht mehr oder der Benutzer wurde
  /// entfernt (vom Server bestätigt) → zurück zur Organisationsauswahl.
  void _lostAccess(String orgId) {
    if (_activeOrgId != orgId) return;
    final wasReady = _status == OrgSessionStatus.ready;
    _cancelOrg();
    _activeOrgId = null;
    notice = 'Du bist nicht mehr Mitglied dieser Organisation.';
    _setStatus(OrgSessionStatus.noOrganization);

    if (wasReady) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    final uid = _user?.uid;
    if (uid != null) {
      _db.collection('users').doc(uid).set({
        'activeOrgId': null,
      }, SetOptions(merge: true)).ignore();
    }
  }

  void _cancelOrg() {
    _orgSub?.cancel();
    _memberSub?.cancel();
    _orgSub = null;
    _memberSub = null;
    _org = null;
    _member = null;
    _orgLoaded = false;
    _memberLoaded = false;
    _orgFromCache = false;
    _memberFromCache = false;
  }

  void _setStatus(OrgSessionStatus status) {
    _status = status;
    notifyListeners();
  }
}

/// Stellt die [OrgSession] im Widget-Baum bereit. Liegt oberhalb des
/// Navigators, damit auch geöffnete Seiten und Dialoge Zugriff haben.
class OrgScope extends InheritedNotifier<OrgSession> {
  const OrgScope({super.key, required OrgSession session, required super.child})
    : super(notifier: session);

  static OrgSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrgScope>()!.notifier!;
}
