import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/repositories/lager_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MontageFormScreen extends ConsumerStatefulWidget {
  final String? montageId; // null = neu
  final String? anlageId;
  final String? betriebId;

  const MontageFormScreen({
    super.key,
    this.montageId,
    this.anlageId,
    this.betriebId,
  });

  @override
  ConsumerState<MontageFormScreen> createState() => _MontageFormScreenState();
}

class _MontageFormScreenState extends ConsumerState<MontageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  MontageLocal? _existing;

  // Typ
  String _montageTyp = 'neu_installation';

  // Betrieb
  String? _betriebId;

  // Datum & Stunden
  late DateTime _datum;
  late final _stundenController = TextEditingController();

  // Details
  late final _beschreibungController = TextEditingController();
  late final _notizenController = TextEditingController();

  // Material
  List<Lager> _lagerItems = [];
  final List<String?> _materialIds = List.filled(5, null);
  final List<double> _materialMengen = List.filled(5, 1);

  // Stundensatz (80 CHF/h default)
  double _stundensatz = 80.0;

  bool get _isEdit => widget.montageId != null;

  /// Betrieb-Feld deaktiviert bei Spesen und Sonstiges
  bool get _betriebDisabled =>
      _montageTyp == 'spesen' || _montageTyp == 'sonstiges';

  @override
  void initState() {
    super.initState();
    _datum = DateTime.now();
    _betriebId = widget.betriebId;
    _loadLager();
    _loadStundensatz();
    if (_isEdit) {
      _loadMontage();
    }
  }

  Future<void> _loadLager() async {
    try {
      final items = await LagerRepository.getAll();
      if (mounted) setState(() => _lagerItems = items);
    } catch (_) {}
  }

  Future<void> _loadStundensatz() async {
    try {
      final preisRows = await SupabaseService.client
          .from('preise')
          .select('montage_stundensatz')
          .lte('gueltig_ab', _datum.toIso8601String().substring(0, 10))
          .order('gueltig_ab', ascending: false)
          .limit(1);
      if (preisRows.isNotEmpty &&
          preisRows.first['montage_stundensatz'] != null) {
        final satz = double.tryParse(
            preisRows.first['montage_stundensatz'].toString());
        if (satz != null && mounted) setState(() => _stundensatz = satz);
      }
    } catch (_) {
      // Fallback: 80 CHF/h bleibt
    }
  }

  Future<void> _loadMontage() async {
    final m = await MontageRepository.getById(widget.montageId!);
    if (m == null || !mounted) return;

    setState(() {
      _existing = m;
      _montageTyp = m.montageTyp;
      _betriebId = m.betriebId;
      _datum = m.datum;
      _stundenController.text =
          m.dauerStunden != null ? m.dauerStunden.toString() : '';
      _beschreibungController.text = m.beschreibung;
      _notizenController.text = m.notizen ?? '';
      if (m.stundensatz != null) _stundensatz = m.stundensatz!;

      // Material
      _materialIds[0] = m.material1Id;
      _materialIds[1] = m.material2Id;
      _materialIds[2] = m.material3Id;
      _materialIds[3] = m.material4Id;
      _materialIds[4] = m.material5Id;
      _materialMengen[0] = m.material1Menge ?? 1;
      _materialMengen[1] = m.material2Menge ?? 1;
      _materialMengen[2] = m.material3Menge ?? 1;
      _materialMengen[3] = m.material4Menge ?? 1;
      _materialMengen[4] = m.material5Menge ?? 1;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final m = _existing ?? MontageLocal();

      if (!_isEdit) {
        m.anlageId = widget.anlageId;
      }

      m.montageTyp = _montageTyp;
      m.betriebId = _betriebDisabled ? null : _betriebId;
      m.datum = _datum;
      m.beschreibung = _beschreibungController.text.trim();
      m.notizen = _emptyToNull(_notizenController.text);
      m.status = 'abgeschlossen';

      // Stunden & Kosten
      final stunden = double.tryParse(_stundenController.text.trim());
      m.stundensatz = _stundensatz;
      m.dauerStunden = stunden;
      m.kostenArbeit = stunden != null ? _stundensatz * stunden : null;

      // Material-Felder
      m.material1Id = _materialIds[0];
      m.material1Menge = _materialIds[0] != null ? _materialMengen[0] : null;
      m.material2Id = _materialIds[1];
      m.material2Menge = _materialIds[1] != null ? _materialMengen[1] : null;
      m.material3Id = _materialIds[2];
      m.material3Menge = _materialIds[2] != null ? _materialMengen[2] : null;
      m.material4Id = _materialIds[3];
      m.material4Menge = _materialIds[3] != null ? _materialMengen[3] : null;
      m.material5Id = _materialIds[4];
      m.material5Menge = _materialIds[4] != null ? _materialMengen[4] : null;

      await MontageRepository.save(m);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEdit ? 'Montage aktualisiert' : 'Montage erfasst'),
          ),
        );
        if (kIsWeb) ref.invalidate(montagenStreamProvider);
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
    _stundenController.dispose();
    _beschreibungController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final betriebe = ref.watch(betriebeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Montage bearbeiten' : 'Neue Montage'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Montage-Typ ===
            _sectionTitle(context, 'Montage-Typ'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _montageTyp,
              decoration: const InputDecoration(
                labelText: 'Typ *',
                prefixIcon: Icon(Icons.build),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'neu_installation', child: Text('Neu-Installation')),
                DropdownMenuItem(value: 'umbau', child: Text('Umbau')),
                DropdownMenuItem(
                    value: 'erweiterung', child: Text('Erweiterung')),
                DropdownMenuItem(value: 'abbau', child: Text('Abbau')),
                DropdownMenuItem(
                    value: 'heigenie_service',
                    child: Text('HeiGenie Service')),
                DropdownMenuItem(
                    value: 'anlass_mitarbeit',
                    child: Text('Anlass-Mitarbeit')),
                DropdownMenuItem(
                    value: 'mehraufwand', child: Text('Mehraufwand')),
                DropdownMenuItem(value: 'spesen', child: Text('Spesen')),
                DropdownMenuItem(
                    value: 'sonstiges', child: Text('Sonstiges')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _montageTyp = v;
                    // Betrieb zurücksetzen wenn deaktiviert
                    if (_betriebDisabled) _betriebId = null;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // === Betrieb ===
            _sectionTitle(context, 'Betrieb'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _betriebId,
              decoration: InputDecoration(
                labelText: _betriebDisabled
                    ? 'Betrieb (nicht relevant)'
                    : 'Betrieb',
                prefixIcon: const Icon(Icons.store),
              ),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('— Kein Betrieb —')),
                ...betriebe
                    .where((b) => b.serverId != null)
                    .map((b) => DropdownMenuItem(
                          value: b.serverId!,
                          child: Text(b.name,
                              overflow: TextOverflow.ellipsis),
                        )),
              ],
              onChanged: _betriebDisabled
                  ? null
                  : (v) => setState(() => _betriebId = v),
            ),
            const SizedBox(height: 24),

            // === Datum & Stunden ===
            _sectionTitle(context, 'Datum & Aufwand'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _datum,
                        firstDate: DateTime(2024),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stundenController,
                    decoration: const InputDecoration(
                      labelText: 'Stunden',
                      prefixIcon: Icon(Icons.timer),
                      suffixText: 'h',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildKostenPreview(),
            const SizedBox(height: 24),

            // === Beschreibung ===
            _sectionTitle(context, 'Beschreibung'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _beschreibungController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung *',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Beschreibung erforderlich'
                  : null,
            ),
            const SizedBox(height: 24),

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

            // === Material ===
            _sectionTitle(context, 'Verwendetes Material'),
            const SizedBox(height: 8),
            ..._buildMaterialSlots(),
            const SizedBox(height: 24),

            // === Speichern ===
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Speichern' : 'Montage erfassen'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMaterialSlots() {
    final slots = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (i > 0 && _materialIds[i - 1] == null && _materialIds[i] == null) {
        break;
      }
      slots.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _materialIds[i],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Material ${i + 1}',
                  isDense: true,
                  prefixIcon: const Icon(Icons.inventory_2, size: 20),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  ..._lagerItems.map((l) => DropdownMenuItem(
                        value: l.id,
                        child:
                            Text(l.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() {
                  _materialIds[i] = v;
                  if (v == null) _materialMengen[i] = 1;
                }),
              ),
            ),
            if (_materialIds[i] != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _materialMengen[i].toStringAsFixed(0),
                  decoration: const InputDecoration(
                    labelText: 'Anz.',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    _materialMengen[i] = double.tryParse(v) ?? 1;
                  },
                ),
              ),
            ],
          ],
        ),
      ));
    }
    return slots;
  }

  Widget _buildKostenPreview() {
    final stunden = double.tryParse(_stundenController.text.trim());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: stunden == null
          ? const Text(
              'Stunden eingeben für Kostenvorschau',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : Column(
              children: [
                _preisRow('Stundensatz',
                    '${_stundensatz.toStringAsFixed(2)} CHF/h'),
                _preisRow('Stunden', '${stunden.toStringAsFixed(2)} h'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Arbeitskosten',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                        '${(_stundensatz * stunden).toStringAsFixed(2)} CHF',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _preisRow(String label, String betrag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(betrag, style: const TextStyle(fontSize: 13)),
        ],
      ),
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
