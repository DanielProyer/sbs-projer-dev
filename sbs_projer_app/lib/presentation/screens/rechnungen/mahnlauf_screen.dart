import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnschreiben_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnlauf_provider.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/widgets/mahnverlauf.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart'
    show MahnPosten;
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';
import 'package:sbs_projer_app/services/rechnung/mahnfall_service.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

/// Mahnlauf (v0.134.0, Spec docs/superpowers/specs/2026-09-23-mahnwesen-design.md
/// Abschnitte 3–4): Vorschläge je Betrieb, Vorschau, erst der zweite Klick
/// erstellt die Mahnung.
///
/// [rechnungId] gesetzt = Einzelmahnung aus der Rechnung: nur der Betrieb
/// dieser Rechnung, nur sie angehakt. Die Sicherungen gelten unverändert.
///
/// CanvasKit (CLAUDE.md): keine Material-Buttons/ListTile/ExpansionTile —
/// Karten aus GestureDetector + Container + Row, Aktionen über `TapKnopf`.
class MahnlaufScreen extends ConsumerStatefulWidget {
  final String? rechnungId;

  const MahnlaufScreen({super.key, this.rechnungId});

  @override
  ConsumerState<MahnlaufScreen> createState() => _MahnlaufScreenState();
}

class _MahnlaufScreenState extends ConsumerState<MahnlaufScreen> {
  /// Häkchen je Betrieb; fehlt ein Betrieb, sind alle Fälligen angehakt.
  final _auswahl = <String, Set<String>>{};
  final _offen = <String>{};
  String? _laeuftFuer;

  /// Letztes Druck-PDF dieser Sitzung — geöffnet nur per Klick (Pop-up-
  /// Sperre des Browsers), siehe `_erstellen`.
  Uint8List? _druckPdf;
  String? _druckName;

  bool get _einzel => widget.rechnungId != null;

  @override
  void initState() {
    super.initState();
    // Die Glocke hält den Mahnlauf am Leben (mahnlaufAufgabeProvider) —
    // ohne Neuladen zeigte die Seite den Stand vom App-Start (Review N-2).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(mahnlaufProvider);
    });
  }

  Set<String> _gewaehlt(MahnBetrieb b) => _auswahl[b.betriebId] ??= _einzel
      ? {widget.rechnungId!}
      : b.faellig.map((p) => p.rechnung.id).toSet();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mahnlaufProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/rechnungen'),
        ),
        // Version sichtbar (CLAUDE.md): Feldrückmeldungen lassen sich nur so
        // einem Stand zuordnen.
        title: Text(
          '${_einzel ? 'Einzelmahnung' : 'Mahnlauf'}  ·  v$kAppVersion',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Mahnlauf nicht ladbar: ${kurzeFehlermeldung(e)}'),
          ),
        ),
        data: (alle) {
          final daten =
              _einzel ? fuerEinzelmahnung(alle, widget.rechnungId!) : alle;
          return RefreshIndicator(
            onRefresh: () async => _neuLaden(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _bankKarte(daten),
                if (daten.zahlungsSperreGrund != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _zahlungsSperreKarte(daten),
                  ),
                if (daten.auszugHinweis != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _kasten(
                      farbe: AppColors.warning,
                      child: Text(
                        daten.auszugHinweis!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                if (_druckPdf != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _kasten(
                      farbe: AppColors.primary,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Druck-PDF der letzten Mahnung',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TapKnopf(
                            text: 'Öffnen',
                            icon: Icons.picture_as_pdf,
                            onTap: _druckPdfOeffnen,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!MailConfig.istScharf('mahnwesen')) _testmodusZeile(),
                const SizedBox(height: 12),
                _titel('Mahnfällig', daten.betriebe.length),
                if (daten.betriebe.isEmpty) _leerHinweis(daten),
                for (final b in daten.betriebe) _betriebKarte(b),
                if (daten.eskalation.isNotEmpty) ...[
                  _titel('Heineken einschalten', daten.eskalation.length),
                  _hinweis(
                    'Die letzte Mahnung samt Frist ist abgelaufen. Nächster '
                    'Schritt: Mahnfall eröffnen und Heineken einschalten.',
                  ),
                  for (final b in daten.eskalation) _eskalationKarte(b),
                ],
                if (daten.offeneFaelle.isNotEmpty) ...[
                  _titel('Offene Mahnfälle', daten.offeneFaelle.length),
                  for (final f in daten.offeneFaelle) _fallZeile(f, daten.imFall),
                ],
                if (daten.eingefroreneFaelle.isNotEmpty) ...[
                  _titel('Erledigt, Rechnungen gesperrt', daten.eingefroreneFaelle.length),
                  _hinweis(
                    'Nach Heineken-Übernahme oder zurückgezogener Betreibung '
                    'werden diese Rechnungen weder gemahnt noch neu eskaliert.',
                  ),
                  for (final f in daten.eingefroreneFaelle) _fallZeile(f, daten.imFall),
                ],
                if (daten.zahlungGebucht.isNotEmpty) ...[
                  _titel('Zahlung gebucht — Status prüfen', daten.zahlungGebucht.length),
                  _hinweis(
                    'Auf diese Rechnungen ist ein Zahlungseingang gebucht, der '
                    'Status steht aber noch offen/gemahnt. Sie werden nie '
                    'gemahnt — bitte Status in der Rechnung klären.',
                  ),
                  for (final r in daten.zahlungGebucht) _rechnungZeile(r),
                ],
                if (daten.inFrist.isNotEmpty) ...[
                  _titel('In Frist', daten.inFrist.length),
                  for (final r in daten.inFrist) _rechnungZeile(r, frist: true),
                ],
                if (daten.erstZustellen.isNotEmpty) ...[
                  _titel('Erst zustellen', daten.erstZustellen.length),
                  _hinweis(
                    'Ohne Zustellnachweis wird nicht gemahnt. In der Rechnung '
                    '«Rechnung erneut senden» oder die Übergabe vermerken.',
                  ),
                  for (final r in daten.erstZustellen) _rechnungZeile(r),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _neuLaden() {
    // Der Mahnlauf lädt Prüfliste, Auszüge, Rechnungen und Zahlungen selbst
    // aus der DB — ein Invalidate genügt. Mit ihm rechnen nur die
    // Mahnlauf-Aufgabe und das Zusammensetzen der Aufgabenliste neu; die
    // übrigen Detektoren (aufgabenDetektorenProvider) bleiben unberührt.
    ref.invalidate(mahnlaufProvider);
  }

  // ─── Kopf ───

  Widget _bankKarte(MahnlaufDaten d) {
    if (d.bankGesperrt) {
      return _kasten(
        farbe: AppColors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.bankSperrgrund ?? 'Bankauszug fehlt',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TapKnopf(
              text: 'Bankauszug einlesen',
              icon: Icons.upload_file,
              onTap: () async {
                await context.push('/buchhaltung/camt-import');
                if (mounted) _neuLaden();
              },
            ),
          ],
        ),
      );
    }
    return _kasten(
      farbe: AppColors.success,
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auszug bis ${_datum(d.letzterAuszug!)} ✓',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Rote Karte «unverknüpfte Kundenzahlung» (24.09.2026) — analog zur
  /// Bankkarte: sperrt den GANZEN Mahnlauf, bis die Zahlung(en) zugeordnet
  /// sind. Betriebe, die per Kürzel eindeutig getroffen wurden, sperren
  /// stattdessen nur ihre eigene Karte (siehe `_betriebKarte`).
  Widget _zahlungsSperreKarte(MahnlaufDaten d) => _kasten(
        farbe: AppColors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.zahlungsSperreGrund!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final z in d.zahlungsSperreZahlungen)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_datum(z.datum)} · CHF ${z.betrag.toStringAsFixed(2)} · '
                  '${z.beschreibung}${z.belegnummer != null ? ' (${z.belegnummer})' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            TapKnopf(
              text: 'Buchungen öffnen',
              icon: Icons.receipt_long,
              onTap: () async {
                await context.push('/buchhaltung/buchungen');
                if (mounted) _neuLaden();
              },
            ),
          ],
        ),
      );

  Widget _testmodusZeile() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _kasten(
          farbe: AppColors.warning,
          child: const Text(
            'Testmodus: Mails gehen an ${MailConfig.testEmpfaenger}, PDFs mit MUSTER',
            style: TextStyle(fontSize: 13),
          ),
        ),
      );

  Widget _leerHinweis(MahnlaufDaten d) {
    String text;
    if (_einzel) {
      if (d.imFall.isNotEmpty) {
        text = 'Diese Rechnung steht in einem Mahnfall — dort weiterführen, '
            'nicht erneut mahnen.';
      } else if (d.eskalation.isNotEmpty) {
        text = 'Die letzte Mahnung ist abgelaufen — nächster Schritt: '
            'Heineken einschalten (unten).';
      } else if (d.zahlungGebucht.isNotEmpty) {
        text = 'Auf diese Rechnung ist eine Zahlung gebucht — nicht mahnen.';
      } else if (d.erstZustellen.isNotEmpty) {
        text = 'Diese Rechnung ist nicht nachweislich zugestellt.';
      } else if (d.bankGesperrt) {
        text = 'Erst nach dem Einlesen des aktuellen Bankauszugs prüfbar.';
      } else if (d.zahlungsSperreGrund != null) {
        text = 'Erst nach dem Zuordnen der unverknüpften Zahlung prüfbar.';
      } else if (d.inFrist.isNotEmpty) {
        text = 'Die Frist der letzten Mahnung läuft noch.';
      } else {
        text = 'Diese Rechnung ist derzeit nicht mahnfällig '
            '(Fälligkeit + $kErinnerungNachTagen Tage, gemessen am Bankauszug).';
      }
    } else if (d.bankGesperrt) {
      text = 'Erst nach dem Einlesen des aktuellen Bankauszugs prüfbar.';
    } else if (d.zahlungsSperreGrund != null) {
      text = 'Erst nach dem Zuordnen der unverknüpften Zahlung prüfbar.';
    } else {
      text = 'Nichts mahnfällig.';
    }
    return _hinweis(text);
  }

  // ─── Betriebskarte ───

  Widget _betriebKarte(MahnBetrieb b) {
    final auf = _einzel || _offen.contains(b.betriebId);
    final gewaehlt = _gewaehlt(b);
    final laeuft = _laeuftFuer == b.betriebId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: b.gesperrt ? AppColors.error.withAlpha(120) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (!_offen.remove(b.betriebId)) _offen.add(b.betriebId);
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.anzeige,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.faellig.length} Rechnung(en) · '
                          'CHF ${b.summeFaellig.toStringAsFixed(2)} · ${b.hoechste.titel} · '
                          '${_kanalText(b.kanal)}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(auf ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (b.gesperrt)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                b.sperrgrund!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          if (auf) ...[
            for (final p in b.faellig) _postenZeile(b, p, gewaehlt),
            if (!b.gesperrt)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TapKnopf(
                    text: 'Vorschau',
                    icon: Icons.visibility,
                    laeuft: laeuft,
                    onTap: gewaehlt.isEmpty || _laeuftFuer != null
                        ? null
                        : () => _vorschau(b),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _postenZeile(MahnBetrieb b, MahnPosten p, Set<String> gewaehlt) {
    final r = p.rechnung;
    final an = gewaehlt.contains(r.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Gesperrter Betrieb: keine Auswahl möglich — es gibt nichts zu mahnen.
      onTap: b.gesperrt
          ? null
          : () => setState(() => an ? gewaehlt.remove(r.id) : gewaehlt.add(r.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            if (!b.gesperrt) ...[
              Icon(
                an ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: an ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.rechnungsnummer ?? '—'} · ${_datum(r.rechnungsdatum)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    p.stufe.titel,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              'CHF ${r.betragBrutto.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Vorschau und Erstellen ───

  Future<void> _vorschau(MahnBetrieb b) async {
    final gewaehlt = _gewaehlt(b);
    final posten = b.faellig.where((p) => gewaehlt.contains(p.rechnung.id)).toList();
    if (posten.isEmpty) return;

    setState(() => _laeuftFuer = b.betriebId);
    BetriebLocal? betrieb;
    String? raMail;
    try {
      betrieb = await BetriebRepository.getByServerId(b.betriebId);
      raMail = (await BetriebRechnungsadresseRepository.getByBetrieb(b.betriebId))?.email;
    } catch (e) {
      _meldung('Vorschau nicht möglich: ${kurzeFehlermeldung(e)}');
      return;
    } finally {
      if (mounted) setState(() => _laeuftFuer = null);
    }
    if (betrieb == null) {
      _meldung('Betrieb nicht gefunden.');
      return;
    }
    if (!mounted) return;

    final stufe = hoechsteStufe(posten.map((p) => p.stufe));
    // Dieselbe Regel wie der Versand (`mahnKanal`) — die Vorschau darf nie
    // einen anderen Kanal zeigen, als dann gewählt wird.
    final k = mahnKanal(raMail: raMail, betriebMail: betrieb.email, stufe: stufe);
    final kontoauszug = b.offeneImMahnbereich.length > 1;
    final test = !MailConfig.istScharf('mahnwesen');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stufe.titel} — ${b.anzeige}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _vorschauZeile('Empfänger', k.mail ?? 'keine Mailadresse'),
              if (test && k.mail != null)
                _vorschauZeile('', 'Testmodus: geht an ${MailConfig.testEmpfaenger}'),
              _vorschauZeile('Kanal', _kanalText(k)),
              _vorschauZeile('Stufe', stufe.titel),
              _vorschauZeile('Neue Frist', _datum(mahnFrist(DateTime.now()))),
              _vorschauZeile(
                'Letzte Zahlung',
                b.letzteZahlung == null
                    ? 'keine vermerkt'
                    : '${_datum(b.letzteZahlung!.datum)} · '
                        'CHF ${b.letzteZahlung!.betrag.toStringAsFixed(2)}',
              ),
              _vorschauZeile(
                'Beilagen',
                [
                  kontoauszug ? 'Kontoauszug ${DateTime.now().year}' : 'kein Kontoauszug',
                  if (k.mail != null) '${posten.length} Rechnungskopie(n) per Mail',
                ].join(' · '),
              ),
              const SizedBox(height: 8),
              const Text('Rechnungen', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final p in posten)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${p.rechnung.rechnungsnummer ?? '—'} · ${_datum(p.rechnung.rechnungsdatum)} · '
                    'CHF ${p.rechnung.betragBrutto.toStringAsFixed(2)} · ${p.stufe.titel}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TapKnopf(
                    text: 'Abbrechen',
                    primaer: false,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                  TapKnopf(
                    text: 'Mahnung erstellen',
                    primaer: true,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _erstellen(b, betrieb, posten);
  }

  /// Erstellt die Mahnung — aber erst nach einer FRISCHEN Prüfung aller
  /// Sicherungen (Review 23.09.2026, I-1): Zwischen Vorschau und Klick kann
  /// ein Auszug eingelesen, eine Zahlung zugeordnet oder gebucht, eine
  /// Rechnung bezahlt worden sein. Der Mahnlauf wird dafür neu aus der
  /// Datenbank gebaut; aus DIESEM Stand kommen auch offene Rechnungen und
  /// Kontoauszug-Inhalt. Weicht etwas ab, wird nichts erstellt.
  Future<void> _erstellen(
    MahnBetrieb alt,
    BetriebLocal betrieb,
    List<MahnPosten> posten,
  ) async {
    setState(() => _laeuftFuer = alt.betriebId);
    try {
      _neuLaden();
      final frisch = await ref.read(mahnlaufProvider.future);
      final p = pruefeVorErstellen(frisch: frisch, betriebId: alt.betriebId, gewaehlt: posten);
      if (p.fehler != null) {
        _meldung(p.fehler!);
        return;
      }
      // Zusätzlich jede Rechnung einzeln direkt aus der DB — der Stand der
      // Seite ist höchstens Sekunden alt, aber hier geht es um Bezahltes.
      final geprueft = <MahnPosten>[];
      for (final x in p.posten) {
        final db = await RechnungRepository.getById(x.rechnung.id);
        final stufeDb =
            db == null ? null : faelligeStufe(db, stichtag: frisch.letzterAuszug!);
        if (db == null || stufeDb != x.stufe) {
          _meldung('Daten haben sich geändert — bitte neu prüfen '
              '(${x.rechnung.rechnungsnummer ?? 'Rechnung'}).');
          return;
        }
        geprueft.add((rechnung: db, stufe: x.stufe));
      }

      final erg = await MahnlaufService.erstellen(
        betrieb: betrieb,
        posten: geprueft,
        offeneDesBetriebs: p.karte!.offeneImMahnbereich,
        rechnungenDesJahres: p.karte!.rechnungenDesJahres,
      );
      if (erg.druckPdf != null && mounted) {
        // Nicht automatisch öffnen: Der Browser blockiert Tabs, die nicht
        // direkt aus einem Klick entstehen. Die Bytes bleiben hier, bis
        // Daniel «Druck-PDF öffnen» tippt (Review 23.09.2026, I-2).
        setState(() {
          _druckPdf = erg.druckPdf;
          _druckName =
              'Mahnung_${betrieb.name.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüéè]+'), '_')}.pdf';
        });
      }
      if (mounted) await _ergebnisZeigen(erg);
    } on MahnlaufFehler catch (f) {
      if (mounted) await _fehlerZeigen(f);
    } catch (e) {
      _meldung('Mahnung fehlgeschlagen: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) {
        ref.invalidate(rechnungenStreamProvider);
        ref.invalidate(mahnlaufProvider);
        setState(() {
          _laeuftFuer = null;
          _auswahl.remove(alt.betriebId);
        });
      }
    }
  }

  void _druckPdfOeffnen() {
    final bytes = _druckPdf;
    if (bytes == null) return;
    oeffnePdfImNeuenTab(bytes, _druckName ?? 'Mahnung.pdf');
  }

  Future<void> _ergebnisZeigen(MahnlaufErgebnis erg) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mahnung erstellt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(erg.mailAn != null
                  ? 'Mail verschickt (Empfänger: ${erg.mailAn}'
                      '${MailConfig.istScharf('mahnwesen') ? '' : ' — Testmodus, an ${MailConfig.testEmpfaenger}'}).'
                  : 'Keine Mail — PDF zum Ausdrucken.'),
              if (erg.druckPdf != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Druck-PDF bereit (auch später oben auf der Seite).'),
                ),
              if (erg.fehlendeAnhaenge.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nicht angehängt: ${erg.fehlendeAnhaenge.join(', ')}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
            ],
          ),
          actions: [
            if (erg.druckPdf != null)
              TapKnopf(
                text: 'Druck-PDF öffnen',
                icon: Icons.picture_as_pdf,
                onTap: _druckPdfOeffnen,
              ),
            TapKnopf(text: 'OK', primaer: false, onTap: () => Navigator.pop(ctx)),
          ],
        ),
      );

  /// Fehler nach dem Protokoll: Die Stufen stehen schon — direkt
  /// «Zurücknehmen» anbieten statt nur einer roten Meldung.
  Future<void> _fehlerZeigen(MahnlaufFehler f) async {
    final id = f.mahnschreibenId;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mahnung nicht vollständig'),
        content: Text(f.meldung),
        actions: [
          if (id != null)
            TapKnopf(
              text: 'Zurücknehmen',
              gefahr: true,
              onTap: () async {
                Navigator.pop(ctx);
                await _zuruecknehmenNachFehler(id);
              },
            ),
          TapKnopf(text: 'Schliessen', primaer: false, onTap: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Future<void> _zuruecknehmenNachFehler(String id) async {
    try {
      final m = await MahnschreibenRepository.getById(id);
      if (m == null) {
        _meldung('Mahnschreiben nicht gefunden.');
        return;
      }
      if (!mounted) return;
      await mahnungZuruecknehmen(context, m);
    } catch (e) {
      _meldung('Zurücknehmen fehlgeschlagen: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) {
        ref.invalidate(rechnungenStreamProvider);
        ref.invalidate(mahnlaufProvider);
      }
    }
  }

  // ─── Listen ───

  Widget _rechnungZeile(Rechnung r, {bool frist = false}) {
    final anzeige = ref.watch(betriebAnzeigeMapProvider)[r.betriebId] ?? '—';
    final fristBis = r.mahnFristBis;
    final zusatz = frist
        ? '${_statusText(r.zahlungsstatus)}${fristBis != null ? ' · Frist bis ${_datum(fristBis)}' : ''}'
        : '${_datum(r.rechnungsdatum)} · CHF ${r.betragBrutto.toStringAsFixed(2)}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/rechnungen/${r.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$anzeige · ${r.rechnungsnummer ?? '—'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    zusatz,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ─── Eskalation (Mahnwesen Teil 2) ───

  /// Karte «Heineken einschalten»: Betrieb, abgelaufene letzte Mahnungen,
  /// Knopf «Mahnfall eröffnen». Gesperrte Betriebe zeigen den Grund wie bei
  /// «Mahnfällig» und keinen Knopf.
  Widget _eskalationKarte(MahnBetrieb b) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: b.gesperrt ? AppColors.error.withAlpha(120) : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.anzeige, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${b.faellig.length} Rechnung(en) · '
                    'CHF ${b.summeFaellig.toStringAsFixed(2)} · letzte Mahnung abgelaufen',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (b.gesperrt)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  b.sperrgrund!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            for (final p in b.faellig)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/rechnungen/${p.rechnung.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p.rechnung.rechnungsnummer ?? '—'} · '
                          '${_datum(p.rechnung.rechnungsdatum)}'
                          '${p.rechnung.mahnFristBis != null ? ' · Frist bis ${_datum(p.rechnung.mahnFristBis!)}' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        'CHF ${p.rechnung.betragBrutto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            if (!b.gesperrt)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TapKnopf(
                    text: 'Mahnfall eröffnen',
                    icon: Icons.gavel,
                    primaer: true,
                    laeuft: _laeuftFuer == b.betriebId,
                    onTap: _laeuftFuer != null ? null : () => _fallVorschau(b),
                  ),
                ),
              ),
          ],
        ),
      );

  /// Vorschau «Mahnfall eröffnen»: Empfänger (Heineken-Kontakt «Mahnwesen»),
  /// Testmodus, Rechnungen mit Total — erst der zweite Klick eröffnet.
  Future<void> _fallVorschau(MahnBetrieb b) async {
    final rechnungen = b.faellig.map((p) => p.rechnung).toList();
    if (rechnungen.isEmpty) return;
    setState(() => _laeuftFuer = b.betriebId);
    BetriebLocal? betrieb;
    String? kontaktMail;
    String? kontaktName;
    try {
      betrieb = await BetriebRepository.getByServerId(b.betriebId);
      final k = await KontaktRepository.getHeinekenZuweisung('mahnwesen');
      final m = k?.email?.trim() ?? '';
      kontaktMail = m.isEmpty ? null : m;
      if (k != null) kontaktName = '${k.vorname} ${k.nachname ?? ''}'.trim();
    } catch (e) {
      _meldung('Vorschau nicht möglich: ${kurzeFehlermeldung(e)}');
      return;
    } finally {
      if (mounted) setState(() => _laeuftFuer = null);
    }
    if (betrieb == null) {
      _meldung('Betrieb nicht gefunden.');
      return;
    }
    if (!mounted) return;
    final test = !MailConfig.istScharf('mahnwesen');
    final total = rechnungen.fold(0.0, (s, r) => s + r.betragBrutto);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mahnfall eröffnen — ${b.anzeige}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _vorschauZeile(
                'Empfänger',
                kontaktMail == null
                    ? 'Kein Heineken-Kontakt «Mahnwesen» hinterlegt — unter '
                        'Heineken → Zuweisungen erfassen'
                    : '${kontaktName != null && kontaktName.isNotEmpty ? '$kontaktName, ' : ''}'
                        '$kontaktMail (Heineken)',
              ),
              if (test && kontaktMail != null)
                _vorschauZeile('', 'Testmodus: geht an ${MailConfig.testEmpfaenger}'),
              _vorschauZeile(
                'Beilagen',
                '${kontoauszugJahre(rechnungen).map((j) => 'Kontoauszug $j').join(' · ')} · '
                '${rechnungen.length} Rechnungskopie(n)',
              ),
              const SizedBox(height: 8),
              const Text('Rechnungen', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final r in rechnungen)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${r.rechnungsnummer ?? '—'} · ${_datum(r.rechnungsdatum)} · '
                    'CHF ${r.betragBrutto.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Total CHF ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TapKnopf(
                    text: 'Abbrechen',
                    primaer: false,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                  TapKnopf(
                    text: 'Mahnfall eröffnen',
                    primaer: true,
                    onTap: kontaktMail == null ? null : () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _fallEroeffnen(b, betrieb, rechnungen);
  }

  Future<void> _fallEroeffnen(
    MahnBetrieb b,
    BetriebLocal betrieb,
    List<Rechnung> rechnungen,
  ) async {
    setState(() => _laeuftFuer = b.betriebId);
    try {
      // Review Teil 2, I-4: wie beim Erstellen einer Mahnung den Mahnlauf
      // frisch aus der DB bauen und prüfen — zwischen Vorschau und Klick
      // kann ein Auszug eingelesen oder eine Zahlung gebucht worden sein.
      _neuLaden();
      final frisch = await ref.read(mahnlaufProvider.future);
      final p = pruefeVorEskalation(
        frisch: frisch,
        betriebId: b.betriebId,
        rechnungIds: [for (final r in rechnungen) r.id],
      );
      if (p.fehler != null) {
        _meldung(p.fehler!);
        return;
      }
      final ids = {for (final r in rechnungen) r.id};
      final fall = await MahnfallService.eroeffnen(
        betrieb: betrieb,
        rechnungen: [
          for (final x in p.karte!.faellig)
            if (ids.contains(x.rechnung.id)) x.rechnung,
        ],
      );
      if (mounted) await context.push('/rechnungen/mahnfall/${fall.id}');
    } on MahnfallFehler catch (f) {
      if (!mounted) return;
      final fallId = f.fallId;
      final zumFall = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(fallId != null ? 'Mahnfall angelegt, Mail fehlgeschlagen' : 'Kein Mahnfall eröffnet'),
          content: Text(f.meldung),
          actions: [
            if (fallId != null)
              TapKnopf(text: 'Zum Fall', onTap: () => Navigator.pop(ctx, true)),
            TapKnopf(text: 'Schliessen', primaer: false, onTap: () => Navigator.pop(ctx, false)),
          ],
        ),
      );
      if (zumFall == true && fallId != null && mounted) {
        await context.push('/rechnungen/mahnfall/$fallId?mailFehler=1');
      }
    } catch (e) {
      _meldung('Mahnfall fehlgeschlagen: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) {
        setState(() => _laeuftFuer = null);
        ref.invalidate(mahnlaufProvider);
      }
    }
  }

  /// Zeile eines offenen Mahnfalls: Betrieb, Status, Anzahl, Summe der noch
  /// offenen Fall-Rechnungen. Tap öffnet das Arbeitsblatt des Falls.
  Widget _fallZeile(Mahnfall f, List<Rechnung> imFall) {
    final anzeige = ref.watch(betriebAnzeigeMapProvider)[f.betriebId] ?? '—';
    final summe = imFall
        .where((r) => f.rechnungIds.contains(r.id))
        .fold(0.0, (s, r) => s + r.betragBrutto);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/rechnungen/mahnfall/${f.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$anzeige${f.test ? ' · TEST' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${mahnfallStatusText(f)} · ${f.rechnungIds.length} Rechnung(en) · '
                    'CHF ${summe.toStringAsFixed(2)} offen',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ─── Bausteine ───

  Widget _titel(String text, int anzahl) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          '$text ($anzahl)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );

  Widget _hinweis(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _kasten({required Color farbe, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: farbe.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: farbe.withAlpha(90)),
        ),
        child: child,
      );

  Widget _vorschauZeile(String label, String wert) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            Expanded(child: Text(wert, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  void _meldung(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _kanalText(MahnKanal k) => switch (k.kanal) {
      'mail' => 'Mail',
      'mail_und_druck' => 'Mail + PDF zum Einschreiben',
      _ => 'Druck — keine Mailadresse',
    };

String _statusText(String s) => switch (s) {
      'erinnert' => 'Erinnert',
      'mahnung_1' => '1. Mahnung',
      'mahnung_2' => 'Letzte Mahnung',
      _ => s,
    };
