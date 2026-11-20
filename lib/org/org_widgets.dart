import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../utils/messages.dart';
import 'org_service.dart';
import 'organization.dart';

/// Überschrift für einen Abschnitt in Listen.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Offene Einladungen an den eingeloggten Benutzer mit
/// "Annehmen" / "Ablehnen". Zeigt nichts an, wenn es keine gibt.
class MyInvitationsSection extends StatelessWidget {
  const MyInvitationsSection({super.key, required this.user});

  final User user;

  Future<void> _accept(BuildContext context, Invitation inv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.acceptInvitation(user, inv);
      messenger.showMessage('Willkommen bei ${inv.orgName}!');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  Future<void> _decline(BuildContext context, Invitation inv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.declineInvitation(inv);
      messenger.showMessage('Einladung abgelehnt');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: OrgService.myInvitations(user),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Einladungen konnten nicht geladen werden'),
            subtitle: Text(errorText(snapshot.error!)),
          );
        }
        final invitations = snapshot.data ?? const <Invitation>[];
        if (invitations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Einladungen an dich'),
            for (final inv in invitations)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.orgName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('Eingeladen von ${inv.invitedByEmail}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _decline(context, inv),
                            child: const Text('Ablehnen'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _accept(context, inv),
                            child: const Text('Annehmen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Dialog zum Einladen eines neuen Mitglieds. Erstellt die Einladung und
/// zeigt danach einen Text, den man dem Empfänger schicken kann.
Future<void> showInviteDialog(
  BuildContext context, {
  required Organization org,
  required User invitedBy,
}) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => _InviteDialog(org: org),
  );
  if (result == null || !context.mounted) return;

  final (email, roleId) = result;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await OrgService.invite(
      orgId: org.id,
      orgName: org.name,
      email: email,
      roleId: roleId,
      invitedBy: invitedBy,
    );
  } catch (e) {
    messenger.showMessage(errorText(e), long: true);
    return;
  }
  if (!context.mounted) return;
  await showInviteText(
    context,
    orgName: org.name,
    email: normalizeEmail(email),
    roleName: org.roleName(roleId),
  );
}

/// Zeigt den Einladungstext zum Kopieren an. Die App verschickt selbst
/// keine E-Mails – die Einladung erscheint beim Empfänger nach dem Login.
Future<void> showInviteText(
  BuildContext context, {
  required String orgName,
  required String email,
  required String roleName,
}) {
  final text =
      'Hallo! Du wurdest in der WildNotes-App zur Organisation '
      '„$orgName" eingeladen (Rolle: $roleName). Registriere dich bzw. '
      'melde dich in WildNotes mit der E-Mail-Adresse $email an – die '
      'Einladung wird dir dann direkt angezeigt.';

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Einladung erstellt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sobald sich $email in WildNotes anmeldet, erscheint die '
            'Einladung automatisch. Du kannst ihr diesen Text schicken:',
          ),
          const SizedBox(height: 12),
          SelectableText(text),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              showMessage(context, 'Text kopiert');
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Kopieren'),
        ),
      ],
    ),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.org});

  final Organization org;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late String _roleId = widget.org.roles.containsKey('keeper')
      ? 'keeper'
      : widget.org.assignableRoles.first.id;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mitglied einladen'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return 'E-Mail eingeben';
                if (!_emailPattern.hasMatch(email)) {
                  return 'Ungültige E-Mail-Adresse';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _roleId,
              decoration: const InputDecoration(labelText: 'Rolle'),
              items: [
                for (final role in widget.org.assignableRoles)
                  DropdownMenuItem(value: role.id, child: Text(role.name)),
              ],
              onChanged: (v) => setState(() => _roleId = v ?? _roleId),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((_email.text.trim(), _roleId));
          },
          child: const Text('Einladen'),
        ),
      ],
    );
  }
}

/// Dialog zur Auswahl einer Rolle; liefert die Rollen-ID.
Future<String?> showRolePicker(
  BuildContext context, {
  required Organization org,
  required String currentRoleId,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Rolle ändern'),
      children: [
        RadioGroup<String>(
          groupValue: currentRoleId,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            children: [
              for (final role in org.assignableRoles)
                RadioListTile<String>(value: role.id, title: Text(role.name)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Dialog mit einem Textfeld (z. B. für Namen); liefert den Text.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String confirmLabel = 'Speichern',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.of(context).pop(v);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
