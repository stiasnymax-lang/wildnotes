import 'package:material_ui/material_ui.dart';

/// Gemeinsames Formular für "Event anlegen" und "Event bearbeiten"
/// (früher activity_add_event.xml / activity_edit_event.xml).
class EventForm extends StatefulWidget {
  const EventForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName = '',
    this.initialInfo = '',
    this.initialDate = '',
  });

  final String submitLabel;
  final String initialName;
  final String initialInfo;
  final String initialDate;

  /// Speichert die Eingaben; liefert `true` bei Erfolg.
  final Future<bool> Function(String name, String info, String date) onSubmit;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _info = TextEditingController(text: widget.initialInfo);
  late final _date = TextEditingController(text: widget.initialDate);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _info.dispose();
    _date.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  /// Optionaler Datumsauswähler; das Datum wird als Text (TT.MM.JJJJ)
  /// gespeichert – genau wie bei der alten App, wo es frei eingegeben wurde.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    _date.text = '${two(picked.day)}.${two(picked.month)}.${picked.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    await widget.onSubmit(
      _name.text.trim(),
      _info.text.trim(),
      _date.text.trim(),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => _required(v, 'Bitte Namen eingeben'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _info,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Info'),
            validator: (v) => _required(v, 'Bitte Info eingeben'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _date,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: 'Date',
              suffixIcon: IconButton(
                tooltip: 'Datum auswählen',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: _pickDate,
              ),
            ),
            validator: (v) => _required(v, 'Bitte Datum eingeben'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
