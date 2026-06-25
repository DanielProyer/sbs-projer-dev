import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_resolver.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/services/pdf/mahnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';

class RechnungDetailScreen extends ConsumerWidget {
  final String rechnungId;

  const RechnungDetailScreen({super.key, required this.rechnungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Rechnung?>(
      future: RechnungRepository.getById(rechnungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rechnung = snapshot.data;
        if (rechnung == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Rechnung nicht gefunden')),
          );
        }

        return _RechnungDetailContent(rechnung: rechnung);
      },
    );
  }
}

class _RechnungDetailContent extends ConsumerStatefulWidget {
  final Rechnung rechnung;

  const _RechnungDetailContent({required this.rechnung});

  @override
  ConsumerState<_RechnungDetailContent> createState() =>
      _RechnungDetailContentState();
}

class _RechnungDetailContentState
    extends ConsumerState<_RechnungDetailContent> {
  late Rechnung _rechnung;
  List<RechnungsPosition>? _positionen;
  String? _betriebName;
  String? _betriebId;
  bool _loadingPositionen = true;

  @override
  void initState() {
    super.initState();
    _rechnung = widget.rechnung;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final positionen =
          await RechnungsPositionRepository.getByRechnung(_rechnung.id);

      String? betriebName;
      if (_rechnung.betriebId != null) {
        final betrieb =
            await BetriebRepository.getByServerId(_rechnung.betriebId!);
        betriebName = betrieb?.name;
        _betriebId = betrieb?.routeId;
      }

      if (mounted) {
        setState(() {
          _positionen = positionen;
          _betriebName = betriebName;
          _loadingPositionen = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPositionen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_rechnung.rechnungsnummer ?? 'Rechnung'),
        actions: [
          if (_rechnung.rechnungstyp == 'jahresrechnung')
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Reinigungsprotokolle',
              onPressed: () => _showProtokollePdf(context),
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF drucken / teilen',
            onPressed: () => _showPdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          _SectionCard(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  _StatusChip(status: _rechnung.zahlungsstatus),
                ],
              ),
              if (_rechnung.versandart != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                    'Versandart', _versandartLabel(_rechnung.versandart!)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Betrieb
          if (_betriebName != null)
            _SectionCard(
              children: [
                InkWell(
                  onTap: _betriebId != null
                      ? () => context.push('/betriebe/$_betriebId')
                      : null,
                  child: Row(
                    children: [
                      const Icon(Icons.store,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_betriebName!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (_betriebId != null)
                        const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Rechnungsadresse (pro Rechnung anpassbar)
          _rechnungsadresseCard(),
          const SizedBox(height: 12),

          // Rechnungsinfo
          _SectionCard(
            children: [
              const Text('Rechnungsdetails',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              _InfoRow(
                  'Rechnungs-Nr.', _rechnung.rechnungsnummer ?? 'Entwurf'),
              _InfoRow('Datum', _formatDate(_rechnung.rechnungsdatum)),
              _InfoRow('Fällig bis', _formatDate(_rechnung.faelligkeitsdatum)),
            ],
          ),
          const SizedBox(height: 12),

          // Positionen
          _SectionCard(
            children: [
              const Text('Positionen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              if (_loadingPositionen)
                const Center(child: CircularProgressIndicator())
              else if (_positionen != null && _positionen!.isNotEmpty)
                ..._positionen!.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('${p.position}.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ),
                          Expanded(
                            child: Text(p.beschreibung,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text('CHF ${p.betragNetto.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ))
              else
                Text('Keine Positionen',
                    style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // Summen
          _SectionCard(
            children: [
              _SummenRow('Netto', _rechnung.betragNetto),
              _SummenRow(
                'MwSt ${_rechnung.betragNetto > 0 ? (_rechnung.mwstBetrag / _rechnung.betragNetto * 100).toStringAsFixed(1) : '8.1'}%',
                _rechnung.mwstBetrag),
              const Divider(),
              _SummenRow(
                'Total CHF',
                (_rechnung.betragBrutto * 20).roundToDouble() / 20,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Zahlungsinfo
          _SectionCard(
            children: [
              const Text('Zahlungsinformationen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              const _InfoRow('Zahlungsfrist', '30 Tage netto'),
              const _InfoRow('Bank', 'Graubündner Kantonalbank'),
              const _InfoRow('IBAN', 'CH66 0077 4010 3765 5060 1'),
            ],
          ),
          const SizedBox(height: 16),

          // Mahnverlauf
          if (_hasMahnungen()) ...[
            _SectionCard(
              children: [
                const Text('Mahnverlauf',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                if (_rechnung.erinnerungAm != null)
                  _MahnungPdfRow(
                    label: 'Zahlungserinnerung',
                    datum: _rechnung.erinnerungAm!,
                    onTap: () => _showMahnungPdf(context, 0),
                  ),
                if (_rechnung.mahnung1Am != null)
                  _MahnungPdfRow(
                    label: '1. Mahnung',
                    datum: _rechnung.mahnung1Am!,
                    onTap: () => _showMahnungPdf(context, 1),
                  ),
                if (_rechnung.mahnung2Am != null)
                  _MahnungPdfRow(
                    label: '2. Mahnung',
                    datum: _rechnung.mahnung2Am!,
                    onTap: () => _showMahnungPdf(context, 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Aktionen
          if (_rechnung.zahlungsstatus != 'bezahlt' && _rechnung.zahlungsstatus != 'abgeschrieben')
            FilledButton.icon(
              onPressed: () => _markAsBezahlt(context),
              icon: const Icon(Icons.check),
              label: const Text('Als bezahlt markieren'),
            ),
        ],
      ),
    );
  }

  // ─── Rechnungsadresse (pro Rechnung, Override/Snapshot) ───

  Widget _rechnungsadresseCard() {
    final override = _rechnung.rechnungsadresse;
    final hatOverride = override != null && override.isNotEmpty;
    return _SectionCard(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Rechnungsadresse',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            if (hatOverride)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('abweichend',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hatOverride
              ? _adresseText(override)
              : 'Standard: Rechnungsadresse des Betriebs.',
          style: TextStyle(
              fontSize: 13,
              color: hatOverride ? null : AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_location_alt, size: 18),
              label: const Text('Adresse anpassen'),
              onPressed: _editRechnungsadresse,
            ),
            if (hatOverride) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetRechnungsadresse,
                child: const Text('Zurücksetzen'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _adresseText(Map<String, dynamic> a) {
    String join(List<String> keys, String sep) => keys
        .map((k) => (a[k] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .join(sep);
    final lines = <String>[
      join(['firma'], ' '),
      join(['vorname', 'nachname'], ' '),
      join(['strasse', 'nr'], ' '),
      join(['plz', 'ort'], ' '),
      join(['email'], ' '),
    ].where((s) => s.isNotEmpty).toList();
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  Future<void> _editRechnungsadresse() async {
    // Vorbefüllung: Override > Betriebs-Rechnungsadresse > leer.
    Map<String, dynamic> init = _rechnung.rechnungsadresse ?? {};
    if (init.isEmpty && _rechnung.betriebId != null) {
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
          _rechnung.betriebId!);
      if (raLocal != null) {
        init = {
          'firma': raLocal.firma,
          'vorname': raLocal.vorname,
          'nachname': raLocal.nachname,
          'strasse': raLocal.strasse,
          'nr': raLocal.nr,
          'plz': raLocal.plz,
          'ort': raLocal.ort,
          'email': raLocal.email,
        };
      }
    }
    if (!mounted) return;
    const felder = [
      'firma', 'vorname', 'nachname', 'strasse', 'nr', 'plz', 'ort', 'email'
    ];
    final ctrls = {
      for (final k in felder)
        k: TextEditingController(text: (init[k] as String?) ?? ''),
    };
    final gespeichert = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnungsadresse anpassen'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _adrFeld(ctrls['firma']!, 'Firma'),
                Row(children: [
                  Expanded(child: _adrFeld(ctrls['vorname']!, 'Vorname')),
                  const SizedBox(width: 8),
                  Expanded(child: _adrFeld(ctrls['nachname']!, 'Nachname')),
                ]),
                Row(children: [
                  Expanded(flex: 3, child: _adrFeld(ctrls['strasse']!, 'Strasse')),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: _adrFeld(ctrls['nr']!, 'Nr.')),
                ]),
                Row(children: [
                  Expanded(flex: 1, child: _adrFeld(ctrls['plz']!, 'PLZ')),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: _adrFeld(ctrls['ort']!, 'Ort')),
                ]),
                _adrFeld(ctrls['email']!, 'E-Mail'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (gespeichert == true) {
      final map = <String, dynamic>{
        for (final e in ctrls.entries)
          e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      };
      try {
        await RechnungRepository.update(
            _rechnung.id, {'rechnungsadresse': map});
        await _reloadRechnung();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Rechnungsadresse für diese Rechnung gespeichert.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
        }
      }
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  Widget _adrFeld(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  Future<void> _resetRechnungsadresse() async {
    try {
      await RechnungRepository.update(_rechnung.id, {'rechnungsadresse': null});
      await _reloadRechnung();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Auf Betriebsadresse zurückgesetzt.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zurücksetzen fehlgeschlagen: $e')));
      }
    }
  }

  Future<void> _reloadRechnung() async {
    final r = await RechnungRepository.getById(_rechnung.id);
    if (r != null && mounted) setState(() => _rechnung = r);
  }

  Future<void> _showPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Betrieb + Rechnungsadresse laden
      final betrieb = _rechnung.betriebId != null
          ? await BetriebRepository.getByServerId(_rechnung.betriebId!)
          : null;

      BetriebRechnungsadresse? ra;
      if (_rechnung.betriebId != null) {
        final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
            _rechnung.betriebId!);
        if (raLocal != null) {
          ra = BetriebRechnungsadresse(
            id: raLocal.serverId ?? '',
            userId: raLocal.userId,
            betriebId: _rechnung.betriebId!,
            firma: raLocal.firma,
            vorname: raLocal.vorname,
            nachname: raLocal.nachname,
            strasse: raLocal.strasse,
            nr: raLocal.nr,
            plz: raLocal.plz,
            ort: raLocal.ort,
            email: raLocal.email,
          );
        }
      }

      // Positionen laden falls noch nicht vorhanden
      final positionen = _positionen ??
          await RechnungsPositionRepository.getByRechnung(_rechnung.id);

      if (betrieb == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }

      final g = ref.read(geschaeftProvider).valueOrNull;
      final pdfBytes = await RechnungPdfService.generate(
        rechnung: _rechnung,
        positionen: positionen,
        betrieb: betrieb,
        rechnungsadresse: effektiveRechnungsadresse(
            _rechnung.rechnungsadresse, ra,
            betriebId: _rechnung.betriebId ?? ''),
        firmaName: g?.firma,
        firmaStrasse: g?.adresseStrasse,
        firmaPlzOrt: g?.adressePlzOrt,
        firmaMwst: g?.mwstZeile,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name:
              'Rechnung_${_rechnung.rechnungsnummer ?? _rechnung.id}'.replaceAll('/', '_'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  bool _hasMahnungen() =>
      _rechnung.erinnerungAm != null ||
      _rechnung.mahnung1Am != null ||
      _rechnung.mahnung2Am != null;

  Future<void> _showMahnungPdf(BuildContext context, int stufe) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final betrieb = _rechnung.betriebId != null
          ? await BetriebRepository.getByServerId(_rechnung.betriebId!)
          : null;

      BetriebRechnungsadresse? ra;
      if (_rechnung.betriebId != null) {
        final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
            _rechnung.betriebId!);
        if (raLocal != null) {
          ra = BetriebRechnungsadresse(
            id: raLocal.serverId ?? '',
            userId: raLocal.userId,
            betriebId: _rechnung.betriebId!,
            firma: raLocal.firma,
            vorname: raLocal.vorname,
            nachname: raLocal.nachname,
            strasse: raLocal.strasse,
            nr: raLocal.nr,
            plz: raLocal.plz,
            ort: raLocal.ort,
            email: raLocal.email,
          );
        }
      }

      if (betrieb == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }

      final pdfBytes = await MahnungPdfService.generate(
        rechnung: _rechnung,
        betrieb: betrieb,
        rechnungsadresse: effektiveRechnungsadresse(
            _rechnung.rechnungsadresse, ra,
            betriebId: _rechnung.betriebId ?? ''),
        mahnStufe: stufe,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        final titel = stufe == 0
            ? 'Zahlungserinnerung'
            : stufe == 1
                ? '1_Mahnung'
                : '2_Mahnung';
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: '${titel}_${_rechnung.rechnungsnummer ?? _rechnung.id}'
              .replaceAll('/', '_'),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  Future<void> _showProtokollePdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url =
          await RechnungPdfStorage.getProtokollSignedUrl(_rechnung.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Keine Protokolle vorhanden oder Fehler: $e')),
        );
      }
    }
  }

  Future<void> _markAsBezahlt(BuildContext context) async {
    final brutto = (_rechnung.betragBrutto * 20).roundToDouble() / 20;
    final controller = TextEditingController(text: brutto.toStringAsFixed(2));

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final eingabe = double.tryParse(
                    controller.text.replaceAll(',', '.')) ??
                0;
            final differenz =
                ((eingabe - brutto) * 20).roundToDouble() / 20;

            return AlertDialog(
              title: const Text('Zahlungseingang'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rechnung ${_rechnung.rechnungsnummer ?? ''}\n'
                    'Rechnungsbetrag: CHF ${brutto.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Eingegangener Betrag (CHF)',
                      prefixText: 'CHF ',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (differenz.abs() >= 0.01) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: differenz < 0
                            ? AppColors.warning.withAlpha(25)
                            : AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: differenz < 0
                              ? AppColors.warning.withAlpha(80)
                              : AppColors.success.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            differenz < 0
                                ? Icons.trending_down
                                : Icons.trending_up,
                            size: 18,
                            color: differenz < 0
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              differenz < 0
                                  ? 'Unterzahlung: CHF ${differenz.abs().toStringAsFixed(2)}\n'
                                    'Wird als Debitorenverlust (3805) gebucht'
                                  : 'Mehrzahlung: CHF ${differenz.toStringAsFixed(2)}\n'
                                    'Wird als a.o. Ertrag (8000) gebucht',
                              style: TextStyle(
                                fontSize: 12,
                                color: differenz < 0
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: eingabe > 0
                      ? () => Navigator.pop(ctx, eingabe)
                      : null,
                  child: const Text('Bezahlt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final zahlungBetrag = (result * 20).roundToDouble() / 20;

    try {
      // 1. Rechnung als bezahlt markieren
      await RechnungRepository.update(_rechnung.id, {
        'zahlungsstatus': 'bezahlt',
        'zahlung_eingegangen_am':
            DateTime.now().toIso8601String().split('T').first,
        'zahlung_betrag': zahlungBetrag,
      });

      // 2. Buchungen erstellen (Zahlungseingang + ggf. Differenz)
      final buchungen = await ZahlungsdifferenzService.verbuchen(
        rechnung: _rechnung,
        zahlungBetrag: zahlungBetrag,
      );

      if (mounted) {
        ref.invalidate(rechnungenStreamProvider);
        ref.invalidate(buchungenStreamProvider);
        setState(() {
          _rechnung = Rechnung(
            id: _rechnung.id,
            userId: _rechnung.userId,
            rechnungsnummer: _rechnung.rechnungsnummer,
            rechnungstyp: _rechnung.rechnungstyp,
            betriebId: _rechnung.betriebId,
            rechnungsdatum: _rechnung.rechnungsdatum,
            faelligkeitsdatum: _rechnung.faelligkeitsdatum,
            betragNetto: _rechnung.betragNetto,
            mwstBetrag: _rechnung.mwstBetrag,
            betragBrutto: _rechnung.betragBrutto,
            zahlungsstatus: 'bezahlt',
            versandart: _rechnung.versandart,
            zahlungEingegangenAm: DateTime.now(),
            zahlungBetrag: zahlungBetrag,
            pdfUrl: _rechnung.pdfUrl,
          );
        });

        final differenz =
            ((zahlungBetrag - brutto) * 20).roundToDouble() / 20;
        String snackText = 'Rechnung als bezahlt markiert';
        if (differenz.abs() >= 0.01) {
          snackText += differenz < 0
              ? ' (CHF ${differenz.abs().toStringAsFixed(2)} Debitorenverlust)'
              : ' (CHF ${differenz.toStringAsFixed(2)} Mehrzahlung)';
        }
        if (buchungen.isNotEmpty) {
          snackText += ' — ${buchungen.length} Buchung(en) erstellt';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackText)),
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

  String _versandartLabel(String art) {
    switch (art) {
      case 'rechnung_mail':
        return 'Per E-Mail';
      case 'rechnung_post':
        return 'Per Post';
      case 'rechnung_tresen':
        return 'Am Tresen';
      default:
        return art;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummenRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _SummenRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('CHF ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _MahnungPdfRow extends StatelessWidget {
  final String label;
  final DateTime datum;
  final VoidCallback onTap;

  const _MahnungPdfRow({
    required this.label,
    required this.datum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final datumStr =
        '${datum.day.toString().padLeft(2, '0')}.${datum.month.toString().padLeft(2, '0')}.${datum.year}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(datumStr,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'offen': return 'Offen';
      case 'bezahlt': return 'Bezahlt';
      case 'erinnert': return 'Erinnert';
      case 'mahnung_1': return 'Mahnung 1';
      case 'mahnung_2': return 'Mahnung 2';
      case 'abgeschrieben': return 'Abgeschrieben';
      default: return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'offen': return AppColors.warning;
      case 'bezahlt': return AppColors.success;
      case 'erinnert': return const Color(0xFFE65100);
      case 'mahnung_1': return AppColors.error;
      case 'mahnung_2': return const Color(0xFF8B0000);
      case 'abgeschrieben': return AppColors.inaktiv;
      default: return AppColors.textSecondary;
    }
  }
}
