import 'package:material_ui/material_ui.dart';

import '../feature_appointments/calendar_screen.dart';
import '../org/org_session.dart';
import '../org/org_setup_screen.dart';
import '../org/organization_screen.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'map_screen.dart';

/// Entscheidet nach dem Login, was angezeigt wird: Ladeanzeige,
/// Organisationsauswahl oder der Hauptbereich der App.
class OrgGate extends StatelessWidget {
  const OrgGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    return switch (session.status) {
      OrgSessionStatus.ready => const MainShell(),
      OrgSessionStatus.noOrganization => const OrgSetupScreen(),
      OrgSessionStatus.loading || OrgSessionStatus.signedOut => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
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
