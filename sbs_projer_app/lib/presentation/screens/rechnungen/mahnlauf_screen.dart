import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnschreiben_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnlauf_provider.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/widgets/mahnverlauf.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart'
    show MahnPosten;
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';
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

  bool get _einzel => widget.rechnungId != null;

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
                if (!MailConfig.istScharf('mahnwesen')) _testmodusZeile(),
                const SizedBox(height: 12),
                _titel('Mahnfällig', daten.betriebe.length),
                if (daten.betriebe.isEmpty) _leerHinweis(daten),
                for (final b in daten.betriebe) _betriebKarte(b),
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
    // Prüfliste und Auszüge frisch holen — eben eingelesene Auszüge oder
    // zugeordnete Zahlungen müssen die Sperren sofort lösen bzw. setzen.
    ref.invalidate(camtPrueflisteProvider);
    ref.invalidate(camtDateienProvider);
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
      if (d.zahlungGebucht.isNotEmpty) {
        text = 'Auf diese Rechnung ist eine Zahlung gebucht — nicht mahnen.';
      } else if (d.erstZustellen.isNotEmpty) {
        text = 'Diese Rechnung ist nicht nachweislich zugestellt.';
      } else if (d.bankGesperrt) {
        text = 'Erst nach dem Einlesen des aktuellen Bankauszugs prüfbar.';
      } else if (d.inFrist.isNotEmpty) {
        text = 'Die Frist der letzten Mahnung läuft noch.';
      } else {
        text = 'Diese Rechnung ist derzeit nicht mahnfällig '
            '(Fälligkeit + $kErinnerungNachTagen Tage, gemessen am Bankauszug).';
      }
    } else {
      text = d.bankGesperrt
          ? 'Erst nach dem Einlesen des aktuellen Bankauszugs prüfbar.'
          : 'Nichts mahnfällig.';
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
                          'CHF ${b.summeFaellig.toStringAsFixed(2)} · ${b.hoechste.titel}',
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
    String? mail;
    try {
      betrieb = await BetriebRepository.getByServerId(b.betriebId);
      final ra = await BetriebRechnungsadresseRepository.getByBetrieb(b.betriebId);
      // Dieselbe Reihenfolge wie `MahnlaufService.erstellen`: Rechnungs-
      // adresse, sonst Betrieb.
      final raMail = (ra?.email ?? '').trim();
      final bMail = (betrieb?.email ?? '').trim();
      mail = raMail.isNotEmpty ? raMail : (bMail.isNotEmpty ? bMail : null);
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
    final druck = mail == null || stufe == MahnStufe.letzte;
    final kanal = mail == null
        ? 'Druck — keine Mailadresse'
        : (druck ? 'Mail + PDF zum Einschreiben' : 'Mail');
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
              _vorschauZeile('Empfänger', mail ?? 'keine Mailadresse'),
              if (test && mail != null)
                _vorschauZeile('', 'Testmodus: geht an ${MailConfig.testEmpfaenger}'),
              _vorschauZeile('Kanal', kanal),
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
                  if (mail != null) '${posten.length} Rechnungskopie(n) per Mail',
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
  /// Sicherungen: Zwischen Anzeige und Klick kann ein Auszug eingelesen,
  /// eine Zahlung zugeordnet oder eine Rechnung bezahlt worden sein. Weicht
  /// irgendetwas ab, wird nichts erstellt (Oberstes Ziel: nie Bezahltes
  /// mahnen).
  Future<void> _erstellen(
    MahnBetrieb alt,
    BetriebLocal betrieb,
    List<MahnPosten> posten,
  ) async {
    setState(() => _laeuftFuer = alt.betriebId);
    try {
      _neuLaden();
      final frisch = await ref.read(mahnlaufProvider.future);
      final karte = frisch.betriebe.where((k) => k.betriebId == alt.betriebId).firstOrNull;
      if (frisch.bankGesperrt || karte == null || karte.gesperrt) {
        _meldung('Stand hat sich geändert — nichts erstellt. Bitte neu prüfen.');
        return;
      }
      final geprueft = <MahnPosten>[];
      for (final p in posten) {
        final f = karte.faellig.where((k) => k.rechnung.id == p.rechnung.id).firstOrNull;
        // Zusätzlich direkt aus der DB: Der Rechnungs-Stream kann einen
        // Moment hinterherhinken.
        final db = await RechnungRepository.getById(p.rechnung.id);
        final stufeDb =
            db == null ? null : faelligeStufe(db, stichtag: frisch.letzterAuszug!);
        if (f == null || db == null || stufeDb != p.stufe) {
          _meldung('${p.rechnung.rechnungsnummer ?? 'Rechnung'} ist nicht mehr '
              'mahnfällig — nichts erstellt. Bitte neu prüfen.');
          return;
        }
        geprueft.add((rechnung: db, stufe: stufeDb!));
      }

      final erg = await MahnlaufService.erstellen(
        betrieb: betrieb,
        posten: geprueft,
        offeneDesBetriebs: karte.offeneImMahnbereich,
        rechnungenDesJahres: karte.rechnungenDesJahres,
      );
      if (erg.druckPdf != null) {
        final name = betrieb.name.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüéè]+'), '_');
        await oeffnePdfImNeuenTab(erg.druckPdf!, 'Mahnung_$name.pdf');
      }
      if (mounted) {
        await _ergebnisZeigen(erg);
      }
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
                  child: Text('Das Druck-PDF ist in einem neuen Tab geöffnet.'),
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
            TapKnopf(text: 'OK', onTap: () => Navigator.pop(ctx)),
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

String _statusText(String s) => switch (s) {
      'erinnert' => 'Erinnert',
      'mahnung_1' => '1. Mahnung',
      'mahnung_2' => 'Letzte Mahnung',
      _ => s,
    };
