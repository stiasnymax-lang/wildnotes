import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../core/settings_screen.dart';
import '../utils/messages.dart';
import 'join_code.dart';
import 'org_service.dart';
import 'org_session.dart';
import 'org_widgets.dart';
import 'organization.dart';
import 'roles_screen.dart';
import '../utils/responsive.dart';

/// Organisationsverwaltung: Mitglieder sehen, einladen, entfernen,
/// Rollen zuweisen sowie Rollen & Berechtigungen verwalten.
class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key});

  Future<void> _rename(BuildContext context, OrgSession session) async {
    final org = session.organization;
    final name = await showTextInputDialog(
      context,
      title: 'Organisation umbenennen',
      label: 'Name',
      initialValue: org.name,
    );
    if (name == null || name == org.name || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.renameOrganization(org.id, name);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _switch(BuildContext context, OrgSession session) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.selectOrganization(session.user!, null);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _leave(BuildContext context, OrgSession session) async {
    final ok = await confirmAction(
      context,
      title: 'Organisation verlassen?',
      message:
          'Du verlierst den Zugriff auf alle Daten von '
          '„${session.organization.name}". Für einen erneuten Beitritt '
          'brauchst du eine neue Einladung.',
      confirmLabel: 'Verlassen',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.leaveOrganization(session.user!, session.orgId);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _import(BuildContext context, OrgSession session) async {
    final ok = await confirmAction(
      context,
      title: 'Daten übernehmen?',
      message:
          'Tiere (inkl. Events) und Gehege aus der alten App werden in '
          'diese Organisation kopiert. Bereits übernommene Einträge werden '
          'dabei mit dem alten Stand überschrieben.',
      confirmLabel: 'Übernehmen',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await OrgService.importLegacyData(session.orgId);
      messenger.showMessage('$count Tiere übernommen.');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    final org = session.organization;
    final me = session.member;
    final canManageMembers = session.can(OrgPermission.membersManage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organisation'),
        actions: [
          IconButton(
            tooltip: 'Konto',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.apartment)),
                title: Text(
                  org.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text('Deine Rolle: ${org.roleName(me.roleId)}'),
                trailing: session.can(OrgPermission.rolesManage)
                    ? IconButton(
                        tooltip: 'Umbenennen',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _rename(context, session),
                      )
                    : null,
              ),
            ),
            SectionHeader(
              'Mitglieder',
              trailing: canManageMembers
                  ? TextButton.icon(
                      onPressed: () => showInviteDialog(
                        context,
                        org: org,
                        invitedBy: session.user!,
                      ),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Einladen'),
                    )
                  : null,
            ),
            const _MemberList(),
            if (canManageMembers) const _PendingInvitations(),
            if (canManageMembers) const _JoinCodeSection(),
            const SectionHeader('Verwaltung'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Rollen & Berechtigungen'),
              subtitle: Text('${org.roles.length} Rollen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RolesScreen())),
            ),
            // Nur Inhaber, und nur mit Zugriff auf die Daten der alten App
            if (session.isOwner)
              FutureBuilder(
                future: OrgService.hasLegacyAccess(session.user!),
                builder: (context, snapshot) => snapshot.data == true
                    ? ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('Daten aus alter App übernehmen'),
                        subtitle: const Text(
                          'Tiere, Events und Gehege kopieren',
                        ),
                        onTap: () => _import(context, session),
                      )
                    : const SizedBox.shrink(),
              ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Organisation wechseln oder neu erstellen'),
              onTap: () => _switch(context, session),
            ),
            if (!session.isOwner)
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Organisation verlassen'),
                onTap: () => _leave(context, session),
              ),
            MyInvitationsSection(user: session.user!),
          ],
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList();

  Future<void> _changeRole(
    BuildContext context,
    OrgSession session,
    Member member,
  ) async {
    final roleId = await showRolePicker(
      context,
      org: session.organization,
      currentRoleId: member.roleId,
    );
    if (roleId == null || roleId == member.roleId || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.setMemberRole(session.orgId, member.uid, roleId);
      messenger.showMessage('Rolle geändert');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _remove(
    BuildContext context,
    OrgSession session,
    Member member,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Mitglied entfernen?',
      message: '${member.email} verliert den Zugriff auf die Organisation.',
      confirmLabel: 'Entfernen',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.removeMember(session.orgId, member.uid);
      messenger.showMessage('${member.email} entfernt');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    final org = session.organization;
    final canManage = session.can(OrgPermission.membersManage);

    return StreamBuilder(
      stream: session.members.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(title: Text(errorText(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final members = snapshot.data!.docs.map(Member.fromDoc).toList()
          ..sort((a, b) {
            if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
            return a.email.compareTo(b.email);
          });

        return Column(
          children: [
            for (final member in members)
              ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.email.isEmpty ? '?' : member.email[0].toUpperCase(),
                  ),
                ),
                title: Text(member.email),
                subtitle: Text(
                  member.uid == session.member.uid
                      ? '${org.roleName(member.roleId)} · Du'
                      : org.roleName(member.roleId),
                ),
                trailing:
                    canManage &&
                        !member.isOwner &&
                        member.uid != session.member.uid
                    ? PopupMenuButton<String>(
                        onSelected: (action) => action == 'role'
                            ? _changeRole(context, session, member)
                            : _remove(context, session, member),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'role',
                            child: Text('Rolle ändern'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Entfernen'),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _PendingInvitations extends StatelessWidget {
  const _PendingInvitations();

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    final org = session.organization;

    return StreamBuilder(
      stream: session.invitations.snapshots(),
      builder: (context, snapshot) {
        final invitations =
            snapshot.data?.docs.map(Invitation.fromDoc).toList() ?? const [];
        if (invitations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Offene Einladungen'),
            for (final inv in invitations)
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(inv.email),
                subtitle: Text('${org.roleName(inv.roleId)} · ausstehend'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Einladungstext',
                      icon: const Icon(Icons.copy),
                      onPressed: () => showInviteText(
                        context,
                        orgName: org.name,
                        email: inv.email,
                        roleName: org.roleName(inv.roleId),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zurückziehen',
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await OrgService.revokeInvitation(org.id, inv.email);
                          messenger.showMessage('Einladung zurückgezogen');
                        } catch (e) {
                          messenger.showMessage(errorText(e), long: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Beitrittscode (24 Zeichen) und Beitrittslink der Organisation. Wer den
/// Code oder Link hat, kann als "Betrachter" beitreten; die Rolle lässt
/// sich danach in der Mitgliederliste ändern.
class _JoinCodeSection extends StatefulWidget {
  const _JoinCodeSection();

  @override
  State<_JoinCodeSection> createState() => _JoinCodeSectionState();
}

class _JoinCodeSectionState extends State<_JoinCodeSection> {
  bool _busy = false;

  Future<void> _generate({required bool replace}) async {
    final session = OrgScope.of(context);
    final org = session.organization;
    final messenger = ScaffoldMessenger.of(context);
    if (replace) {
      final ok = await confirmAction(
        context,
        title: 'Neuen Code erzeugen?',
        message:
            'Der bisherige Code und Link funktionieren danach nicht mehr. '
            'Bereits beigetretene Mitglieder bleiben Mitglieder.',
        confirmLabel: 'Neu erzeugen',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await OrgService.createJoinCode(
        orgId: org.id,
        orgName: org.name,
        oldCode: org.joinCode,
      );
      messenger.showMessage('Beitrittscode erzeugt');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _copy(String text, String what) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showMessage('$what kopiert');
  }

  @override
  Widget build(BuildContext context) {
    final org = OrgScope.of(context).organization;
    final code = org.joinCode;
    final roleName = org.roleName(kJoinCodeRoleId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Beitreten per Code'),
        if (code == null)
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Noch kein Beitrittscode vorhanden'),
            subtitle: const Text(
              'Mit Code oder Link können neue Mitglieder ohne Einladung '
              'beitreten.',
            ),
            trailing: FilledButton.tonal(
              onPressed: _busy ? null : () => _generate(replace: false),
              child: const Text('Erzeugen'),
            ),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: SelectableText(
              formatJoinCode(code),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            subtitle: Text('Beitrittscode · neue Mitglieder: $roleName'),
            trailing: IconButton(
              tooltip: 'Code kopieren',
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(code, 'Code'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: SelectableText(
              joinLink(code),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            subtitle: const Text('Beitrittslink'),
            trailing: IconButton(
              tooltip: 'Link kopieren',
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(joinLink(code), 'Link'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _busy ? null : () => _generate(replace: true),
                icon: const Icon(Icons.autorenew),
                label: const Text('Neuen Code erzeugen'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
