import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/reinigung_local.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';

class ReinigungFormScreen extends ConsumerStatefulWidget {
  final int? reinigungId; // null = neu
  final String? anlageId; // für neue Reinigung
  final String? betriebId; // für neue Reinigung

  const ReinigungFormScreen({
    super.key,
    this.reinigungId,
    this.anlageId,
    this.betriebId,
  });

  @override
  ConsumerState<ReinigungFormScreen> createState() =>
      _ReinigungFormScreenState();
}

class _ReinigungFormScreenState extends ConsumerState<ReinigungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  ReinigungLocal? _existing;

  // Zeiterfassung
  late DateTime _datum;
  late final _uhrzeitStartController = TextEditingController();
  late final _uhrzeitEndeController = TextEditingController();
  late final _notizenController = TextEditingController();

  // Checkliste - Anlagen-Checks
  bool _hatDurchlaufkuehler = false;
  bool _hatBuffetanstich = false;
  bool _hatKuehlkeller = false;
  bool _hatFasskuehler = false;

  // Checkliste - Service-Checks
  bool _begleitkuehlungKontrolliert = false;
  bool _installationAllgemeinKontrolliert = false;
  bool _aligalAnschluesseKontrolliert = false;
  bool _durchlaufkuehlerAusgeblasen = false;
  bool _wasserstandKontrolliert = false;
  bool _wasserGewechselt = false;
  bool _leitungWasserVorgespuelt = false;
  bool _leitungsreinigungReinigungsmittel = false;
  bool _foerderdruckKontrolliert = false;
  bool _zapfhahnZerlegtGereinigt = false;
  bool _zapfkopfZerlegtGereinigt = false;
  bool _servicekarteAusgefuellt = false;

  String _status = 'offen';

  bool get _isEdit => widget.reinigungId != null;

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _uhrzeitStartController.text = _formatTime(TimeOfDay.now());
    if (_isEdit) _loadReinigung();
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadReinigung() async {
    final r = await ReinigungRepository.getById(widget.reinigungId!);
    if (r == null || !mounted) return;

    setState(() {
      _existing = r;
      _datum = r.datum;
      _uhrzeitStartController.text = r.uhrzeitStart ?? '';
      _uhrzeitEndeController.text = r.uhrzeitEnde ?? '';
      _notizenController.text = r.notizen ?? '';
      _hatDurchlaufkuehler = r.hatDurchlaufkuehler;
      _hatBuffetanstich = r.hatBuffetanstich;
      _hatKuehlkeller = r.hatKuehlkeller;
      _hatFasskuehler = r.hatFasskuehler;
      _begleitkuehlungKontrolliert = r.begleitkuehlungKontrolliert;
      _installationAllgemeinKontrolliert =
          r.installationAllgemeinKontrolliert;
      _aligalAnschluesseKontrolliert = r.aligalAnschluesseKontrolliert;
      _durchlaufkuehlerAusgeblasen = r.durchlaufkuehlerAusgeblasen;
      _wasserstandKontrolliert = r.wasserstandKontrolliert;
      _wasserGewechselt = r.wasserGewechselt;
      _leitungWasserVorgespuelt = r.leitungWasserVorgespuelt;
      _leitungsreinigungReinigungsmittel =
          r.leitungsreinigungReinigungsmittel;
      _foerderdruckKontrolliert = r.foerderdruckKontrolliert;
      _zapfhahnZerlegtGereinigt = r.zapfhahnZerlegtGereinigt;
      _zapfkopfZerlegtGereinigt = r.zapfkopfZerlegtGereinigt;
      _servicekarteAusgefuellt = r.servicekarteAusgefuellt;
      _status = r.status;
    });
  }

  Future<void> _save({bool abschliessen = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final r = _existing ?? ReinigungLocal();

      if (!_isEdit) {
        r.anlageId = widget.anlageId!;
        r.betriebId = widget.betriebId!;
      }

      r.datum = _datum;
      r.uhrzeitStart = _emptyToNull(_uhrzeitStartController.text);
      r.uhrzeitEnde = _emptyToNull(_uhrzeitEndeController.text);
      r.notizen = _emptyToNull(_notizenController.text);

      r.hatDurchlaufkuehler = _hatDurchlaufkuehler;
      r.hatBuffetanstich = _hatBuffetanstich;
      r.hatKuehlkeller = _hatKuehlkeller;
      r.hatFasskuehler = _hatFasskuehler;
      r.begleitkuehlungKontrolliert = _begleitkuehlungKontrolliert;
      r.installationAllgemeinKontrolliert =
          _installationAllgemeinKontrolliert;
      r.aligalAnschluesseKontrolliert = _aligalAnschluesseKontrolliert;
      r.durchlaufkuehlerAusgeblasen = _durchlaufkuehlerAusgeblasen;
      r.wasserstandKontrolliert = _wasserstandKontrolliert;
      r.wasserGewechselt = _wasserGewechselt;
      r.leitungWasserVorgespuelt = _leitungWasserVorgespuelt;
      r.leitungsreinigungReinigungsmittel =
          _leitungsreinigungReinigungsmittel;
      r.foerderdruckKontrolliert = _foerderdruckKontrolliert;
      r.zapfhahnZerlegtGereinigt = _zapfhahnZerlegtGereinigt;
      r.zapfkopfZerlegtGereinigt = _zapfkopfZerlegtGereinigt;
      r.servicekarteAusgefuellt = _servicekarteAusgefuellt;

      if (abschliessen) {
        r.status = 'abgeschlossen';
        r.uhrzeitEnde ??= _formatTime(TimeOfDay.now());
      } else {
        r.status = _status;
      }

      await ReinigungRepository.save(r);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(abschliessen
                ? 'Reinigung abgeschlossen'
                : _isEdit
                    ? 'Reinigung aktualisiert'
                    : 'Reinigung gestartet'),
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
    _notizenController.dispose();
    super.dispose();
  }

  int get _checkedCount {
    var count = 0;
    if (_begleitkuehlungKontrolliert) count++;
    if (_installationAllgemeinKontrolliert) count++;
    if (_aligalAnschluesseKontrolliert) count++;
    if (_durchlaufkuehlerAusgeblasen) count++;
    if (_wasserstandKontrolliert) count++;
    if (_wasserGewechselt) count++;
    if (_leitungWasserVorgespuelt) count++;
    if (_leitungsreinigungReinigungsmittel) count++;
    if (_foerderdruckKontrolliert) count++;
    if (_zapfhahnZerlegtGereinigt) count++;
    if (_zapfkopfZerlegtGereinigt) count++;
    if (_servicekarteAusgefuellt) count++;
    if (_hatDurchlaufkuehler) count++;
    if (_hatBuffetanstich) count++;
    if (_hatKuehlkeller) count++;
    if (_hatFasskuehler) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Reinigung bearbeiten' : 'Neue Reinigung'),
        actions: [
          if (_isEdit || !_isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$_checkedCount/16',
                style: TextStyle(
                  color: _checkedCount == 16
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
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

            // === Anlagen-Checks ===
            _sectionTitle(context, 'Anlagen-Checks'),
            const SizedBox(height: 8),
            _checkTile('Durchlaufkühler vorhanden',
                _hatDurchlaufkuehler,
                (v) => setState(() => _hatDurchlaufkuehler = v)),
            _checkTile('Buffetanstich vorhanden', _hatBuffetanstich,
                (v) => setState(() => _hatBuffetanstich = v)),
            _checkTile('Kühlkeller vorhanden', _hatKuehlkeller,
                (v) => setState(() => _hatKuehlkeller = v)),
            _checkTile('Fasskühler vorhanden', _hatFasskuehler,
                (v) => setState(() => _hatFasskuehler = v)),
            const SizedBox(height: 16),

            // === Service-Checkliste ===
            _sectionTitle(context, 'Service-Checkliste (12 Punkte)'),
            const SizedBox(height: 8),
            _checkTile('Begleitkühlung kontrolliert',
                _begleitkuehlungKontrolliert,
                (v) => setState(() => _begleitkuehlungKontrolliert = v)),
            _checkTile('Installation allgemein kontrolliert',
                _installationAllgemeinKontrolliert,
                (v) => setState(
                    () => _installationAllgemeinKontrolliert = v)),
            _checkTile('Aligal-Anschlüsse kontrolliert',
                _aligalAnschluesseKontrolliert,
                (v) => setState(
                    () => _aligalAnschluesseKontrolliert = v)),
            _checkTile('Durchlaufkühler ausgeblasen',
                _durchlaufkuehlerAusgeblasen,
                (v) =>
                    setState(() => _durchlaufkuehlerAusgeblasen = v)),
            _checkTile('Wasserstand kontrolliert',
                _wasserstandKontrolliert,
                (v) => setState(() => _wasserstandKontrolliert = v)),
            _checkTile('Wasser gewechselt', _wasserGewechselt,
                (v) => setState(() => _wasserGewechselt = v)),
            _checkTile('Leitung mit Wasser vorgespült',
                _leitungWasserVorgespuelt,
                (v) => setState(() => _leitungWasserVorgespuelt = v)),
            _checkTile('Leitungsreinigung mit Reinigungsmittel',
                _leitungsreinigungReinigungsmittel,
                (v) => setState(
                    () => _leitungsreinigungReinigungsmittel = v)),
            _checkTile('Förderdruck kontrolliert',
                _foerderdruckKontrolliert,
                (v) => setState(() => _foerderdruckKontrolliert = v)),
            _checkTile('Zapfhahn zerlegt & gereinigt',
                _zapfhahnZerlegtGereinigt,
                (v) => setState(() => _zapfhahnZerlegtGereinigt = v)),
            _checkTile('Zapfkopf zerlegt & gereinigt',
                _zapfkopfZerlegtGereinigt,
                (v) => setState(() => _zapfkopfZerlegtGereinigt = v)),
            _checkTile('Servicekarte ausgefüllt',
                _servicekarteAusgefuellt,
                (v) => setState(() => _servicekarteAusgefuellt = v)),
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
                  : Text(_isEdit ? 'Speichern' : 'Reinigung starten'),
            ),
            const SizedBox(height: 12),
            if (_status == 'offen')
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _save(abschliessen: true),
                icon: const Icon(Icons.check_circle),
                label: const Text('Reinigung abschliessen'),
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
