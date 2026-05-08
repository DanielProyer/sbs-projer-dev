import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/data/models/lohn_abrechnung.dart';
import 'package:sbs_projer_app/data/repositories/lohn_repository.dart';
import 'package:sbs_projer_app/presentation/providers/lohn_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/services/pdf/lohnausweis_pdf_service.dart';
import 'package:printing/printing.dart';

class LohnlaufScreen extends ConsumerStatefulWidget {
  const LohnlaufScreen({super.key});

  @override
  ConsumerState<LohnlaufScreen> createState() => _LohnlaufScreenState();
}

class _LohnlaufScreenState extends ConsumerState<LohnlaufScreen> {
  late int _jahr;
  bool _buching = false;

  @override
  void initState() {
    super.initState();
    _jahr = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final einstAsync = ref.watch(lohnEinstellungenProvider(_jahr));
    final abrAsync = ref.watch(lohnAbrechnungenProvider(_jahr));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lohnbuchhaltung'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _jahr,
            onSelected: (j) => setState(() => _jahr = j),
            itemBuilder: (ctx) {
              final now = DateTime.now().year;
              return [
                for (int y = now + 1; y >= now - 2; y--)
                  PopupMenuItem(value: y, child: Text('$y')),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_jahr',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: einstAsync.valueOrNull != null
          ? FloatingActionButton.extended(
              onPressed: _buching ? null : () => _neuerLohnlauf(einstAsync.value!),
              icon: const Icon(Icons.add),
              label: const Text('Neuer Lohnlauf'),
            )
          : null,
      body: einstAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (einst) {
          if (einst == null) return _buildNoSettings();
          return abrAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (abrechnungen) => _buildContent(einst, abrechnungen),
          );
        },
      ),
    );
  }

  Widget _buildNoSettings() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Keine Lohn-Einstellungen für $_jahr',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bitte zuerst die Versicherungs-Sätze und Personaldaten erfassen.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/buchhaltung/lohn/einstellungen'),
              icon: const Icon(Icons.settings),
              label: const Text('Einstellungen öffnen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      LohnEinstellungen einst, List<LohnAbrechnung> abrechnungen) {
    double totalBrutto = 0;
    double totalNetto = 0;
    for (final a in abrechnungen) {
      totalBrutto += a.bruttolohn;
      totalNetto += a.nettolohn;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Zusammenfassung
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Brutto $_jahr',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text('${totalBrutto.toStringAsFixed(2)} CHF',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Netto $_jahr',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text('${totalNetto.toStringAsFixed(2)} CHF',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${abrechnungen.length} Auszahlungen'),
                    TextButton(
                      onPressed: () =>
                          context.push('/buchhaltung/lohn/einstellungen'),
                      child: const Text('Einstellungen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Lohnausweis
        if (abrechnungen.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () => _generateLohnausweis(einst),
              icon: const Icon(Icons.description),
              label: const Text('Lohnausweis generieren'),
            ),
          ),

        // Abrechnungen-Liste
        Text('Auszahlungen $_jahr',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        if (abrechnungen.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Noch keine Lohnauszahlungen in $_jahr',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          ...abrechnungen.map((abr) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success.withAlpha(25),
                    radius: 18,
                    child: Icon(Icons.payments, size: 18,
                        color: AppColors.success),
                  ),
                  title: Text(
                    '${abr.bruttolohn.toStringAsFixed(2)} CHF brutto',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${abr.datumFormatiert}  ·  Netto: ${abr.nettolohn.toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'detail') {
                        _showDetail(abr);
                      } else if (v == 'loeschen') {
                        _loeschen(abr);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'detail',
                          child: Text('Detail anzeigen')),
                      const PopupMenuItem(
                          value: 'loeschen',
                          child: Text('Stornieren',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                  onTap: () => _showDetail(abr),
                ),
              )),
      ],
    );
  }

  void _neuerLohnlauf(LohnEinstellungen einst) {
    final bruttolohnCtrl = TextEditingController(
      text: ref
              .read(lohnAbrechnungenProvider(_jahr))
              .valueOrNull
              ?.isNotEmpty ==
          true
          ? ref
              .read(lohnAbrechnungenProvider(_jahr))
              .value!
              .first
              .bruttolohn
              .toStringAsFixed(2)
          : '',
    );
    DateTime selectedDatum = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LohnlaufFormSheet(
        einst: einst,
        bruttolohnCtrl: bruttolohnCtrl,
        initialDatum: selectedDatum,
        buching: _buching,
        onBuchen: (abr) {
          Navigator.pop(ctx);
          _buchen(abr);
        },
      ),
    );
  }

  Future<void> _buchen(LohnAbrechnung abr) async {
    setState(() => _buching = true);
    try {
      await LohnRepository.lohnlaufBuchen(abr);
      ref.invalidate(lohnAbrechnungenProvider(_jahr));
      ref.invalidate(buchungenStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Lohn vom ${abr.datumFormatiert} gebucht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _buching = false);
    }
  }

  Future<void> _loeschen(LohnAbrechnung abr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lohnlauf stornieren?'),
        content: Text(
            'Lohnlauf vom ${abr.datumFormatiert} '
            '(${abr.bruttolohn.toStringAsFixed(2)} CHF) und alle '
            'zugehörigen Buchungen werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await LohnRepository.abrechnungLoeschen(abr.id);
      ref.invalidate(lohnAbrechnungenProvider(_jahr));
      ref.invalidate(buchungenStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lohnlauf vom ${abr.datumFormatiert} storniert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _showDetail(LohnAbrechnung abr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Text(
                'Lohnabrechnung ${abr.datumFormatiert}',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Divider(),
              _detailRow('Bruttolohn', abr.bruttolohn),
              const SizedBox(height: 8),
              Text('AN-Abzüge',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.error)),
              if (abr.ahvIvEoAn > 0) _detailRow('  AHV/IV/EO AN', -abr.ahvIvEoAn),
              if (abr.alvAn > 0) _detailRow('  ALV AN', -abr.alvAn),
              if (abr.nbuAn > 0) _detailRow('  NBU AN', -abr.nbuAn),
              if (abr.bvgAn > 0) _detailRow('  BVG AN', -abr.bvgAn),
              if (abr.ktgAn > 0) _detailRow('  KTG AN', -abr.ktgAn),
              const Divider(),
              _detailRow('Nettolohn', abr.nettolohn, bold: true),
              const SizedBox(height: 12),
              Text('AG-Beiträge',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.info)),
              if (abr.ahvIvEoAg > 0) _detailRow('  AHV/IV/EO AG', abr.ahvIvEoAg),
              if (abr.alvAg > 0) _detailRow('  ALV AG', abr.alvAg),
              if (abr.buAg > 0) _detailRow('  BU/UVG AG', abr.buAg),
              if (abr.fakAg > 0) _detailRow('  FAK AG', abr.fakAg),
              if (abr.bvgAg > 0) _detailRow('  BVG AG', abr.bvgAg),
              if (abr.ktgAg > 0) _detailRow('  KTG AG', abr.ktgAg),
              const Divider(),
              _detailRow('Total AG-Beiträge', abr.totalAgBeitraege),
              _detailRow('Lohnkosten total',
                  abr.bruttolohn + abr.totalAgBeitraege,
                  bold: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateLohnausweis(LohnEinstellungen einst) async {
    try {
      final totale = await LohnRepository.jahresTotale(_jahr);
      final pdf =
          await LohnausweisPdfService.generate(einst, totale, _jahr);
      if (mounted) {
        await Printing.layoutPdf(onLayout: (_) => pdf);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  static Widget _detailRow(String label, double betrag, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              )),
          Text(
            '${betrag >= 0 ? '' : '–'} ${betrag.abs().toStringAsFixed(2)} CHF',
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: betrag < 0 ? AppColors.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom-Sheet für neuen Lohnlauf ──

class _LohnlaufFormSheet extends StatefulWidget {
  final LohnEinstellungen einst;
  final TextEditingController bruttolohnCtrl;
  final DateTime initialDatum;
  final bool buching;
  final void Function(LohnAbrechnung) onBuchen;

  const _LohnlaufFormSheet({
    required this.einst,
    required this.bruttolohnCtrl,
    required this.initialDatum,
    required this.buching,
    required this.onBuchen,
  });

  @override
  State<_LohnlaufFormSheet> createState() => _LohnlaufFormSheetState();
}

class _LohnlaufFormSheetState extends State<_LohnlaufFormSheet> {
  late DateTime _datum;
  LohnAbrechnung? _abr;

  @override
  void initState() {
    super.initState();
    _datum = widget.initialDatum;
    _berechnen();
    widget.bruttolohnCtrl.addListener(_berechnen);
  }

  @override
  void dispose() {
    widget.bruttolohnCtrl.removeListener(_berechnen);
    super.dispose();
  }

  void _berechnen() {
    final brutto = double.tryParse(widget.bruttolohnCtrl.text) ?? 0;
    if (brutto <= 0) {
      setState(() => _abr = null);
      return;
    }
    setState(() {
      _abr = LohnRepository.berechnen(widget.einst, _datum, brutto);
    });
  }

  Future<void> _pickDatum() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(_datum.year, 1, 1),
      lastDate: DateTime(_datum.year, 12, 31),
    );
    if (picked != null) {
      setState(() => _datum = picked);
      _berechnen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final datumStr =
        '${_datum.day.toString().padLeft(2, '0')}.${_datum.month.toString().padLeft(2, '0')}.${_datum.year}';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text('Neuer Lohnlauf',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Datum
            InkWell(
              onTap: _pickDatum,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Auszahlungsdatum',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(datumStr),
              ),
            ),
            const SizedBox(height: 12),

            // Bruttolohn
            TextFormField(
              controller: widget.bruttolohnCtrl,
              decoration: const InputDecoration(
                labelText: 'Bruttolohn (CHF)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixText: 'CHF ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),

            if (_abr != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              _LohnlaufScreenState._detailRow('Bruttolohn', _abr!.bruttolohn),
              const SizedBox(height: 8),
              Text('AN-Abzüge',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.error)),
              if (_abr!.ahvIvEoAn > 0)
                _LohnlaufScreenState._detailRow('  AHV/IV/EO', -_abr!.ahvIvEoAn),
              if (_abr!.alvAn > 0)
                _LohnlaufScreenState._detailRow('  ALV', -_abr!.alvAn),
              if (_abr!.nbuAn > 0)
                _LohnlaufScreenState._detailRow('  NBU', -_abr!.nbuAn),
              if (_abr!.bvgAn > 0)
                _LohnlaufScreenState._detailRow('  BVG', -_abr!.bvgAn),
              if (_abr!.ktgAn > 0)
                _LohnlaufScreenState._detailRow('  KTG', -_abr!.ktgAn),
              const Divider(),
              _LohnlaufScreenState._detailRow('Nettolohn', _abr!.nettolohn,
                  bold: true),
              const SizedBox(height: 16),
              Text('AG-Beiträge (zusätzlich)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.info)),
              if (_abr!.ahvIvEoAg > 0)
                _LohnlaufScreenState._detailRow('  AHV/IV/EO AG', _abr!.ahvIvEoAg),
              if (_abr!.alvAg > 0)
                _LohnlaufScreenState._detailRow('  ALV AG', _abr!.alvAg),
              if (_abr!.buAg > 0)
                _LohnlaufScreenState._detailRow('  BU/UVG AG', _abr!.buAg),
              if (_abr!.fakAg > 0)
                _LohnlaufScreenState._detailRow('  FAK AG', _abr!.fakAg),
              if (_abr!.bvgAg > 0)
                _LohnlaufScreenState._detailRow('  BVG AG', _abr!.bvgAg),
              if (_abr!.ktgAg > 0)
                _LohnlaufScreenState._detailRow('  KTG AG', _abr!.ktgAg),
              const Divider(),
              _LohnlaufScreenState._detailRow(
                  'Lohnkosten total',
                  _abr!.bruttolohn + _abr!.totalAgBeitraege,
                  bold: true),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: widget.buching
                    ? null
                    : () => widget.onBuchen(_abr!),
                icon: const Icon(Icons.check),
                label: const Text('Lohnlauf buchen'),
              ),
            ],

            if (_abr == null && widget.bruttolohnCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Bitte gültigen Bruttolohn eingeben.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
