import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../feature_animals/animal.dart';
import '../org/org_session.dart';
import '../org/org_widgets.dart';
import '../org/organization.dart';
import '../utils/messages.dart';
import 'appointment.dart';
import '../utils/responsive.dart';

/// Termin anlegen oder bearbeiten: Betreff, Beschreibung, Datum,
/// Uhrzeit von–bis sowie Teilnehmer (Personen und Tiere).
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    this.existing,
    this.initialDate,
    this.initialAnimalIds = const [],
  });

  /// Zu bearbeitender Termin (`null` = neuer Termin).
  final Appointment? existing;

  /// Vorausgewähltes Datum (z. B. der markierte Kalendertag).
  final DateTime? initialDate;

  /// Vorausgewählte Tiere (z. B. beim Anlegen aus der Tieransicht).
  final List<String> initialAnimalIds;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.existing?.subject);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );

  late DateTime _date;
  late TimeOfDay _from;
  late TimeOfDay _to;

  /// Ausgewählte Personen (UID → E-Mail) und Tiere (ID → Name).
  late final Map<String, String> _people;
  late final Set<String> _animalIds;

  bool _busy = false;

  // Streams einmalig anlegen (beim ersten build), damit nicht jede
  // Chip-Auswahl neue Firestore-Listener erzeugt.
  late final _animalsStream = OrgScope.of(context).animals.snapshots();
  late final _membersStream = OrgScope.of(context).members.snapshots();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _date = dateOnly(existing.start);
      _from = TimeOfDay.fromDateTime(existing.start);
      _to = TimeOfDay.fromDateTime(existing.end);
      _people = {...existing.participantEmails};
      _animalIds = {...existing.animalIds};
    } else {
      final now = DateTime.now();
      _date = dateOnly(widget.initialDate ?? now);
      // Nächste volle Stunde als Vorschlag
      final nextHour = (now.hour + 1).clamp(0, 22);
      _from = TimeOfDay(hour: nextHour, minute: 0);
      _to = TimeOfDay(hour: nextHour + 1, minute: 0);
      _people = {};
      _animalIds = {...widget.initialAnimalIds};
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime({required bool from}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        // Dauer beibehalten, wenn der Beginn verschoben wird
        final duration = _minutes(_to) - _minutes(_from);
        _from = picked;
        final end = (_minutes(picked) + duration).clamp(0, 23 * 60 + 59);
        _to = TimeOfDay(hour: end ~/ 60, minute: end % 60);
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save(List<Animal> allAnimals) async {
    if (!_formKey.currentState!.validate()) return;
    if (_minutes(_to) <= _minutes(_from)) {
      showMessage(context, 'Das Ende muss nach dem Beginn liegen.');
      return;
    }

    final session = OrgScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final names = {for (final a in allAnimals) a.id: a.name};
    final animalNames = {
      for (final id in _animalIds)
        id: names[id] ?? widget.existing?.animalNames[id] ?? '',
    };

    final data = Appointment.toMap(
      subject: _subject.text.trim(),
      description: _description.text.trim(),
      start: _combine(_from),
      end: _combine(_to),
      animalNames: animalNames,
      participantEmails: _people,
    );

    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await session.appointments.add({
          ...data,
          'done': false,
          'createdByEmail': session.member.email,
        });
        messenger.showMessage('Termin gespeichert!');
      } else {
        await session.appointments.doc(existing.id).update(data);
        messenger.showMessage('Termin aktualisiert!');
      }
      navigator.pop();
    } catch (e) {
      messenger.showMessage(
        'Fehler beim Speichern: ${errorText(e)}',
        long: true,
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = OrgScope.of(context);
    if (!session.isReady) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Neuer Termin' : 'Termin bearbeiten',
        ),
      ),
      body: ContentWidth(
        child: StreamBuilder(
          stream: _animalsStream,
          builder: (context, animalSnapshot) {
            final animals =
                animalSnapshot.data?.docs.map(Animal.fromDoc).toList() ?? [];
            animals.sort((a, b) => a.name.compareTo(b.name));

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _subject,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Betreff',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bitte Betreff eingeben'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Datum'),
                    subtitle: Text(
                      DateFormat('EEEE, d. MMMM y', 'de').format(_date),
                    ),
                    onTap: _pickDate,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Von'),
                          subtitle: Text(_from.format(context)),
                          onTap: () => _pickTime(from: true),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('Bis'),
                          subtitle: Text(_to.format(context)),
                          onTap: () => _pickTime(from: false),
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader('Teilnehmer: Personen'),
                  StreamBuilder(
                    stream: _membersStream,
                    builder: (context, snapshot) {
                      final members =
                          snapshot.data?.docs.map(Member.fromDoc).toList() ??
                          [];
                      members.sort((a, b) => a.email.compareTo(b.email));
                      // Ehemalige Mitglieder, die schon eingetragen sind,
                      // bleiben auswählbar.
                      final known = {for (final m in members) m.uid: m.email};
                      final options = {..._people, ...known};
                      if (options.isEmpty) {
                        return const ListTile(title: Text('Lade Mitglieder …'));
                      }
                      return _ChipWrap(
                        children: [
                          for (final entry in options.entries)
                            FilterChip(
                              avatar: const Icon(
                                Icons.person_outline,
                                size: 18,
                              ),
                              label: Text(entry.value),
                              selected: _people.containsKey(entry.key),
                              onSelected: (selected) => setState(() {
                                selected
                                    ? _people[entry.key] = entry.value
                                    : _people.remove(entry.key);
                              }),
                            ),
                        ],
                      );
                    },
                  ),
                  const SectionHeader('Teilnehmer: Tiere'),
                  if (animals.isEmpty)
                    const ListTile(title: Text('Noch keine Tiere vorhanden.'))
                  else
                    _ChipWrap(
                      children: [
                        for (final animal in animals)
                          FilterChip(
                            avatar: const Icon(Icons.pets, size: 18),
                            label: Text(
                              animal.enclosureNr == null
                                  ? animal.name
                                  : '${animal.name} (G${animal.enclosureNr})',
                            ),
                            selected: _animalIds.contains(animal.id),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? _animalIds.add(animal.id)
                                  : _animalIds.remove(animal.id);
                            }),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: FilledButton(
                      onPressed: _busy ? null : () => _save(animals),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 4, children: children),
    );
  }
}
