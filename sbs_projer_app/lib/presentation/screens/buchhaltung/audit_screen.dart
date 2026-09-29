import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/delkredere.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/rueckstellung_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/gefahr_rueckfrage.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/steuerrueckstellung_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;

/// Abschlussprüfung: alle Regeln je Geschäftsjahr, gruppiert und nach Ampel
/// sortiert. Grüne Befunde sind eingeklappt — offen bleibt, was zu tun ist.
class AuditScreen extends ConsumerStatefulWidget {
  final int? jahr;
  const AuditScreen({super.key, this.jahr});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  /// Unsinniges Jahr aus der URL (altes Lesezeichen, Tippfehler) fällt aufs
  /// laufende Jahr zurück, statt eine leere Prüfung zu zeigen.
  late int _jahr = _gueltig(widget.jahr) ? widget.jahr! : DateTime.now().year;
  bool _grueneZeigen = false;

  static bool _gueltig(int? j) =>
      j != null && j >= kSteuerJahrAb && j <= DateTime.now().year;

  @override
  void didUpdateWidget(AuditScreen alt) {
    super.didUpdateWidget(alt);
    // Zurück-Navigation oder neuer ?jahr=-Link auf derselben Seite: der State
    // überlebt, das Jahr muss deshalb nachgezogen werden.
    if (widget.jahr != alt.jahr && _gueltig(widget.jahr)) {
      setState(() => _jahr = widget.jahr!);
    }
  }

  Color _farbe(PruefStatus s) => switch (s) {
    PruefStatus.rot => AppColors.error,
    PruefStatus.gelb => AppColors.warning,
    PruefStatus.gruen => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(abschlussPruefungProvider(_jahr));
    return Scaffold(
      appBar: AppBar(title: const Text('Abschlussprüfung')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterDropdown<int>(
                    hint: 'Jahr',
                    value: _jahr,
                    nullable: false,
                    isExpanded: true,
                    options: [
                      for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--)
                        (j, '$j'),
                    ],
                    onChanged: (v) => setState(() => _jahr = v ?? _jahr),
                  ).build(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              // Nach jeder Buchung rechnet die Prüfung neu — ohne das fiele
              // die Liste dabei jedes Mal auf den Spinner zurück.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _fehler(e),
              data: (befunde) {
                int n(PruefStatus s) =>
                    befunde.where((b) => b.status == s).length;
                final gruppen = <String, List<Pruefbefund>>{};
                for (final b in befunde) {
                  if (b.status == PruefStatus.gruen && !_grueneZeigen) continue;
                  gruppen.putIfAbsent(b.gruppe, () => []).add(b);
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    InkWell(
                      onTap: () =>
                          setState(() => _grueneZeigen = !_grueneZeigen),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Wrap statt fester Texte: bei 375 px Breite und
                            // zweistelligen Zählern läuft eine Row sonst über.
                            Expanded(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _zaehler(PruefStatus.rot, n, 'rot'),
                                  _zaehler(PruefStatus.gelb, n, 'gelb'),
                                  _zaehler(PruefStatus.gruen, n, 'grün'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _grueneZeigen
                                  ? 'grüne ausblenden'
                                  : 'grüne zeigen',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (gruppen.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('Alles im Lot — keine offenen Befunde.'),
                        ),
                      ),
                    for (final g in gruppen.entries)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Divider(),
                            for (final b in g.value) _zeile(b),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _delkredereLaeuft = false;
  bool _rueckstellungLaeuft = false;

  /// Das Jahr, dessen Abschluss gerade ansteht (Vorjahr): Nur dort gehen die
  /// Abschlussbuchungen (Delkredere, Rückstellung) per 31.12. Im laufenden
  /// Jahr gibt es noch kein 31.12. mit fertigen Zahlen; ältere Jahre
  /// (2019–2024) sind eingereicht und veranlagt — dort zeigte der Knopf
  /// bei roten Zeilen zum Buchen in eine abgeschlossene Periode (Review W1).
  bool get _abschlussJahr => _jahr == DateTime.now().year - 1;

  bool get _laufendesJahr => _jahr == DateTime.now().year;

  void _meldung(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Journal frisch laden, bevor ein Abschlussbetrag gerechnet wird.
  ///
  /// WARUM: Andere Schritte buchen, ohne den Journal-Stream zu erneuern
  /// (z. B. «Jahrgang abschreiben») — Delkredere und Rückstellung stünden
  /// sonst auf einem veralteten 1100-Saldo bzw. Gewinn.
  Future<List<Buchung>> _frischesJournal() {
    ref.invalidate(buchungenStreamProvider);
    return ref.read(buchungenStreamProvider.future);
  }

  /// Nach einer Buchung: Journal, Bilanz und Prüfung neu rechnen. Der
  /// Stream zuerst — die Prüfung liest das Journal aus ihm.
  void _nachBuchung(int jahr) {
    ref.invalidate(buchungenStreamProvider);
    ref.invalidate(debitorenUebersichtProvider);
    ref.invalidate(abschlussPruefungProvider(jahr));
  }

  /// Delkredere (1109) auf 5 % der Debitoren (1100) — mit Rückfrage, weil es
  /// eine Aufwandbuchung auf 3805 erzeugt. Abschlussjahr: per 31.12.
  /// ([_delkredereStichtagBuchen]); laufendes Jahr: heute gegen den heutigen
  /// Saldo (wie bisher).
  Future<void> _delkredereBuchen() async {
    if (_abschlussJahr) return _delkredereStichtagBuchen(_jahr);
    if (!_laufendesJahr) return;
    setState(() => _delkredereLaeuft = true);
    try {
      ref.invalidate(debitorenUebersichtProvider);
      final d = await ref.read(debitorenUebersichtProvider.future);
      final debitoren = d['debitoren_total'] ?? 0;
      final ziel = delkredereZiel(debitoren);
      if (!mounted) return;
      final ok = await gefahrRueckfrage(
        context,
        titel: 'Delkredere auf 5 % buchen?',
        text: 'Debitoren 1100: CHF ${chf(debitoren)}\n'
            'Delkredere 1109 neu: CHF ${chf(ziel)} '
            '(bisher CHF ${chf(d['delkredere'] ?? 0)})\n\n'
            'Die Differenz wird heute gegen 3805 gebucht.',
        bestaetigen: 'Buchen',
      );
      if (!ok) return;
      await AbschreibungService.delkredereSetzen(
        zielWertberichtigung: ziel,
        datum: DateTime.now(),
      );
      _nachBuchung(_jahr);
      _meldung('Delkredere auf CHF ${chf(ziel)} gesetzt');
    } catch (e) {
      _meldung('Fehler: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) setState(() => _delkredereLaeuft = false);
    }
  }

  /// Jahresabschluss Schritt E: Delkredere per 31.12.[jahr] auf 5 % der
  /// Debitoren per 31.12.[jahr] — dieselben Saldi, die die Regel zeigt.
  Future<void> _delkredereStichtagBuchen(int jahr) async {
    setState(() => _delkredereLaeuft = true);
    try {
      final s = delkredereStichtag(await _frischesJournal(), jahr);
      final b = delkredereBuchung(
        debitoren: s.debitoren,
        bisher: s.wertberichtigung,
      );
      if (b.betrag < 0.01) {
        _meldung(
          'Delkredere per 31.12.$jahr stimmt schon (CHF ${chf(s.ziel)})',
        );
        return;
      }
      if (!mounted) return;
      final ok = await gefahrRueckfrage(
        context,
        titel: 'Delkredere per 31.12.$jahr buchen?',
        text: 'Debitoren 1100 per 31.12.$jahr: CHF ${chf(s.debitoren)}\n'
            'Delkredere 1109 neu: CHF ${chf(s.ziel)} '
            '(bisher CHF ${chf(s.wertberichtigung)})\n\n'
            'Buchung per 31.12.$jahr gegen 3805: CHF ${chf(b.betrag)} '
            '(${b.aufbau ? '3805 an 1109' : '1109 an 3805'}). Als '
            'Abschlussbuchung gilt $jahr danach als abgeschlossen.',
        bestaetigen: 'Buchen',
      );
      if (!ok) return;
      await AbschreibungService.delkredereSetzenPerStichtag(
        jahr: jahr,
        debitorenPerStichtag: s.debitoren,
        wertberichtigungPerStichtag: s.wertberichtigung,
      );
      _nachBuchung(jahr);
      _meldung('Delkredere per 31.12.$jahr auf CHF ${chf(s.ziel)} gesetzt');
    } catch (e) {
      _meldung('Fehler: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) setState(() => _delkredereLaeuft = false);
    }
  }

  /// Jahresabschluss Schritt D: Steuerrückstellung per 31.12. des gewählten
  /// Jahres — Dialog mit Vorschlag, dann die Differenz buchen.
  Future<void> _rueckstellungBuchen() async {
    final jahr = _jahr;
    setState(() => _rueckstellungLaeuft = true);
    try {
      final lage = SteuerrueckstellungService.lage(
        await _frischesJournal(),
        jahr,
      );
      if (!mounted) return;
      final eingabe = await zeigeRueckstellungDialog(
        context,
        jahr: jahr,
        lage: lage,
      );
      if (eingabe == null) return;
      await SteuerrueckstellungService.buchen(
        jahr: jahr,
        ziel: eingabe.ziel,
        gebucht: lage.gebucht,
        begruendung: eingabe.begruendung,
      );
      _nachBuchung(jahr);
      _meldung(
        'Steuerrückstellung $jahr auf CHF ${chf(eingabe.ziel)} gesetzt',
      );
    } catch (e) {
      _meldung('Fehler: ${kurzeFehlermeldung(e)}');
    } finally {
      if (mounted) setState(() => _rueckstellungLaeuft = false);
    }
  }

  Widget _fehler(Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Fehler: $e', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => ref.invalidate(abschlussPruefungProvider(_jahr)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Erneut laden',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _zaehler(PruefStatus s, int Function(PruefStatus) n, String label) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [_punkt(s), const SizedBox(width: 4), Text('${n(s)} $label')],
      );

  Widget _punkt(PruefStatus s) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _farbe(s)),
  );

  Widget _zeile(Pruefbefund b) => InkWell(
    onTap: b.aktionRoute == null ? null : () => context.push(b.aktionRoute!),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _punkt(b.status),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.titel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (b.ist.isNotEmpty || b.soll.isNotEmpty)
                  Text(
                    'Ist: ${b.ist}${b.soll.isEmpty ? '' : ' · Soll: ${b.soll}'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (b.hinweis.isNotEmpty)
                  Text(
                    b.hinweis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                // Früher im Debitoren-Header der Rechnungsliste, ohne
                // Rückfrage (Analyse 25.09.2026 Befund E). Seit 29.09.2026
                // auch im Abschlussjahr: dort per 31.12. gegen die Debitoren
                // per 31.12. (Jahresabschluss Schritt E). Ältere Jahre ohne
                // Knopf (W1).
                if (b.regelId == 'delkredere' &&
                    b.status != PruefStatus.gruen &&
                    (_abschlussJahr || _laufendesJahr))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TapKnopf(
                      text: _abschlussJahr
                          ? 'Delkredere per 31.12.$_jahr buchen'
                          : 'Delkredere auf 5 % buchen',
                      icon: Icons.percent,
                      primaer: false,
                      laeuft: _delkredereLaeuft,
                      onTap: _delkredereBuchen,
                    ),
                  ),
                // Schritt D: auch bei grüner Zeile, weil eine gebuchte
                // Rückstellung nachgeführt werden kann (2025: 4'000 → 2'800
                // nach Abschreibung Jahrgang 2020). Nur im Abschlussjahr —
                // vorher steht der Gewinn nicht fest, ältere Jahre sind
                // veranlagt (W1).
                if (b.regelId == 'rueckstellung' && _abschlussJahr)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TapKnopf(
                      key: const Key('rueckstellung_knopf'),
                      text: 'Rückstellung buchen',
                      icon: Icons.account_balance,
                      primaer: false,
                      laeuft: _rueckstellungLaeuft,
                      onTap: _rueckstellungBuchen,
                    ),
                  ),
              ],
            ),
          ),
          if (b.aktionRoute != null)
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    ),
  );
}
