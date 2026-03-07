import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';

class StoerungFormScreen extends ConsumerStatefulWidget {
  final int? stoerungId; // null = neu
  final String? anlageId; // für neue Störung
  final String? betriebId; // für neue Störung

  const StoerungFormScreen({
    super.key,
    this.stoerungId,
    this.anlageId,
    this.betriebId,
  });

  @override
  ConsumerState<StoerungFormScreen> createState() =>
      _StoerungFormScreenState();
}

class _StoerungFormScreenState extends ConsumerState<StoerungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  StoerungLocal? _existing;
  String? _stoerungsnummer;

  // Zeiterfassung
  late DateTime _datum;
  late final _uhrzeitStartController = TextEditingController();
  late final _uhrzeitEndeController = TextEditingController();

  // Störungsdetails
  late final _problemController = TextEditingController();
  late final _loesungController = TextEditingController();
  int? _stoerungBereich;
  bool _istPikettEinsatz = false;
  bool _istBergkunde = false;
  bool _istWochenende = false;

  // Notizen
  late final _notizenController = TextEditingController();

  String _status = 'offen';

  bool get _isEdit => widget.stoerungId != null;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _uhrzeitStartController.text = _formatTime(TimeOfDay.now());
    if (_isEdit) {
      _loadStoerung();
    } else {
      _generateNummer();
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _generateNummer() async {
    final nr = await StoerungRepository.generateStoerungsnummer();
    if (mounted) setState(() => _stoerungsnummer = nr);
  }

  Future<void> _loadStoerung() async {
    final s = await StoerungRepository.getById(widget.stoerungId!);
    if (s == null || !mounted) return;

    setState(() {
      _existing = s;
      _stoerungsnummer = s.stoerungsnummer;
      _datum = s.datum;
      _uhrzeitStartController.text = s.uhrzeitStart ?? '';
      _uhrzeitEndeController.text = s.uhrzeitEnde ?? '';
      _problemController.text = s.problemBeschreibung;
      _loesungController.text = s.loesungBeschreibung ?? '';
      _stoerungBereich = s.stoerungBereich;
      _istPikettEinsatz = s.istPikettEinsatz;
      _istBergkunde = s.istBergkunde;
      _istWochenende = s.istWochenende;
      _notizenController.text = s.notizen ?? '';
      _status = s.status;
    });
  }

  Future<void> _save({bool abschliessen = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final s = _existing ?? StoerungLocal();

      if (!_isEdit) {
        s.anlageId = widget.anlageId!;
        s.betriebId = widget.betriebId!;
        s.stoerungsnummer = _stoerungsnummer!;
      }

      s.datum = _datum;
      s.uhrzeitStart = _emptyToNull(_uhrzeitStartController.text);
      s.uhrzeitEnde = _emptyToNull(_uhrzeitEndeController.text);
      s.problemBeschreibung = _problemController.text.trim();
      s.loesungBeschreibung = _emptyToNull(_loesungController.text);
      s.stoerungBereich = _stoerungBereich;
      s.istPikettEinsatz = _istPikettEinsatz;
      s.istBergkunde = _istBergkunde;
      s.istWochenende = _istWochenende;
      s.notizen = _emptyToNull(_notizenController.text);

      if (abschliessen) {
        s.status = 'abgeschlossen';
        s.uhrzeitEnde ??= _formatTime(TimeOfDay.now());
      } else {
        s.status = _status;
      }

      await StoerungRepository.save(s);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(abschliessen
                ? 'Störung abgeschlossen'
                : _isEdit
                    ? 'Störung aktualisiert'
                    : 'Störung erfasst'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _emptyToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _uhrzeitStartController.dispose();
    _uhrzeitEndeController.dispose();
    _problemController.dispose();
    _loesungController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Störung bearbeiten' : 'Neue Störung'),
        actions: [
          if (_stoerungsnummer != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _stoerungsnummer!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Zeiterfassung ===
            _sectionTitle(context, 'Zeiterfassung'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _datum,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _datum = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Datum',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatDate(_datum)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _uhrzeitStartController,
                    decoration: const InputDecoration(
                      labelText: 'Start',
                      prefixIcon: Icon(Icons.play_arrow),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _uhrzeitEndeController,
                    decoration: const InputDecoration(
                      labelText: 'Ende',
                      prefixIcon: Icon(Icons.stop),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // === Störungsbereich ===
            _sectionTitle(context, 'Störungsbereich'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _stoerungBereich,
              decoration: const InputDecoration(
                labelText: 'Bereich',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 - Kühlung/Durchlaufkühler')),
                DropdownMenuItem(value: 2, child: Text('2 - Schankanlage/Zapfhahn')),
                DropdownMenuItem(value: 3, child: Text('3 - Kühlsystem')),
                DropdownMenuItem(value: 4, child: Text('4 - Druckgasanlage')),
                DropdownMenuItem(value: 5, child: Text('5 - Sonstiges')),
              ],
              onChanged: (v) => setState(() => _stoerungBereich = v),
            ),
            const SizedBox(height: 24),

            // === Problem & Lösung ===
            _sectionTitle(context, 'Problembeschreibung'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _problemController,
              decoration: const InputDecoration(
                labelText: 'Problem *',
                prefixIcon: Icon(Icons.error_outline),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Problembeschreibung erforderlich'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loesungController,
              decoration: const InputDecoration(
                labelText: 'Lösung',
                prefixIcon: Icon(Icons.check_circle_outline),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // === Optionen ===
            _sectionTitle(context, 'Optionen'),
            const SizedBox(height: 8),
            _checkTile('Pikett-Einsatz', _istPikettEinsatz,
                (v) => setState(() => _istPikettEinsatz = v)),
            _checkTile('Bergkunde', _istBergkunde,
                (v) => setState(() => _istBergkunde = v)),
            _checkTile('Wochenende/Feiertag', _istWochenende,
                (v) => setState(() => _istWochenende = v)),
            const SizedBox(height: 16),

            // === Notizen ===
            TextFormField(
              controller: _notizenController,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // === Aktionen ===
            FilledButton(
              onPressed: _isLoading ? null : () => _save(),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Störung erfassen'),
            ),
            const SizedBox(height: 12),
            if (_status == 'offen')
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _save(abschliessen: true),
                icon: const Icon(Icons.check_circle),
                label: const Text('Störung abschliessen'),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.success,
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
