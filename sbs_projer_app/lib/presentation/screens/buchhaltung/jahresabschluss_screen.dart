import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/jahresabschluss_schritte.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/jahresabschluss_providers.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_leiste.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/pdf/jahresrechnung_pdf_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;

/// Der geführte Jahresabschluss als Liste — reine Darstellung, testbar ohne
/// Provider (Bauart wie `MonatsabschlussInhalt`).
///
/// WARUM: Den Abschluss 2025 hat Claude per SQL gebucht und das
/// Beilage-Skript von Hand gefüttert (Entscheid Daniel 29.09.2026: ab 2026
/// macht er ihn selbst in der App). Die sechs Schritte zeigen, was fällig ist
/// und wo es erledigt wird; die Jahresrechnung entsteht zum Schluss direkt
/// ins Steuer-Dossier.
class JahresabschlussInhalt extends StatelessWidget {
  final int jahr;
  final List<int> jahre;
  final ValueChanged<int> onJahr;

  /// `null` solange geladen wird oder ein Fehler vorliegt.
  final List<JahresabschlussSchritt>? schritte;
  final String? fehler;
  final ValueChanged<SchrittAktion> onAktion;
  final VoidCallback? onNeuLaden;

  /// Aktionen, die gerade laufen — ihr Knopf dreht und ist gesperrt.
  final Set<SchrittAktion> laufend;

  const JahresabschlussInhalt({
    super.key,
    required this.jahr,
    required this.jahre,
    required this.onJahr,
    required this.schritte,
    required this.onAktion,
    this.fehler,
    this.onNeuLaden,
    this.laufend = const {},
  });

  static Color farbe(PruefStatus s) => switch (s) {
    PruefStatus.rot => AppColors.error,
    PruefStatus.gelb => AppColors.warning,
    PruefStatus.gruen => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final liste = schritte;
    final erledigt =
        liste?.where((s) => s.status == PruefStatus.gruen).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Jahresabschluss')),
      body: Column(
        children: [
          AppJahrLeiste(
            jahre: jahre,
            selectedJahr: jahr,
            onJahrChanged: onJahr,
            trailing: liste == null
                ? null
                : Text(
                    '$erledigt von ${liste.length} erledigt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: erledigt == liste.length
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
          ),
          Expanded(child: _koerper(context, liste)),
        ],
      ),
    );
  }

  Widget _koerper(BuildContext context, List<JahresabschlussSchritt>? liste) {
    if (fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fehler!, textAlign: TextAlign.center),
              if (onNeuLaden != null) ...[
                const SizedBox(height: 12),
                TapKnopf(
                  text: 'Erneut laden',
                  primaer: false,
                  onTap: onNeuLaden,
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (liste == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Reihenfolge einhalten: Abschreibung und Delkredere ändern die '
            'Bilanz, die Rückstellung den Gewinn — die Jahresrechnung zuletzt '
            'erzeugen.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        for (final s in liste) _zeile(s),
      ],
    );
  }

  /// CanvasKit: Container + Row/Column, Knöpfe als `TapKnopf`.
  Widget _zeile(JahresabschlussSchritt s) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: farbe(s.status), width: 2),
          ),
          child: Text(
            '${s.nr}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      s.titel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      key: ValueKey('punkt-${s.nr}'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: farbe(s.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(s.ist, style: const TextStyle(fontSize: 12)),
              if (s.hinweis.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    s.hinweis,
                    style: TextStyle(
                      fontSize: 11,
                      color: s.status == PruefStatus.gruen
                          ? AppColors.textSecondary
                          : farbe(s.status),
                    ),
                  ),
                ),
              if (s.knoepfe.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in s.knoepfe)
                        TapKnopf(
                          text: k.text,
                          primaer: false,
                          laeuft: laufend.contains(k.aktion),
                          onTap: () => onAktion(k.aktion),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Eingaben des Erzeugen-Dialogs.
typedef JahresrechnungEingabe = ({double manuell, String? ereignisse});

/// Rückfrage vor dem Ablegen: weitere Aufrechnungen, Ereignisse nach dem
/// Bilanzstichtag und die Kennzahlen, die ins PDF kommen.
class JahresrechnungDialog extends StatefulWidget {
  final JahresrechnungKennzahlen kennzahlen;

  /// Wie viele Jahresrechnungen des Jahrs schon im Dossier liegen.
  final int bisherige;

  const JahresrechnungDialog({
    super.key,
    required this.kennzahlen,
    this.bisherige = 0,
  });

  @override
  State<JahresrechnungDialog> createState() => _JahresrechnungDialogState();
}

class _JahresrechnungDialogState extends State<JahresrechnungDialog> {
  final _aufrechnung = TextEditingController();
  final _ereignisse = TextEditingController();

  @override
  void dispose() {
    _aufrechnung.dispose();
    _ereignisse.dispose();
    super.dispose();
  }

  /// Leeres Feld = 0; unlesbar = null (Knopf gesperrt statt still 0).
  double? get _manuell {
    final t = _aufrechnung.text.trim();
    if (t.isEmpty) return 0;
    return chfBetragParsen(t);
  }

  @override
  Widget build(BuildContext context) {
    final manuell = _manuell;
    final k = widget.kennzahlen.mit(aufrechnungenManuell: manuell ?? 0);
    final fassung = widget.bisherige + 1;
    Widget zahl(String l, double v, {bool fett = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                fontSize: 12,
                fontWeight: fett ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            chf(v),
            style: TextStyle(
              fontSize: 12,
              fontWeight: fett ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      title: Text(
        widget.bisherige == 0
            ? 'Jahresrechnung ${k.jahr} erzeugen'
            : 'Fassung $fassung ablegen?',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.bisherige > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Im Dossier liegt schon '
                  '${widget.bisherige == 1 ? 'eine Jahresrechnung' : '${widget.bisherige} Fassungen'} '
                  '${k.jahr}. Fassung $fassung wird zusätzlich abgelegt, '
                  'die bisherige bleibt liegen.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            TextField(
              controller: _aufrechnung,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9.,'’\s-]")),
              ],
              decoration: InputDecoration(
                labelText: 'Weitere Aufrechnungen (CHF)',
                hintText: '0.00',
                errorText: manuell == null ? 'Kein gültiger Betrag' : null,
                helperText:
                    'Bussen 6280/6281 ${chf(k.aufrechnungenAuto)} sind schon '
                    'aufgerechnet. Hier z. B. Bussen, die auf 8900 liefen.',
                helperMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ereignisse,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ereignisse nach dem Bilanzstichtag (optional)',
                helperText: 'Leer: Standardtext im Anhang.',
              ),
            ),
            const SizedBox(height: 16),
            zahl('Gewinn ${k.jahr}', k.gewinn),
            zahl('+ Aufrechnungen', k.aufrechnungen),
            zahl('= Steuerbarer Gewinn', k.steuerbarerGewinn, fett: true),
            zahl('Eigenkapital 31.12.${k.jahr}', k.eigenkapital, fett: true),
          ],
        ),
      ),
      actions: [
        TapKnopf(
          text: 'Abbrechen',
          primaer: false,
          onTap: () => Navigator.pop(context),
        ),
        TapKnopf(
          text: widget.bisherige == 0 ? 'Erzeugen' : 'Fassung $fassung ablegen',
          onTap: manuell == null
              ? null
              : () => Navigator.pop<JahresrechnungEingabe>(context, (
                  manuell: manuell,
                  ereignisse: _ereignisse.text.trim().isEmpty
                      ? null
                      : _ereignisse.text.trim(),
                )),
        ),
      ],
    );
  }
}

/// Angebunden: hält die Jahreswahl, lädt die Lage und führt die Aktionen aus.
class JahresabschlussScreen extends ConsumerStatefulWidget {
  final int? jahr;
  const JahresabschlussScreen({super.key, this.jahr});

  @override
  ConsumerState<JahresabschlussScreen> createState() =>
      _JahresabschlussScreenState();
}

class _JahresabschlussScreenState extends ConsumerState<JahresabschlussScreen> {
  /// Vorgabe ist das Vorjahr: Das laufende Jahr lässt sich noch nicht
  /// abschliessen (wie der Vormonat beim Monatsabschluss).
  late int _jahr = _gueltig(widget.jahr) ? widget.jahr! : _vorgabe();
  final Set<SchrittAktion> _laufend = {};

  static int _vorgabe() {
    final j = DateTime.now().year - 1;
    return j < kSteuerJahrAb ? kSteuerJahrAb : j;
  }

  static bool _gueltig(int? j) =>
      j != null && j >= kSteuerJahrAb && j <= DateTime.now().year;

  @override
  void didUpdateWidget(JahresabschlussScreen alt) {
    super.didUpdateWidget(alt);
    if (widget.jahr != alt.jahr && _gueltig(widget.jahr)) {
      setState(() => _jahr = widget.jahr!);
    }
  }

  List<int> get _jahre => [
    for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--) j,
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(jahresabschlussLageProvider(_jahr));
    final lage = async.valueOrNull;
    return JahresabschlussInhalt(
      jahr: _jahr,
      jahre: _jahre,
      onJahr: (j) => setState(() => _jahr = j),
      // Nach einer Buchung rechnet die Lage neu — die Liste bleibt dabei
      // stehen, statt auf den Spinner zurückzufallen.
      schritte: async.isLoading && lage?.jahr != _jahr
          ? null
          : lage?.schritte(DateTime.now()),
      fehler: async.hasError && lage == null
          ? 'Jahresabschluss nicht ladbar: ${kurzeFehlermeldung(async.error!)}'
          : null,
      onNeuLaden: () => ref.invalidate(jahresabschlussLageProvider(_jahr)),
      laufend: _laufend,
      onAktion: (a) => _aktion(a, lage),
    );
  }

  void _aktion(SchrittAktion a, JahresabschlussLage? lage) {
    switch (a) {
      case SchrittAktion.pruefung:
        context.push('/buchhaltung/audit?jahr=$_jahr');
      case SchrittAktion.abschreibung:
        context.push('/buchhaltung/abschreibung?jahr=$_jahr');
      case SchrittAktion.steuerjahr:
        context.push('/buchhaltung/steuern/$_jahr');
      case SchrittAktion.vorschau:
        if (lage != null) _vorschau(lage);
      case SchrittAktion.erzeugen:
        if (lage != null) _erzeugen(lage);
    }
  }

  Future<Uint8List> _pdf(
    JahresabschlussLage lage,
    JahresrechnungKennzahlen k,
  ) async {
    // Firmendaten sind Kür: Lassen sie sich nicht laden, greifen die
    // Rückfall-Konstanten des PDF-Kopfs — die Jahresrechnung entsteht trotzdem.
    GeschaeftEinstellungen? gs;
    try {
      gs = await ref.read(geschaeftProvider.future);
    } catch (_) {
      gs = null;
    }
    return JahresrechnungPdfService.generate(
      k: k,
      bilanz: lage.bilanz,
      bilanzVorjahr: lage.bilanzVorjahr,
      er: lage.er,
      erVorjahr: lage.erVorjahr,
      konten: lage.konten,
      kontenVorjahr: lage.kontenVorjahr,
      firmaName: gs?.firma,
      firmaStrasse: gs?.adresseStrasse,
      firmaOrt: gs?.adressePlzOrt,
      mwstZeile: gs?.mwstZeile,
      geschaeftsfuehrer: gs?.gfVollname,
      erstelltAm: DateTime.now(),
    );
  }

  Future<void> _mitSperre(SchrittAktion a, Future<void> Function() f) async {
    if (_laufend.contains(a)) return;
    setState(() => _laufend.add(a));
    try {
      await f();
    } finally {
      if (mounted) setState(() => _laufend.remove(a));
    }
  }

  Future<void> _vorschau(JahresabschlussLage lage) =>
      _mitSperre(SchrittAktion.vorschau, () async {
        try {
          final bytes = await _pdf(lage, lage.kennzahlen);
          await Printing.layoutPdf(
            onLayout: (_) => bytes,
            name: jahresrechnungDateiname(lage.jahr),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF-Fehler: ${kurzeFehlermeldung(e)}')),
          );
        }
      });

  Future<void> _erzeugen(JahresabschlussLage lage) async {
    final bisherige = lage.jahresrechnungen.length;
    final eingabe = await showDialog<JahresrechnungEingabe>(
      context: context,
      builder: (_) => JahresrechnungDialog(
        kennzahlen: lage.kennzahlen,
        bisherige: bisherige,
      ),
    );
    if (eingabe == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final k = lage.kennzahlen.mit(
      aufrechnungenManuell: eingabe.manuell,
      ereignisse: eingabe.ereignisse,
    );
    final fassung = bisherige + 1;

    await _mitSperre(SchrittAktion.erzeugen, () async {
      try {
        final bytes = await _pdf(lage, k);
        await DokumentRepository.upload(
          bereich: 'steuern',
          typ: 'jahresrechnung',
          jahr: lage.jahr,
          dokumentDatum: DateTime(lage.jahr, 12, 31),
          titel: jahresrechnungTitel(k, fassung: fassung),
          dateiname: jahresrechnungDateiname(lage.jahr, fassung: fassung),
          dateityp: 'application/pdf',
          bytes: bytes,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Jahresrechnung nicht abgelegt: ${kurzeFehlermeldung(e)}',
            ),
          ),
        );
        return;
      }

      // Steuerjahr frisch lesen, nicht aus der Lage: Wurde es inzwischen
      // bearbeitet, überschriebe der alte Stand sonst die neuen Felder.
      var vorbefuellt = false;
      String? steuerjahrFehler;
      try {
        final alle = await SteuerjahrRepository.getAll();
        final alt = alle.where((s) => s.jahr == lage.jahr).firstOrNull;
        final neu = steuerjahrVorbefuellt(alt, k);
        if (neu != null) {
          await SteuerjahrRepository.upsert(neu);
          vorbefuellt = true;
        }
      } catch (e) {
        steuerjahrFehler = kurzeFehlermeldung(e);
      }

      if (!mounted) return;
      invalidateSteuern(ref);
      ref.invalidate(jahresabschlussLageProvider(lage.jahr));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Jahresrechnung ${lage.jahr}'
            '${fassung > 1 ? ' (Fassung $fassung)' : ''} im Dossier abgelegt'
            '${vorbefuellt ? ' — steuerbarer Gewinn und Kapital im Steuerjahr eingetragen' : ''}'
            '${steuerjahrFehler == null ? '' : ' — Steuerjahr nicht vorbefüllt: $steuerjahrFehler'}',
          ),
        ),
      );
    });
  }
}
