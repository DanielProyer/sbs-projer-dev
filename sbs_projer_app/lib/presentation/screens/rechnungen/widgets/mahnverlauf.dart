import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/mahnschreiben.dart';
import 'package:sbs_projer_app/data/repositories/mahnschreiben_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

/// Mahnverlauf einer Rechnung aus dem Protokoll `mahnschreiben` (v0.134.0)
/// — ersetzt die alten Zeilen, die das Mahn-PDF bei jedem Antippen NEU
/// erzeugten (und damit nicht das zeigten, was verschickt worden war).
///
/// CanvasKit: Zeilen aus GestureDetector + Container + Row, «Zurücknehmen»
/// als `TapKnopf(gefahr: true)` (CLAUDE.md, Wächter).
class Mahnverlauf extends StatefulWidget {
  final String rechnungId;

  /// Nach einem Zurücknehmen — der Aufrufer lädt die Rechnung neu.
  final VoidCallback onGeaendert;

  /// Mahnungen aus der Zeit VOR dem Protokoll (bis v0.133, einzeln über
  /// die alte Eskalation erstellt): Stufe und Datum aus der Rechnung. Eine
  /// Stufe, die schon im Protokoll steht, wird ausgeblendet
  /// ([sichtbareAltEintraege]) — sonst stünde sie doppelt da.
  final List<({int stufe, DateTime datum})> altEintraege;

  const Mahnverlauf({
    super.key,
    required this.rechnungId,
    required this.onGeaendert,
    this.altEintraege = const [],
  });

  @override
  State<Mahnverlauf> createState() => _MahnverlaufState();
}

class _MahnverlaufState extends State<Mahnverlauf> {
  late Future<List<Mahnschreiben>> _laden;

  @override
  void initState() {
    super.initState();
    _laden = MahnschreibenRepository.getByRechnung(widget.rechnungId);
  }

  void _neuLaden() {
    setState(() => _laden = MahnschreibenRepository.getByRechnung(widget.rechnungId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Mahnschreiben>>(
      future: _laden,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snap.hasError) {
          return Text(
            'Mahnverlauf nicht ladbar: ${kurzeFehlermeldung(snap.error!)}',
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          );
        }
        final liste = snap.data ?? const <Mahnschreiben>[];
        final alt = sichtbareAltEintraege(widget.altEintraege, liste);
        if (liste.isEmpty && alt.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mahnverlauf',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              for (final m in liste) _zeile(m),
              for (final a in alt) _altZeile(a.stufe, a.datum),
            ],
          ),
        );
      },
    );
  }

  Widget _zeile(Mahnschreiben m) {
    final stufe = MahnStufe.values[m.stufe.clamp(0, MahnStufe.values.length - 1)];
    final kanal = switch (m.kanal) {
      'mail' => 'Mail',
      'druck' => 'Druck',
      _ => 'Mail + Druck',
    };
    final zurueck = m.zurueckgenommen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: m.pdfPfad == null ? null : () => _pdfOeffnen(m),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 18,
                    color: zurueck ? AppColors.textSecondary : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stufe.titel} · ${_datum(m.erstelltAm.toLocal())}',
                          style: TextStyle(
                            fontSize: 13,
                            decoration: zurueck ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          [
                            kanal,
                            'Frist ${_datum(m.fristBis)}',
                            if (m.test) 'TEST',
                            if (zurueck) 'zurückgenommen',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: m.test ? FontWeight.w600 : null,
                          ),
                        ),
                        // Mail + Druck: Die Zeile öffnet das Mahnschreiben
                        // der Mail; das Einschreiben-PDF liegt daneben als
                        // druck.pdf (Review 23.09.2026, I-2).
                        if (m.kanal == 'mail_und_druck')
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pdfOeffnen(m, datei: 'druck.pdf'),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Druck-PDF öffnen',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!zurueck)
            TapKnopf(
              text: 'Zurücknehmen',
              gefahr: true,
              onTap: () async {
                final ok = await mahnungZuruecknehmen(context, m);
                if (ok) {
                  _neuLaden();
                  widget.onGeaendert();
                }
              },
            ),
        ],
      ),
    );
  }

  /// Alte Einzelmahnung: Das damals abgelegte PDF (`mahnung_<stufe>.pdf`)
  /// öffnen — kein Zurücknehmen, dafür fehlt das Protokoll.
  Widget _altZeile(int stufe, DateTime datum) {
    final titel = MahnStufe.values[stufe.clamp(0, MahnStufe.values.length - 1)].titel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _altPdfOeffnen(stufe),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$titel · ${_datum(datum)} (vor dem Mahnlauf)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _altPdfOeffnen(int stufe) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await RechnungPdfStorage.getMahnungSignedUrl(widget.rechnungId, stufe);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('PDF nicht ladbar: ${kurzeFehlermeldung(e)}')),
      );
    }
  }

  Future<void> _pdfOeffnen(Mahnschreiben m, {String? datei}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = datei ?? m.pdfPfad!.split('/').last;
      final url = await RechnungPdfStorage.getMahnlaufSignedUrl(m.id, name);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('PDF nicht ladbar: ${kurzeFehlermeldung(e)}')),
      );
    }
  }
}

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Bestätigt und nimmt ein Mahnschreiben zurück; zeigt das Ergebnis
/// (zurückgesetzt / übersprungen mit Grund). `true`, wenn etwas
/// zurückgesetzt wurde. Gemeinsam für Mahnverlauf und Mahnlauf-Seite
/// (Knopf nach einem abgebrochenen Lauf).
Future<bool> mahnungZuruecknehmen(BuildContext context, Mahnschreiben m) async {
  final bestaetigt = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mahnung zurücknehmen?'),
      content: Text(
        'Die ${m.rechnungIds.length} Rechnung(en) dieses Schreibens werden auf '
        'den Stand davor gesetzt — nur, wenn sich seither nichts geändert hat '
        '(keine Zahlung, keine weitere Mahnung). Das Schreiben bleibt im '
        'Verlauf stehen.',
      ),
      actions: [
        TapKnopf(text: 'Abbrechen', primaer: false, onTap: () => Navigator.pop(ctx, false)),
        TapKnopf(text: 'Zurücknehmen', gefahr: true, onTap: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  if (bestaetigt != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final erg = await MahnlaufService.zuruecknehmen(m);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(zuruecknehmenMeldung(erg)),
    ));
    return !erg.nichtsZurueckgesetzt;
  } on MahnlaufFehler catch (f) {
    messenger.showSnackBar(SnackBar(content: Text('Zurücknehmen fehlgeschlagen: ${f.meldung}')));
    return false;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Zurücknehmen fehlgeschlagen: ${kurzeFehlermeldung(e)}')),
    );
    return false;
  }
}

/// Alte Mahnverlauf-Einträge (aus den Datumsfeldern der Rechnung, vor dem
/// Protokoll) — nur die, deren Stufe NICHT schon im Protokoll steht
/// (Review 23.09.2026, M-4). Sonst verschwände eine alte Erinnerung, sobald
/// die 1. Mahnung über den Mahnlauf protokolliert ist.
List<({int stufe, DateTime datum})> sichtbareAltEintraege(
  List<({int stufe, DateTime datum})> alt,
  List<Mahnschreiben> protokoll,
) {
  final protokolliert = {for (final m in protokoll) m.stufe};
  return [for (final a in alt) if (!protokolliert.contains(a.stufe)) a];
}

/// Rückmeldung nach dem Zurücknehmen — mit Rechnungsnummer je
/// übersprungener Rechnung (Review 23.09.2026, M-7): «2 übersprungen» allein
/// sagt nicht, WELCHE Rechnung noch gemahnt dasteht.
String zuruecknehmenMeldung(MahnlaufZuruecknehmenErgebnis erg) {
  final details = [
    for (final u in erg.uebersprungen) '${u.rechnungsnummer ?? u.rechnungId}: ${u.grund}',
  ].join('; ');
  if (erg.nichtsZurueckgesetzt) {
    return 'Nichts zurückgesetzt ($details) — das Schreiben gilt weiter.';
  }
  final basis = '${erg.zurueckgesetzt.length} Rechnung(en) zurückgesetzt';
  return erg.uebersprungen.isEmpty ? '$basis.' : '$basis; nicht zurückgesetzt: $details.';
}
