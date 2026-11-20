import 'package:material_ui/material_ui.dart';

import '../utils/messages.dart';
import 'org_service.dart';
import 'org_session.dart';
import 'org_widgets.dart';
import 'organization.dart';
import '../utils/responsive.dart';

/// Rollen & Berechtigungen: zeigt für jede Rolle, was sie darf.
/// Mit der Berechtigung "Rollen verwalten" lassen sich Berechtigungen
/// ändern sowie eigene Rollen anlegen und löschen.
class RolesScreen extends StatelessWidget {
  const RolesScreen({super.key});

  Future<void> _addRole(BuildContext context, OrgSession session) async {
    final name = await showTextInputDialog(
      context,
      title: 'Neue Rolle',
      label: 'Name der Rolle',
      confirmLabel: 'Anlegen',
    );
    if (name == null || !context.mounted) return;
    final role = OrgRole(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      permissions: const {},
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.saveRole(session.orgId, role);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    final canEdit = session.can(OrgPermission.rolesManage);

    return Scaffold(
      appBar: AppBar(title: const Text('Rollen & Berechtigungen')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _addRole(context, session),
              icon: const Icon(Icons.add),
              label: const Text('Rolle'),
            )
          : null,
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('Du kannst die Rollen ansehen, aber nicht ändern.'),
              ),
            for (final role in session.organization.sortedRoles)
              _RoleCard(role: role, canEdit: canEdit && !role.isOwner),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.canEdit});

  final OrgRole role;
  final bool canEdit;

  Future<void> _toggle(
    BuildContext context,
    OrgPermission permission,
    bool enabled,
  ) async {
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final permissions = {...role.permissions};
    enabled ? permissions.add(permission) : permissions.remove(permission);
    try {
      await OrgService.saveRole(
        session.orgId,
        role.copyWith(permissions: permissions),
      );
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _rename(BuildContext context) async {
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showTextInputDialog(
      context,
      title: 'Rolle umbenennen',
      label: 'Name',
      initialValue: role.name,
    );
    if (name == null || name == role.name) return;
    try {
      await OrgService.saveRole(session.orgId, role.copyWith(name: name));
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Rolle löschen?',
      message: 'Die Rolle „${role.name}" wird gelöscht.',
    );
    if (!ok) return;
    try {
      await OrgService.deleteRole(session.orgId, role.id);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(role.name),
        subtitle: Text(
          role.isOwner
              ? 'Hat immer alle Rechte'
              : '${role.permissions.length} von '
                    '${OrgPermission.values.length} Berechtigungen',
        ),
        children: [
          for (final permission in OrgPermission.values)
            CheckboxListTile(
              value: role.isOwner || role.permissions.contains(permission),
              onChanged: canEdit
                  ? (v) => _toggle(context, permission, v ?? false)
                  : null,
              title: Text(permission.label),
              subtitle: Text(permission.description),
            ),
          if (canEdit)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _rename(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Umbenennen'),
                ),
                if (!role.builtIn)
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Löschen'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
