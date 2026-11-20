import 'package:material_ui/material_ui.dart';

/// Gemeinsames Formular für "Tier anlegen" und "Tier bearbeiten"
/// (früher activity_add_animal.xml / activity_edit_animal.xml).
class AnimalForm extends StatefulWidget {
  const AnimalForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName = '',
    this.initialInfo = '',
    this.initialEnclosureNr,
    this.clearAfterSubmit = false,
  });

  final String submitLabel;
  final String initialName;
  final String initialInfo;
  final int? initialEnclosureNr;

  /// Felder nach erfolgreichem Speichern leeren (für "Tier anlegen").
  final bool clearAfterSubmit;

  /// Speichert die Eingaben; liefert `true` bei Erfolg.
  final Future<bool> Function(String name, String info, int enclosureNr)
  onSubmit;

  @override
  State<AnimalForm> createState() => _AnimalFormState();
}

class _AnimalFormState extends State<AnimalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _info = TextEditingController(text: widget.initialInfo);
  late final _enclosure = TextEditingController(
    text: widget.initialEnclosureNr?.toString() ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _info.dispose();
    _enclosure.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _validateEnclosure(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Bitte Gehege-Nr. eingeben';
    if (int.tryParse(text) == null) return 'Bitte eine Zahl eingeben';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final ok = await widget.onSubmit(
      _name.text.trim(),
      _info.text.trim(),
      int.parse(_enclosure.text.trim()),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok && widget.clearAfterSubmit) {
      _name.clear();
      _info.clear();
      _enclosure.clear();
    }
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
            validator: (v) => _required(v, 'Bitte Name eingeben'),
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
            controller: _enclosure,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Enclosure'),
            validator: _validateEnclosure,
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
