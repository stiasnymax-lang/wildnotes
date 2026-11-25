import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/verify_email_screen.dart';
import '../feature_appointments/calendar_screen.dart';
import '../org/join_code.dart';
import '../org/org_service.dart';
import '../org/org_session.dart';
import '../org/org_setup_screen.dart';
import '../org/organization_screen.dart';
import '../utils/messages.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Entscheidet nach dem Login, was angezeigt wird: E-Mail-Bestätigung,
/// Ladeanzeige, Fehler, Organisationsauswahl oder der Hauptbereich der App.
class OrgGate extends StatelessWidget {
  const OrgGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      return const VerifyEmailScreen();
    }
    return switch (session.status) {
      OrgSessionStatus.ready => const MainShell(),
      OrgSessionStatus.noOrganization => const OrgSetupScreen(),
      OrgSessionStatus.error => const _OrgErrorScreen(),
      OrgSessionStatus.loading || OrgSessionStatus.signedOut => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// Organisation konnte nicht geladen werden (z. B. Netzwerk oder App
/// Check). Es wird nichts gelöscht – man kann es einfach erneut versuchen.
class _OrgErrorScreen extends StatelessWidget {
  const _OrgErrorScreen();

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('WildNotes'),
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
      body: ContentWidth.narrow(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Die Daten konnten gerade nicht geladen werden.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session.errorMessage ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: session.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                final user = session.user;
                if (user != null) {
                  OrgService.selectOrganization(user, null).ignore();
                }
              },
              child: const Text('Andere Organisation wählen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hauptbereich der App mit Bottom Navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Über einen Beitrittslink geöffnet, aber schon in einer Organisation?
    if (PendingJoin.code != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerJoin());
    }
  }

  Future<void> _offerJoin() async {
    final code = PendingJoin.code;
    if (code == null || !mounted) return;
    PendingJoin.code = null;
    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (session.organization.joinCode == code) return; // schon Mitglied

    final ok = await confirmAction(
      context,
      title: 'Organisation beitreten?',
      message:
          'Du hast einen Beitrittslink geöffnet. Möchtest du der '
          'Organisation beitreten und zu ihr wechseln?',
      confirmLabel: 'Beitreten',
    );
    if (!ok) return;
    try {
      final name = await OrgService.joinWithCode(session.user!, code);
      messenger.showMessage('Willkommen bei $name!');
    } catch (e) {
      messenger.showMessage(errorText(e), long: true);
    }
  }

  static const _pages = <Widget>[
    HomeScreen(),
    MapScreen(),
    CalendarScreen(),
    LibraryScreen(),
    OrganizationScreen(),
  ];

  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.map_outlined, Icons.map, 'Karte'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Kalender'),
    (Icons.pets_outlined, Icons.pets, 'Tiere'),
    (Icons.groups_outlined, Icons.groups, 'Organisation'),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(index: _index, children: _pages);

    // Handy: Navigation unten. Tablet/Desktop: Navigationsleiste links,
    // ab Desktop-Breite mit Beschriftung.
    if (!context.isExpanded) {
      return Scaffold(
        body: pages,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, selected, label) in _destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }

    final extended = context.isLarge;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pets,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    if (extended) ...[
                      const SizedBox(width: 8),
                      Text(
                        'WildNotes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages),
        ],
      ),
    );
  }
}
