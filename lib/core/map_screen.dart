import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_animals/animal.dart';
import '../feature_appointments/appointment.dart';
import '../org/org_session.dart';
import '../utils/messages.dart';
import 'enclosure_screen.dart';
import 'map_hotspots.dart';

/// Interaktive Zookarte (früher MapActivity).
///
/// Ein Tipp auf ein Gehege öffnet dessen Tierliste. Gehege, deren Tiere
/// Termine haben, leuchten: rot = Termin heute/überfällig,
/// gelb = Termin bevorstehend, grün = alles erledigt.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  String? _streamOrgId;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _animalsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream;

  void _ensureStreams(OrgSession session) {
    if (_streamOrgId == session.orgId) return;
    _streamOrgId = session.orgId;
    _animalsStream = session.animals.snapshots();
    _appointmentsStream = session.appointments.snapshots();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap(Offset local, Size size) {
    // Touch-Koordinaten in Bildpixel umrechnen
    final imagePoint = Offset(
      local.dx / size.width * kMapImageWidth,
      local.dy / size.height * kMapImageHeight,
    );

    final enclosureNr = findEnclosureByImagePoint(imagePoint);
    if (enclosureNr == null) {
      showMessage(context, 'Kein Gehege ausgewählt');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnclosureScreen(enclosureNr: enclosureNr),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();
    _ensureStreams(session);

    return Scaffold(
      appBar: AppBar(title: const Text('Karte')),
      body: StreamBuilder(
        stream: _animalsStream,
        builder: (context, animalSnap) => StreamBuilder(
          stream: _appointmentsStream,
          builder: (context, appointmentSnap) {
            final statuses = computeEnclosureStatuses(
              animals: animalSnap.data?.docs.map(Animal.fromDoc) ?? const [],
              appointments:
                  appointmentSnap.data?.docs.map(Appointment.fromDoc) ??
                  const [],
              now: DateTime.now(),
            );

            return Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: kMapImageWidth / kMapImageHeight,
                        child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            onTapUp: (details) => _onTap(
                              details.localPosition,
                              constraints.biggest,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/images/map_raw.png',
                                  fit: BoxFit.fill,
                                ),
                                if (statuses.isNotEmpty)
                                  CustomPaint(
                                    painter: _EnclosureGlowPainter(
                                      statuses: statuses,
                                      pulse: _pulse,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const _Legend(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Zeichnet die Gehege-Polygone farbig und pulsierend ("leuchtend").
class _EnclosureGlowPainter extends CustomPainter {
  _EnclosureGlowPainter({required this.statuses, required this.pulse})
    : super(repaint: pulse);

  final Map<int, EnclosureStatus> statuses;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    // Hotspot-Koordinaten → Bildpixel → Widget-Pixel
    final scale = size.width / kMapImageWidth / kHotspotScale;
    final t = pulse.value;

    for (final hotspot in kHotspots) {
      final status = statuses[hotspot.enclosureNr];
      if (status == null) continue;

      final path = Path()
        ..addPolygon([for (final p in hotspot.points) p * scale], true);

      // Rot pulsiert stärker als Gelb; Grün leuchtet ruhig.
      final intensity = switch (status) {
        EnclosureStatus.due => 0.45 + 0.4 * t,
        EnclosureStatus.upcoming => 0.4 + 0.2 * t,
        EnclosureStatus.ok => 0.45,
      };

      canvas
        ..drawPath(
          path,
          Paint()
            ..color = status.color.withValues(alpha: intensity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        )
        ..drawPath(
          path,
          Paint()..color = status.color.withValues(alpha: intensity * 0.55),
        )
        ..drawPath(
          path,
          Paint()
            ..color = status.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_EnclosureGlowPainter old) => old.statuses != statuses;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final status in EnclosureStatus.values.reversed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: status.color, blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
