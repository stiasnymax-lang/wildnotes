import 'package:material_ui/material_ui.dart';

import 'appointment.dart';
import 'appointment_screen.dart';

/// Listeneintrag für einen Termin mit farbigem Status-Symbol.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    this.showDate = false,
  });

  final Appointment appointment;

  /// Datum statt nur Uhrzeit anzeigen (z. B. in der Tieransicht).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final status = appointment.statusAt(DateTime.now());
    final animals = appointment.animalNames.values.join(', ');

    return ListTile(
      leading: Icon(status.icon, color: status.color),
      title: Text(
        appointment.subject,
        style: appointment.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        [
          showDate ? appointment.dateTimeLabel : appointment.timeRange,
          if (animals.isNotEmpty) animals,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentScreen(appointmentId: appointment.id),
        ),
      ),
    );
  }
}
