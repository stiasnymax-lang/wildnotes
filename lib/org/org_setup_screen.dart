import 'package:material_ui/material_ui.dart';

import '../core/settings_screen.dart';
import '../utils/messages.dart';
import 'org_service.dart';
import 'org_session.dart';
import 'org_widgets.dart';
import '../utils/responsive.dart';

/// Wird angezeigt, solange keine Organisation aktiv ist: Einladungen
/// annehmen, eine bestehende Organisation wählen oder eine neue anlegen.
class OrgSetupScreen extends StatefulWidget {
  const OrgSetupScreen({super.key});

  @override
  State<OrgSetupScreen> createState() => _OrgSetupScreenState();
}

class _OrgSetupScreenState extends State<OrgSetupScreen> {
  final _name = TextEditingController();
  bool _importLegacy = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Bitte einen Namen eingeben');
      return;
    }
    final user = OrgScope.of(context).user!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final orgId = await OrgService.createOrganization(user: user, name: name);
      if (_importLegacy) {
        final count = await OrgService.importLegacyData(orgId);
        messenger.showMessage(
          'Organisation erstellt – $count Tiere übernommen.',
          long: true,
        );
      } else {
        messenger.showMessage('Organisation erstellt');
      }
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _select(String orgId) async {
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OrgService.selectOrganization(session.user!, orgId);
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    final user = session.user;
    if (user == null) return const Scaffold();

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
            if (session.notice != null)
              Card(
                margin: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(session.notice!),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'In WildNotes gehören Tiere, Gehege und Termine immer zu einer '
                'Organisation. Nimm eine Einladung an, wähle eine deiner '
                'Organisationen oder lege eine neue an.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            MyInvitationsSection(user: user),
            StreamBuilder(
              stream: OrgService.myMemberships(user),
              builder: (context, snapshot) {
                final memberships = snapshot.data ?? const <String, String>{};
                if (memberships.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader('Meine Organisationen'),
                    for (final entry in memberships.entries)
                      ListTile(
                        leading: const Icon(Icons.apartment_outlined),
                        title: Text(entry.value),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _select(entry.key),
                      ),
                  ],
                );
              },
            ),
            const SectionHeader('Neue Organisation erstellen'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name der Organisation',
                  hintText: 'z. B. Tiergarten Musterstadt',
                ),
              ),
            ),
            // Nur für das Konto, das die Daten der alten App lesen darf
            FutureBuilder(
              future: OrgService.hasLegacyAccess(user),
              builder: (context, snapshot) => snapshot.data == true
                  ? CheckboxListTile(
                      value: _importLegacy,
                      onChanged: (v) =>
                          setState(() => _importLegacy = v ?? false),
                      title: const Text('Bisherige Tiere & Gehege übernehmen'),
                      subtitle: const Text(
                        'Kopiert die Daten aus der alten App in die neue '
                        'Organisation.',
                      ),
                    )
                  : const SizedBox(height: 16),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Organisation erstellen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
