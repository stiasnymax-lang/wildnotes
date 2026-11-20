import 'package:material_ui/material_ui.dart';

/// Bildschirmbreiten nach den Material-3-Richtlinien.
abstract final class Breakpoints {
  /// Ab hier: Tablet (Navigationsleiste an der Seite, zweispaltige Ansichten)
  static const double expanded = 840;

  /// Ab hier: Desktop (Navigationsleiste mit Beschriftung)
  static const double large = 1200;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isExpanded => screenWidth >= Breakpoints.expanded;
  bool get isLarge => screenWidth >= Breakpoints.large;
}

/// Begrenzt die Breite des Inhalts und zentriert ihn horizontal, damit
/// Listen und Formulare auf Tablets und am Desktop gut lesbar bleiben.
/// Auf dem Handy hat das keine Wirkung.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  /// Schmal für Login/Registrierung, breiter für Listen.
  const ContentWidth.narrow({super.key, required this.child}) : maxWidth = 480;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
