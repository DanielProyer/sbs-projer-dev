import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';

class BuchungFormScreen extends ConsumerStatefulWidget {
  const BuchungFormScreen({super.key});

  @override
  ConsumerState<BuchungFormScreen> createState() => _BuchungFormScreenState();
}

class _BuchungFormScreenState extends ConsumerState<BuchungFormScreen> {
  final _formKey = GlobalKey<FormState>();
  BuchungsVorlage? _selectedVorlage;
  bool _freiBuchen = false;
  bool _saving = false;

  DateTime _datum = DateTime.now();
  final _betragController = TextEditingController();
  final _beschreibungController = TextEditingController();
  final _belegnummerController = TextEditingController();
  final _sollKontoController = TextEditingController();
  final _habenKontoController = TextEditingController();
  final _mwstKontoController = TextEditingController();
  final _mwstSatzController = TextEditingController();
  String? _zahlungsweg;

  @override
  void dispose() {
    _betragController.dispose();
    _beschreibungController.dispose();
    _belegnummerController.dispose();
    _sollKontoController.dispose();
    _habenKontoController.dispose();
    _mwstKontoController.dispose();
    _mwstSatzController.dispose();
    super.dispose();
  }

  void _onVorlageSelected(BuchungsVorlage? vorlage) {
    setState(() {
      _selectedVorlage = vorlage;
      if (vorlage != null) {
        _sollKontoController.text = vorlage.sollKonto.toString();
        _habenKontoController.text = vorlage.habenKonto.toString();
        _mwstKontoController.text = vorlage.mwstKonto?.toString() ?? '';
        _mwstSatzController.text = vorlage.mwstSatz?.toString() ?? '0';
        _zahlungsweg = vorlage.zahlungsweg;
        _beschreibungController.text = vorlage.bezeichnung;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vorlagenAsync = ref.watch(manuelleBuchungsVorlagenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Neue Buchung')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vorlage oder Frei buchen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Buchungsart',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _freiBuchen = !_freiBuchen;
                            if (_freiBuchen) _selectedVorlage = null;
                          }),
                          child: Text(
                            _freiBuchen ? 'Vorlage wählen' : 'Frei buchen',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_freiBuchen)
                      vorlagenAsync.when(
                        data: (vorlagen) => DropdownButtonFormField<BuchungsVorlage>(
                          value: _selectedVorlage,
                          decoration: const InputDecoration(
                            labelText: 'Vorlage',
                          ),
                          isExpanded: true,
                          items: vorlagen.map((v) {
                            return DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.geschaeftsfallId} – ${v.bezeichnung}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onVorlageSelected,
                          validator: (v) =>
                              v == null ? 'Bitte Vorlage wählen' : null,
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Fehler: $e'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Datum
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Datum'),
                trailing: Text(
                  _formatDate(_datum),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _datum,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _datum = picked);
                },
              ),
            ),
            const SizedBox(height: 8),

            // Betrag + Beschreibung
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _betragController,
                      decoration: const InputDecoration(
                        labelText: 'Betrag Netto (CHF)',
                        prefixText: 'CHF ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Pflichtfeld';
                        if (double.tryParse(v) == null) return 'Ungültiger Betrag';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _beschreibungController,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Pflichtfeld' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _belegnummerController,
                      decoration: const InputDecoration(
                        labelText: 'Belegnummer (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Konten (bei Frei buchen oder nach Vorlage-Auswahl)
            if (_freiBuchen || _selectedVorlage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konten',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sollKontoController,
                              decoration: const InputDecoration(
                                labelText: 'Soll',
                              ),
                              keyboardType: TextInputType.number,
                              enabled: _freiBuchen,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Pflicht' : null,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.arrow_forward, size: 20),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _habenKontoController,
                              decoration: const InputDecoration(
                                labelText: 'Haben',
                              ),
                              keyboardType: TextInputType.number,
                              enabled: _freiBuchen,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Pflicht' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mwstKontoController,
                              decoration: const InputDecoration(
                                labelText: 'MwSt-Konto',
                              ),
                              keyboardType: TextInputType.number,
                              enabled: _freiBuchen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _mwstSatzController,
                              decoration: const InputDecoration(
                                labelText: 'MwSt-Satz (%)',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              enabled: _freiBuchen,
                            ),
                          ),
                        ],
                      ),
                      if (_freiBuchen) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _zahlungsweg,
                          decoration: const InputDecoration(
                            labelText: 'Zahlungsweg',
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'kasse', child: Text('Kasse')),
                            DropdownMenuItem(
                                value: 'bank', child: Text('Bank')),
                            DropdownMenuItem(
                                value: 'privat', child: Text('Privat')),
                          ],
                          onChanged: (v) => setState(() => _zahlungsweg = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // MwSt Vorschau
            if (_betragController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildMwstPreview(),
            ],

            const SizedBox(height: 24),

            // Speichern
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Buchung speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMwstPreview() {
    final netto = double.tryParse(_betragController.text) ?? 0;
    final satz = double.tryParse(_mwstSatzController.text) ?? 0;
    final mwst = netto * satz / 100;
    final brutto = netto + mwst;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Netto'),
                Text('${netto.toStringAsFixed(2)} CHF'),
              ],
            ),
            if (satz > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MwSt (${satz.toStringAsFixed(1)}%)'),
                  Text('${mwst.toStringAsFixed(2)} CHF'),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Brutto',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('${brutto.toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_freiBuchen && _selectedVorlage == null) return;

    setState(() => _saving = true);

    try {
      final netto = double.parse(_betragController.text);
      final mwstSatz =
          double.tryParse(_mwstSatzController.text) ?? 0;
      final mwstBetrag =
          (netto * mwstSatz / 100 * 100).roundToDouble() / 100;
      final brutto =
          (netto + mwstBetrag * 100).roundToDouble() / 100;

      final sollKonto = int.parse(_sollKontoController.text);
      final habenKonto = int.parse(_habenKontoController.text);
      final mwstKonto = _mwstKontoController.text.isNotEmpty
          ? int.tryParse(_mwstKontoController.text)
          : null;

      await BuchungRepository.create({
        'datum': _datum.toIso8601String().split('T').first,
        'belegnummer': _belegnummerController.text.isNotEmpty
            ? _belegnummerController.text
            : null,
        'vorlage_id': _selectedVorlage?.id,
        'soll_konto': sollKonto,
        'haben_konto': habenKonto,
        'mwst_konto': mwstKonto,
        'betrag_netto': netto,
        'mwst_satz': mwstSatz,
        'mwst_betrag': mwstBetrag,
        'betrag_brutto': netto + mwstBetrag,
        'beschreibung': _beschreibungController.text,
        'zahlungsweg': _zahlungsweg ?? _selectedVorlage?.zahlungsweg,
        'belegordner': _selectedVorlage?.belegordner,
        'beleg_typ': 'sonstiges',
        'geschaeftsjahr': _datum.year,
      });

      ref.invalidate(buchungenStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buchung gespeichert')),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
