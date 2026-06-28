import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/file_download_export.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/data/repositories/zahlungsfile_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/pain001_writer.dart';

/// Export-Screen für das GKB-Zahlungsfile (ISO-20022 pain.001).
///
/// Sammelt alle vorgemerkten, noch nicht exportierten Kreditoren-Zahlungen mit
/// IBAN, erzeugt eine pain.001-XML-Datei zum Download und markiert die
/// Rechnungen anschliessend als `exportiert` (verknüpft mit dem Zahlungsfile).
class ZahlungsfileExportScreen extends ConsumerStatefulWidget {
  const ZahlungsfileExportScreen({super.key});

  @override
  ConsumerState<ZahlungsfileExportScreen> createState() =>
      _ZahlungsfileExportScreenState();
}

class _ZahlungsfileExportScreenState
    extends ConsumerState<ZahlungsfileExportScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _fehler;
  List<Eingangsrechnung> _zahlungen = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Lädt offene, vorgemerkte und noch nicht exportierte Zahlungen mit IBAN.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _fehler = null;
    });
    try {
      final rechnungen = await EingangsrechnungRepository.getByStatus(
        const ['gebucht', 'zahlung_vorgemerkt'],
      );
      final offen = rechnungen
          .where((e) =>
              e.zahlungVorgemerkt &&
              e.exportiertAm == null &&
              (e.lieferantIban?.trim().isNotEmpty ?? false))
          .toList();
      setState(() {
        _zahlungen = offen;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _fehler = '$e';
        _loading = false;
      });
    }
  }

  double get _summe =>
      _zahlungen.fold<double>(0, (sum, e) => sum + e.betragBrutto);

  /// Baut den Auftraggeber (Dbtr) aus den Geschäfts-Stammdaten.
  Pain001Debtor _buildDebtor(GeschaeftEinstellungen g) {
    final strasse = g.adresseStrasse; // z.B. "Via Rezia 8"
    final plzOrt = g.adressePlzOrt; // z.B. "7013 Domat/Ems"

    // Strasse am LETZTEN Leerzeichen splitten (Hausnummer am Ende).
    String strtNm = strasse;
    String bldgNb = '';
    final lastSpace = strasse.lastIndexOf(' ');
    if (lastSpace > 0) {
      strtNm = strasse.substring(0, lastSpace).trim();
      bldgNb = strasse.substring(lastSpace + 1).trim();
    }

    // PLZ/Ort am ERSTEN Leerzeichen splitten.
    String pstCd = plzOrt;
    String twnNm = '';
    final firstSpace = plzOrt.indexOf(' ');
    if (firstSpace > 0) {
      pstCd = plzOrt.substring(0, firstSpace).trim();
      twnNm = plzOrt.substring(firstSpace + 1).trim();
    }

    return Pain001Debtor(
      name: g.firma,
      iban: (g.firmenIban ?? '').replaceAll(' ', ''),
      strtNm: strtNm,
      bldgNb: bldgNb,
      pstCd: pstCd,
      twnNm: twnNm,
      ctry: 'CH',
      bic: 'GRKBCH2270A',
    );
  }

  Future<void> _erstellen() async {
    if (_busy || _zahlungen.isEmpty) return;
    setState(() => _busy = true);
    try {
      final g = await GeschaeftRepository.get();
      final iban = (g.firmenIban ?? '').replaceAll(' ', '');
      if (iban.isEmpty) {
        throw Exception(
          'Firmen-IBAN fehlt in den Geschäfts-Einstellungen.',
        );
      }
      final debtor = _buildDebtor(g);

      final millis = DateTime.now().millisecondsSinceEpoch;
      final msgId = 'SBS-$millis';
      final now = DateTime.now();

      final exportierte = List<Eingangsrechnung>.from(_zahlungen);
      final payments = exportierte
          .map((e) => Pain001Payment(
                endToEndId: e.rechnungsnummer ?? 'NOTPROVIDED',
                cdtrName: e.ausstellerName ?? '',
                cdtrIban: e.lieferantIban ?? '',
                cdtrStrtNm: e.ausstellerStrasse,
                cdtrBldgNb: e.ausstellerHausnr,
                cdtrPstCd: e.ausstellerPlz,
                cdtrTwnNm: e.ausstellerOrt,
                cdtrCtry: e.ausstellerLand ?? 'CH',
                referenzTyp: e.referenzTyp ?? 'NON',
                referenz: e.qrReferenz,
                betrag: e.betragBrutto,
                waehrung: 'CHF',
              ))
          .toList();

      final xml = Pain001Writer.build(
        msgId: msgId,
        creationDateTime: now,
        requestedExecutionDate: now,
        debtor: debtor,
        payments: payments,
      );

      // 1. XML herunterladen.
      await downloadTextFile(
        filename: 'gkb_zahlung_$millis.xml',
        content: xml,
        mimeType: 'application/xml',
      );

      // 2. Zahlungsfile-Eintrag in der DB anlegen.
      final ctrlSum =
          exportierte.fold<double>(0, (sum, e) => sum + e.betragBrutto);
      final zf = await ZahlungsfileRepository.create({
        'msg_id': msgId,
        'format': 'pain.001.001.09',
        'anzahl_tx': exportierte.length,
        'ctrl_sum': ctrlSum,
        'status': 'erstellt',
      });

      // 3. Rechnungen als exportiert markieren + verknüpfen.
      final nowIso = now.toIso8601String();
      for (final e in exportierte) {
        await EingangsrechnungRepository.update(e.id, {
          'status': 'exportiert',
          'exportiert_am': nowIso,
          'zahlungsfile_id': zf.id,
        });
      }

      ref.invalidate(eingangsrechnungenProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Zahlungsfile mit ${exportierte.length} Zahlung(en) erstellt.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GKB-Zahlungsfile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Fehler beim Laden:\n$_fehler',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    if (_zahlungen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 64,
              color: AppColors.primary.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              'Keine vorgemerkten Zahlungen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Es gibt aktuell keine vorgemerkten, noch nicht exportierten '
                'Zahlungen mit IBAN.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: _zahlungen.length,
            itemBuilder: (context, i) => _ZahlungZeile(e: _zahlungen[i]),
          ),
        ),
        _Footer(
          anzahl: _zahlungen.length,
          summe: _summe,
          busy: _busy,
          onErstellen: _erstellen,
        ),
      ],
    );
  }
}

class _ZahlungZeile extends StatelessWidget {
  const _ZahlungZeile({required this.e});

  final Eingangsrechnung e;

  @override
  Widget build(BuildContext context) {
    final titel = (e.ausstellerName?.trim().isNotEmpty ?? false)
        ? e.ausstellerName!.trim()
        : 'Unbekannt';
    final betrag = 'CHF ${e.betragBrutto.toStringAsFixed(2)}';
    final iban = e.lieferantIban ?? '—';
    final ref = (e.qrReferenz?.trim().isNotEmpty ?? false)
        ? e.qrReferenz!.trim()
        : (e.referenzTyp ?? 'NON');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  betrag,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'IBAN: $iban',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Referenz: $ref',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.anzahl,
    required this.summe,
    required this.busy,
    required this.onErstellen,
  });

  final int anzahl;
  final double summe;
  final bool busy;
  final VoidCallback onErstellen;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$anzahl Zahlung(en)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Total: CHF ${summe.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // In-Body-Button als GestureDetector (CanvasKit-Klick-Workaround).
              GestureDetector(
                onTap: busy ? null : onErstellen,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: busy
                        ? AppColors.primary.withAlpha(120)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Zahlungsfile erstellen',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Datei anschliessend im GKB-E-Banking hochladen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
