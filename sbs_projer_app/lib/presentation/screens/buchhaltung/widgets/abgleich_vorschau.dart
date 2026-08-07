import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/zahlungsdifferenz_text.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/abgleich_fenster.dart';
import 'package:sbs_projer_app/core/util/zahlung_paarung.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/auto_match_tile.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/paar_badge.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';
import 'package:sbs_projer_app/services/camt/vermerk_parser.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wiederverwendbare Ergebnis-Vorschau für den camt-Forderungsabgleich:
/// Kopf-Übersicht (KPIs) + vier klappbare Gruppen (🟢 Auto / 🟡 Manuell /
/// ⚪ Nicht zugeordnet / 🔴 Keine Zahlung) inkl. aller Verbuchungs- und
/// Zuordnungs-Dialoge. Eingebettet sowohl im Standalone-Abgleich-Screen als
/// auch (später) im Import-Screen.
///
/// Das übergebene [ergebnis] wird beim Verbuchen in-place mutiert (gewollt),
/// ebenso der [alleOffenen]-Pool für die ⚪-Zuordnung.
class AbgleichVorschau extends ConsumerStatefulWidget {
  final AbgleichErgebnis ergebnis; // wird beim Verbuchen in-place mutiert
  final List<Rechnung> alleOffenen; // Pool für die ⚪-Zuordnung
  final Map<String, String> betriebName; // id → Name
  final EdgeInsets padding;

  const AbgleichVorschau({
    super.key,
    required this.ergebnis,
    required this.alleOffenen,
    required this.betriebName,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  });

  @override
  ConsumerState<AbgleichVorschau> createState() => _AbgleichVorschauState();
}

class _AbgleichVorschauState extends ConsumerState<AbgleichVorschau> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  // Auch bei Auto-Treffern den Zahlernamen als Alias des Betriebs lernen.
  // Standard an; pro Abgleich/Import abschaltbar (Schutz gegen Festschreiben
  // eines falschen unscharfen Treffers).
  bool _autoLernen = true;

  @override
  Widget build(BuildContext context) {
    final erg = widget.ergebnis;
    final autoSumme = erg.auto.fold<double>(0, (s, t) => s + t.gutschrift.amount);
    final unbekanntSumme =
        erg.unbekannteGutschriften.fold<double>(0, (s, g) => s + g.amount);
    return ListView(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _uebersicht(erg, autoSumme, unbekanntSumme),

        // 🟢 Auto-gematcht
        _GruppeCard(
          emoji: '🟢',
          titel: 'Auto-gematcht',
          anzahl: erg.auto.length,
          summe: erg.auto.isEmpty ? null : autoSumme,
          farbe: AppColors.success,
          initiallyExpanded: true,
          children: [
            if (erg.auto.isNotEmpty)
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                controlAffinity: ListTileControlAffinity.leading,
                value: _autoLernen,
                onChanged: (v) => setState(() => _autoLernen = v ?? true),
                title: const Text('Zahlernamen aus Auto-Treffern lernen',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                    'Schreibt den Einzahler-Namen als Alias des Betriebs fest.',
                    style: TextStyle(fontSize: 11)),
              ),
            if (erg.auto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _verbucheAlle,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Alle verbuchen'),
                  ),
                ),
              ),
            for (final t in erg.auto) _autoZeile(t),
          ],
        ),

        // 🟡 Manuell zuordnen
        _GruppeCard(
          emoji: '🟡',
          titel: 'Manuell zuordnen',
          anzahl: erg.manuell.length,
          summe: null,
          farbe: AppColors.warning,
          initiallyExpanded: true,
          children: [
            for (final f in erg.manuell)
              ListTile(
                title: Text(f.betriebName),
                subtitle: Text(
                  '${f.gutschriften.length} Zahlung(en), '
                  '${f.forderungen.length} offene Forderung(en)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _oeffneManuell(f),
              ),
          ],
        ),

        // ⚪ Nicht zugeordnet (benannte Gutschriften ohne offene Forderung)
        _GruppeCard(
          emoji: '⚪',
          titel: 'Nicht zugeordnet',
          anzahl: erg.unbekannteGutschriften.length,
          summe: erg.unbekannteGutschriften.isEmpty ? null : unbekanntSumme,
          farbe: AppColors.textSecondary,
          initiallyExpanded: true,
          children: _unbekanntZeilen(erg.unbekannteGutschriften),
        ),

        // 🔴 «Keine Zahlung gefunden» bewusst NICHT mehr angezeigt (Entscheid
        // Daniel 07.08.2026): offene Rechnungen ohne Zahlung sind für den
        // Abgleich irrelevant — dafür gibt es den Forderungen-Hub.
      ],
    );
  }

  /// Kompakte Kopf-Übersicht: drei KPIs (umbrechend auf Smartphone).
  Widget _uebersicht(
    AbgleichErgebnis erg,
    double autoSumme,
    double unbekanntSumme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Kpi(
                  farbe: AppColors.success,
                  label: 'Auto',
                  anzahl: erg.auto.length,
                  sub: '${chf(autoSumme)} CHF',
                ),
                _Kpi(
                  farbe: AppColors.warning,
                  label: 'Manuell',
                  anzahl: erg.manuell.length,
                ),
                _Kpi(
                  farbe: AppColors.textSecondary,
                  label: 'Nicht zugeordnet',
                  anzahl: erg.unbekannteGutschriften.length,
                  sub: '${chf(unbekanntSumme)} CHF',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Baut die Beschreibung + delegiert an das getestete, responsive
  /// [AutoMatchTile] (Betrag/Beschreibung strikt einzeilig, Details darunter
  /// mehrzeilig — alle Kontroll-Infos auf einen Blick, Wunsch Daniel 07.08.).
  Widget _autoZeile(AutoTreffer t) {
    final betrieb = widget.betriebName[t.forderungen.first.betriebId] ?? '';
    final teile = [
      if (betrieb.isNotEmpty) betrieb,
      'Zahlung ${_dateFormat.format(t.gutschrift.bookingDate)}',
    ];
    // Kontroll-Block: Zahler + Treffer-Grund, jede Rechnung mit Nummer, Datum
    // und Betrag, zuletzt die Bank-Bemerkung.
    final zahler = effektiverZahlername(
        partyName: t.gutschrift.partyName,
        additionalInfo: t.gutschrift.additionalInfo);
    final remit = t.gutschrift.remittanceInfo?.trim();
    final kopf = [
      if (zahler != null) 'Zahler: $zahler',
      if (t.grund.isNotEmpty) t.grund,
    ].join(' · ');
    final detail = [
      if (kopf.isNotEmpty) kopf,
      for (final r in t.forderungen)
        'Rechnung ${r.rechnungsnummer ?? '?'} vom '
            '${_dateFormat.format(r.rechnungsdatum)} — '
            '${r.betragBrutto.toStringAsFixed(2)} CHF',
      if (remit != null && remit.isNotEmpty) 'Bemerkung: $remit',
    ].join('\n');
    return AutoMatchTile(
      betrag: '${t.gutschrift.amount.toStringAsFixed(2)} CHF',
      beschreibung: teile.join(' · '),
      detail: detail.isEmpty ? null : detail,
      onVerbuchen: () => _verbuche(t),
      // Falscher Treffer (z.B. Betreiber-Name)? Neu zuordnen + Alias lernen.
      onKorrigieren: () => _ordneZu(t.gutschrift, korrigiereAuto: t),
    );
  }

  /// Zusatz-Infos zu einer Gutschrift: Zahler-Name, Mitteilung, und bei
  /// Schalter-/Automaten-/Posteinzahlung der rohe Bank-Text (Ort/Datum/Zeit).
  /// Null, wenn keine über Betrag/Datum hinausgehende Info vorhanden ist.
  String? _zahlungInfo(CamtTransaction g) {
    final teile = <String>[];
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    if (name != null) teile.add(name);
    final adr = g.partyAddress.trim();
    if (adr.isNotEmpty) teile.add(adr);
    final remit = g.remittanceInfo?.trim();
    if (remit != null && remit.isNotEmpty) teile.add('Bemerkung: $remit');
    // Kein Name extrahierbar (z.B. Schalter-/Automaten-/Posteinzahlung) →
    // rohen AddtlNtryInf-Text zeigen (enthält bei Automaten Ort/Datum/Zeit).
    if (name == null) {
      final addtl = g.additionalInfo?.trim();
      if (addtl != null && addtl.isNotEmpty) teile.add(addtl);
    }
    return teile.isEmpty ? null : teile.join(' · ');
  }

  /// Wie [_zahlungInfo], aber ohne die Adresse. In den Zuordnungs-Dialogen ist
  /// der Platz knapp und die Adresse hilft beim Zuordnen nicht — entscheidend
  /// sind Zahlername und Bemerkung (Rechnungsnummer/Datum/Betriebnummer).
  String? _zahlungInfoKurz(CamtTransaction g) {
    final teile = <String>[];
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    if (name != null) teile.add(name);
    final remit = g.remittanceInfo?.trim();
    if (remit != null && remit.isNotEmpty) teile.add('Bemerkung: $remit');
    if (name == null) {
      final addtl = g.additionalInfo?.trim();
      if (addtl != null && addtl.isNotEmpty) teile.add(addtl);
    }
    return teile.isEmpty ? null : teile.join(' · ');
  }

  /// Untertitel-Widget für die Zuordnungs-Dialoge: kompakte Kurzfassung,
  /// der vollständige Text (inkl. Adresse) steckt im Tooltip — langer Druck
  /// bzw. Maus-Hover zeigt ihn, ohne dass die Zeile höher wird.
  Widget? _zahlungInfoText(CamtTransaction g) {
    final kurz = _zahlungInfoKurz(g);
    if (kurz == null) return null;
    final voll = _zahlungInfo(g) ?? kurz;
    return Tooltip(
      message: voll,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 12),
      child: Text(
        kurz,
        style: const TextStyle(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Fragt nach, wenn eine Rechnung NACH dem Zahlungseingang datiert ist —
  /// die konnte der Kunde damals nicht bezahlen (Fall Marsöl 28.07.2026:
  /// Zahlung 25.03. auf Rechnung vom 12.05., obwohl ältere offene Posten
  /// vorlagen). Keine harte Sperre: Vorauszahlungen gibt es. Gibt true zurück,
  /// wenn gebucht werden darf.
  ///
  /// Geprüft wird je Rechnung gegen die Zahlung, die sie nach der Paarung
  /// tatsächlich begleicht — bei Mehrfachauswahl also nicht pauschal gegen die
  /// erste Gutschrift.
  Future<bool> _pruefeDatumsfolge(
      List<CamtTransaction> gutschriften, Iterable<Rechnung> forderungen) async {
    if (gutschriften.isEmpty) return true;
    final paarung = paareMitBetrag<CamtTransaction>(
      zahlungen: gutschriften,
      datumVon: (g) => g.bookingDate,
      betragVon: (g) => g.amount,
      forderungen: [
        for (final r in forderungen)
          (id: r.id, rechnungsdatum: r.rechnungsdatum, betrag: r.betragBrutto)
      ],
    );
    final zeilen = <String>[];
    for (final r in forderungen) {
      final zahlung = paarung[r.id] ?? gutschriften.first;
      final treffer = rechnungenNachZahlung(zahlung.bookingDate, [
        (
          bezeichnung: r.rechnungsnummer ?? r.id,
          rechnungsdatum: r.rechnungsdatum,
        )
      ]);
      if (treffer.isNotEmpty) {
        zeilen.add('${treffer.first} — Zahlung vom '
            '${_datumKurz(zahlung.bookingDate)}, Rechnung vom '
            '${_datumKurz(r.rechnungsdatum)}');
      }
    }
    if (zeilen.isEmpty || !mounted) return zeilen.isEmpty;

    final trotzdem = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnung jünger als die Zahlung'),
        content: Text(
          '${zeilen.length == 1 ? 'Diese Rechnung wurde' : 'Diese Rechnungen wurden'} '
          'erst nach dem Zahlungseingang ausgestellt:\n\n${zeilen.join('\n')}\n\n'
          'Das ist meist ein Fehlgriff — vermutlich gehört die Zahlung zu '
          'einer älteren offenen Rechnung. Trotzdem zuordnen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trotzdem zuordnen'),
          ),
        ],
      ),
    );
    return trotzdem == true;
  }

  /// Schalter, der Forderungen älter als ein Jahr in die Auswahl holt.
  ///
  /// Der Abgleich arbeitet standardmässig nur mit Forderungen aus dem letzten
  /// Jahr — sonst stehen bei einem Betrieb zehn gleich hohe Altposten zur
  /// Auswahl und eine neue Zahlung landet auf einer Rechnung von 2019. Zahlt
  /// ein Kunde doch erst später, lassen sich die älteren hier zuschalten
  /// (Wunsch Daniel 28.07.2026).
  Widget _altpostenSchalter({
    required bool an,
    required int anzahl,
    required VoidCallback umschalten,
  }) {
    return InkWell(
      onTap: umschalten,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(an ? Icons.expand_less : Icons.expand_more,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                an
                    ? 'Ältere ausblenden (über ein Jahr)'
                    : '$anzahl Forderungen älter als ein Jahr einblenden',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _datumKurz(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Live-Paarung für die Zuordnungs-Dialoge: Welche gewählte Zahlung
  /// begleicht welche gewählte Forderung? Dieselbe Logik wie beim Verbuchen
  /// ([paareMitBetrag]) — die Anzeige zeigt exakt, was gebucht würde.
  ///
  /// Rückgabe: Paar-Nummer je Gutschrift (Reihenfolge = Anzeige-Reihenfolge)
  /// und je Forderungs-Id die Nummer der zugeordneten Gutschrift.
  ({Map<CamtTransaction, int> gut, Map<String, int> ford}) _paarNummern({
    required List<CamtTransaction> gutsAnzeige,
    required Set<CamtTransaction> gewaehlteGuts,
    required Set<Rechnung> gewaehlteForderungen,
  }) {
    final selGuts =
        [for (final g in gutsAnzeige) if (gewaehlteGuts.contains(g)) g];
    final gutNr = <CamtTransaction, int>{
      for (var i = 0; i < selGuts.length; i++) selGuts[i]: i + 1
    };
    if (selGuts.isEmpty || gewaehlteForderungen.isEmpty) {
      return (gut: gutNr, ford: const {});
    }
    final paarung = paareMitBetrag<CamtTransaction>(
      zahlungen: selGuts,
      datumVon: (g) => g.bookingDate,
      betragVon: (g) => g.amount,
      forderungen: [
        for (final r in gewaehlteForderungen)
          (id: r.id, rechnungsdatum: r.rechnungsdatum, betrag: r.betragBrutto)
      ],
    );
    return (
      gut: gutNr,
      ford: {
        for (final e in paarung.entries)
          if (gutNr[e.value] != null) e.key: gutNr[e.value]!
      },
    );
  }

  /// Zeilen-Titel mit optionalem Paar-Punkt davor.
  Widget _mitPaarBadge(int? nr, String text) {
    if (nr == null) return Text(text);
    return Row(
      children: [
        PaarBadge(nummer: nr),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  /// Entfernt verbuchte Forderungen aus **jeder** Liste des Abgleichs — auch
  /// aus anderen Manuell-Fällen und Auto-Treffern. Vorher verschwanden sie nur
  /// aus dem gerade bearbeiteten Fall; dieselbe Forderung blieb anderswo
  /// auswählbar und hätte ein zweites Mal zugeordnet werden können
  /// (gemeldet Daniel 28.07.2026). Der Service lehnt eine solche Doppelbuchung
  /// zwar ab — sichtbar sein soll sie aber gar nicht erst.
  void _entferneVerbuchte(Set<String> ids) {
    if (ids.isEmpty) return;
    widget.alleOffenen.removeWhere((r) => ids.contains(r.id));
    widget.ergebnis.keineZahlung.removeWhere((r) => ids.contains(r.id));
    for (final m in widget.ergebnis.manuell) {
      m.forderungen.removeWhere((r) => ids.contains(r.id));
    }
    for (final a in [...widget.ergebnis.auto]) {
      a.forderungen.removeWhere((r) => ids.contains(r.id));
      if (a.forderungen.isEmpty) widget.ergebnis.auto.remove(a);
    }
    // Manuell-Fälle, die dadurch leer laufen, fallen weg.
    widget.ergebnis.manuell
        .removeWhere((m) => m.forderungen.isEmpty && m.gutschriften.isEmpty);
  }

  Future<void> _verbuche(AutoTreffer t) async {
    try {
      await ForderungsAbgleichService.verbuche(
        zahlbetrag: t.gutschrift.amount,
        datum: t.gutschrift.bookingDate,
        forderungen: t.forderungen,
        camtTxKey: t.gutschrift.txKey,
      );
      // Auto-Treffer lernen (wenn aktiviert): Zahlername → Betrieb der Forderung.
      if (_autoLernen) {
        final bid = t.forderungen.first.betriebId;
        if (bid != null) await _lerneAlias(bid, t.gutschrift);
      }
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        widget.ergebnis.auto.remove(t);
        _entferneVerbuchte(t.forderungen.map((r) => r.id).toSet());
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verbuchungs-Fehler: $e')));
      }
    }
  }

  Future<void> _verbucheAlle() async {
    final treffer = List<AutoTreffer>.from(widget.ergebnis.auto);
    final fehler = <String>[];
    final verbuchteTreffer = <AutoTreffer>[];
    for (final t in treffer) {
      try {
        await ForderungsAbgleichService.verbuche(
          zahlbetrag: t.gutschrift.amount,
          datum: t.gutschrift.bookingDate,
          forderungen: t.forderungen,
          camtTxKey: t.gutschrift.txKey,
        );
        verbuchteTreffer.add(t);
      } catch (e) {
        fehler.add('${t.gutschrift.amount.toStringAsFixed(2)} CHF: $e');
      }
    }
    // Auto-Treffer lernen (wenn aktiviert): je eindeutigem Betrieb+Zahlername
    // einmal (spart wiederholte getAll()-Fetches).
    if (_autoLernen) {
      final gelernt = <String>{};
      for (final t in verbuchteTreffer) {
        final bid = t.forderungen.first.betriebId;
        if (bid == null) continue;
        final name = effektiverZahlername(
            partyName: t.gutschrift.partyName,
            additionalInfo: t.gutschrift.additionalInfo);
        if (name == null || !gelernt.add('$bid|${zahlernameNorm(name)}')) {
          continue;
        }
        await _lerneAlias(bid, t.gutschrift);
      }
    }
    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (mounted) {
      setState(() {
        widget.ergebnis.auto.removeWhere((t) => verbuchteTreffer.contains(t));
        _entferneVerbuchte(verbuchteTreffer
            .expand((t) => t.forderungen)
            .map((r) => r.id)
            .toSet());
      });
      final verbucht = treffer.length - fehler.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fehler.isEmpty
            ? '$verbucht Zahlung(en) verbucht.'
            : '$verbucht verbucht, ${fehler.length} fehlgeschlagen: ${fehler.join('; ')}'),
      ));
    }
  }

  Future<void> _oeffneManuell(ManuellFall f) async {
    // Lokale Auswahl-Mengen für den Dialog (Sammelzahlung ↔ mehrere Forderungen).
    final gewaehlteGutschriften = <CamtTransaction>{};
    final gewaehlteForderungen = <Rechnung>{};
    // Gesetzt, wenn der User eine Gutschrift „anders zuordnen" will (gehört zu
    // einem anderen Betrieb, z.B. Betreiber-/Ketten-Name).
    CamtTransaction? umleiten;

    // Zahlungseingänge neueste zuoberst.
    final gutschriftenSortiert = [...f.gutschriften]
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    // Vermerk-basierte Vorauswahl (nur Vorschlag, kein Auto): Forderung, deren
    // Rechnungsdatum dem im Zahlungs-Vermerk genannten Datum (HAPIMAG /
    // Betreiber-Sammelzahlung) entspricht, wird vorgehäkelt + hervorgehoben.
    final vorschlagFordIds = <String>{};
    for (final g in gutschriftenSortiert) {
      final v = parseVermerk(g.remittanceInfo);
      // Rechnungsnummer aus der Bemerkung exakt (stärkstes Signal), sonst
      // Datum, sonst exakter Betrag (Goodfast nennt weder Nummer noch Datum —
      // die Beträge sind praktisch immer eindeutig, Regel Daniel 07.08.2026).
      var treffer = v.rechnungsnummer == null
          ? const <Rechnung>[]
          : f.forderungen
              .where((r) => r.rechnungsnummer == v.rechnungsnummer)
              .toList();
      if (treffer.isEmpty && v.datum != null) {
        treffer = f.forderungen
            .where((r) => _sameDay(r.rechnungsdatum, v.datum!))
            .toList();
      }
      if (treffer.isEmpty) {
        treffer = f.forderungen
            .where((r) => (r.betragBrutto - g.amount).abs() < 0.005)
            .toList();
      }
      if (treffer.length == 1 && !vorschlagFordIds.contains(treffer.first.id)) {
        vorschlagFordIds.add(treffer.first.id);
        gewaehlteGutschriften.add(g);
        gewaehlteForderungen.add(treffer.first);
      }
    }

    final verbucht = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Live-Summen + 5-Rappen-gerundete Differenz.
            final zahlSumme =
                gewaehlteGutschriften.fold<double>(0, (s, g) => s + g.amount);
            final fordSumme = gewaehlteForderungen.fold<double>(
                0, (s, r) => s + r.betragBrutto);
            final info = bewerteDifferenz(zahlSumme, fordSumme);
            final kannVerbuchen = gewaehlteGutschriften.isNotEmpty &&
                gewaehlteForderungen.isNotEmpty;
            // Forderungen chronologisch (neueste zuoberst, nach Datum — nicht Nr.).
            final forderungenSortiert = [...f.forderungen]
              ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));
            // Paar-Punkte: zeigen, welche gewählte Zahlung welche Rechnung
            // begleicht (gleiche Nummer + Farbe = ein Paar).
            final badges = _paarNummern(
              gutsAnzeige: gutschriftenSortiert,
              gewaehlteGuts: gewaehlteGutschriften,
              gewaehlteForderungen: gewaehlteForderungen,
            );

            return AlertDialog(
              // Schmaler Rand → auf dem Handy zählt jeder Pixel Textbreite.
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              contentPadding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: Text('Manuelle Zuordnung — ${f.betriebName}'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zahlungseingänge (Gutschriften) als Mehrfachauswahl.
                    const Text('Zahlungseingänge',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final g in gutschriftenSortiert)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteGutschriften.contains(g),
                        title: _mitPaarBadge(
                          badges.gut[g],
                          '${_dateFormat.format(g.bookingDate)} — '
                          '${g.amount.toStringAsFixed(2)} CHF',
                        ),
                        subtitle: _zahlungInfoText(g),
                        // Gehört zu einem anderen Betrieb? Über alle Betriebe
                        // neu zuordnen (+ Alias lernen). GestureDetector, da
                        // Material-Buttons in CanvasKit teils nicht rendern.
                        secondary: Tooltip(
                          message: 'Anders zuordnen',
                          child: GestureDetector(
                            onTap: () {
                              umleiten = g;
                              Navigator.pop(ctx, false);
                            },
                            behavior: HitTestBehavior.opaque,
                            // Icon statt zweizeiligem Label: schmaler (mehr
                            // Platz für den Text) und die Zeile wird nicht
                            // vom Button hochgedrückt. 44px = Tippfläche.
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.swap_horiz,
                                  size: 22, color: AppColors.primary),
                            ),
                          ),
                        ),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteGutschriften.add(g);
                          } else {
                            gewaehlteGutschriften.remove(g);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    // Offene Forderungen als Mehrfachauswahl.
                    const Text('Offene Forderungen',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final r in forderungenSortiert)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        tileColor: vorschlagFordIds.contains(r.id)
                            ? AppColors.success.withAlpha(20)
                            : null,
                        value: gewaehlteForderungen.contains(r),
                        title: _mitPaarBadge(
                          badges.ford[r.id],
                          '${_dateFormat.format(r.rechnungsdatum)} — '
                          '${r.betragBrutto.toStringAsFixed(2)} CHF',
                        ),
                        subtitle: Text(vorschlagFordIds.contains(r.id)
                            ? 'Rechnung ${r.rechnungsnummer ?? '?'} · 📌 Vorschlag (Bemerkung/Betrag)'
                            : 'Rechnung ${r.rechnungsnummer ?? '?'}'),
                        secondary: _forderungPdfLink(r),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteForderungen.add(r);
                          } else {
                            gewaehlteForderungen.remove(r);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    if (badges.ford.isNotEmpty) ...[
                      Row(
                        children: [
                          const PaarBadge(nummer: 1),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gleicher Punkt = Zahlung und Rechnung werden '
                              'einander zugeordnet.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Summen + Differenz-Hinweis (gespiegelt aus rechnung_detail_screen).
                    Text(
                      'Zahlung: CHF ${zahlSumme.toStringAsFixed(2)}\n'
                      'Forderung: CHF ${fordSumme.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (!info.istKeine) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: info.istMinder
                              ? AppColors.error.withAlpha(25)
                              : AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (info.istMinder
                                    ? AppColors.error
                                    : AppColors.success)
                                .withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              info.istMinder
                                  ? Icons.trending_down
                                  : Icons.trending_up,
                              size: 18,
                              color: info.istMinder
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                info.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: info.istMinder
                                      ? AppColors.error
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: kannVerbuchen
                      ? () async {
                          if (!await _pruefeDatumsfolge(
                              gewaehlteGutschriften.toList(),
                              gewaehlteForderungen)) {
                            return;
                          }
                          try {
                            await ForderungsAbgleichService.verbuche(
                              zahlbetrag: zahlSumme,
                              datum: gewaehlteGutschriften.first.bookingDate,
                              forderungen: gewaehlteForderungen.toList(),
                              camtTxKey: gewaehlteGutschriften.first.txKey,
                              gutschriften: gewaehlteGutschriften.toList(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content:
                                      Text('Verbuchungs-Fehler: $e')));
                            }
                          }
                        }
                      : null,
                  child: const Text('Verbuchen'),
                ),
              ],
            );
          },
        );
      },
    );

    // „Anders zuordnen": diese Gutschrift gehört zu einem anderen Betrieb →
    // über alle offenen Forderungen neu zuordnen (+ Alias lernen).
    if (umleiten != null) {
      await _ordneZu(umleiten!, korrigiereManuell: f);
      return;
    }
    if (verbucht != true) return;

    // Zahler→Betrieb lernen: pro eindeutigem Zahlernamen einmal (mehrere
    // Gutschriften desselben Betriebs teilen i.d.R. denselben Namen) → spart
    // wiederholte getAll()-Fetches und doppelte Konflikt-Hinweise.
    final gelernteNamen = <String>{};
    for (final g in gewaehlteGutschriften) {
      final name = effektiverZahlername(
          partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null || !gelernteNamen.add(zahlernameNorm(name))) continue;
      await _lerneAlias(f.betriebId, g);
    }

    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (!mounted) return;
    setState(() {
      // Verbuchte Forderungen + konsumierte Gutschriften aus dem Fall entfernen.
      f.forderungen.removeWhere((r) => gewaehlteForderungen.contains(r));
      f.gutschriften.removeWhere((g) => gewaehlteGutschriften.contains(g));
      // Aus ALLEN Listen entfernen — auch aus anderen Fällen und Auto-Treffern.
      final gebuchteIds = gewaehlteForderungen.map((r) => r.id).toSet();
      _entferneVerbuchte(gebuchteIds);
      // Bleiben keine Forderungen mehr offen, fällt der ganze Fall weg.
      if (f.forderungen.isEmpty) {
        // Übrige (nicht zugeordnete) Gutschriften des Falls sichtbar halten.
        widget.ergebnis.unbekannteGutschriften.addAll(f.gutschriften);
        widget.ergebnis.manuell.remove(f);
      } else if (f.gutschriften.isEmpty) {
        // Alle Zahlungen des Falls sind zugeordnet — es gibt nichts mehr zu
        // tun, der Eintrag würde sonst mit „0 Zahlung(en)" stehen bleiben
        // (gemeldet Daniel 28.07.2026). Die weiterhin offenen Forderungen
        // wandern nach „Keine Zahlung gefunden", wie im ⚪-Pfad.
        for (final r in f.forderungen) {
          if (!gebuchteIds.contains(r.id) &&
              widget.alleOffenen.any((o) => o.id == r.id) &&
              !widget.ergebnis.keineZahlung.any((k) => k.id == r.id)) {
            widget.ergebnis.keineZahlung.add(r);
          }
        }
        widget.ergebnis.manuell.remove(f);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
    }
  }

  /// Manuelle Zuordnung einer Gutschrift zu einer oder mehreren offenen
  /// Forderungen aus dem Gesamtpool (mit Suche). [korrigiereAuto] != null:
  /// korrigiert einen falschen Auto-Treffer (z.B. Betreiber-/Ketten-Name) —
  /// dieser wird entfernt, seine ursprünglichen Forderungen wieder als offen
  /// gezeigt; bei eindeutigem Betrieb wird der Alias gelernt.
  Future<void> _ordneZu(CamtTransaction g,
      {AutoTreffer? korrigiereAuto, ManuellFall? korrigiereManuell}) async {
    final gewaehlt = <Rechnung>{};
    var suche = '';
    var zeigeAlte = false;
    // „Später klären": Zahlung in die Prüfliste parken (Recherche-Fall).
    var spaeterKlaeren = false;
    final jetzt = DateTime.now();
    final anzahlAlte = widget.alleOffenen
        .where((r) => !istImAbgleichsfenster(r.rechnungsdatum, jetzt))
        .length;
    // Exakte Betrags-Treffer nach oben + markieren — bei Sammelzahlern ohne
    // Vermerk (Goodfast) ist der Betrag das beste Signal für die Handarbeit.
    bool passtBetrag(Rechnung r) => (r.betragBrutto - g.amount).abs() < 0.005;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final gefiltert = widget.alleOffenen.where((r) {
            if (!zeigeAlte && !istImAbgleichsfenster(r.rechnungsdatum, jetzt)) {
              return false;
            }
            if (suche.isEmpty) return true;
            final q = suche.toLowerCase();
            final nr = (r.rechnungsnummer ?? '').toLowerCase();
            final betrieb = (widget.betriebName[r.betriebId] ?? '').toLowerCase();
            return nr.contains(q) || betrieb.contains(q);
          }).toList()
            ..sort((a, b) {
              final ba = passtBetrag(a) ? 0 : 1;
              final bb = passtBetrag(b) ? 0 : 1;
              if (ba != bb) return ba - bb;
              return b.rechnungsdatum.compareTo(a.rechnungsdatum);
            });
          final zahlSumme = g.amount;
          final fordSumme = gewaehlt.fold<double>(0, (s, r) => s + r.betragBrutto);
          final info = bewerteDifferenz(zahlSumme, fordSumme);
          return AlertDialog(
            title: Text('Zahlung zuordnen — ${g.amount.toStringAsFixed(2)} CHF'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info zur Zahlung (Datum/Betrag + Zahler/Mitteilung/Schalter-Text).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dateFormat.format(g.bookingDate)} — '
                          '${g.amount.toStringAsFixed(2)} CHF',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_zahlungInfo(g) != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _zahlungInfo(g)!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Suche (Rechnungsnr. oder Betrieb)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => suche = v),
                  ),
                  if (anzahlAlte > 0)
                    _altpostenSchalter(
                      an: zeigeAlte,
                      anzahl: anzahlAlte,
                      umschalten: () =>
                          setDialogState(() => zeigeAlte = !zeigeAlte),
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in gefiltert)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: gewaehlt.contains(r),
                            tileColor: passtBetrag(r)
                                ? AppColors.success.withAlpha(20)
                                : null,
                            title: Text('${_dateFormat.format(r.rechnungsdatum)} — '
                                '${r.betragBrutto.toStringAsFixed(2)} CHF'),
                            subtitle: Text('Rechnung ${r.rechnungsnummer ?? '?'} · '
                                '${widget.betriebName[r.betriebId] ?? '?'}'
                                '${passtBetrag(r) ? ' · 💰 Betrag passt' : ''}'),
                            secondary: _forderungPdfLink(r),
                            onChanged: (sel) => setDialogState(() {
                              if (sel == true) {
                                gewaehlt.add(r);
                              } else {
                                gewaehlt.remove(r);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!info.istKeine)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (info.istMinder
                                ? AppColors.error
                                : AppColors.success)
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                            info.istMinder
                                ? Icons.trending_down
                                : Icons.trending_up,
                            color: info.istMinder
                                ? AppColors.error
                                : AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text(info.text)),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  spaeterKlaeren = true;
                  Navigator.pop(ctx, false);
                },
                child: const Text('Später klären'),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              FilledButton(
                onPressed: gewaehlt.isEmpty
                    ? null
                    : () async {
                        if (!await _pruefeDatumsfolge([g], gewaehlt)) {
                          return;
                        }
                        try {
                          await ForderungsAbgleichService.verbuche(
                            zahlbetrag: g.amount,
                            datum: g.bookingDate,
                            forderungen: gewaehlt.toList(),
                            camtTxKey: g.txKey,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Verbuchungs-Fehler: $e')));
                          }
                        }
                      },
                child: const Text('Verbuchen'),
              ),
            ],
          );
        },
      ),
    );
    if (spaeterKlaeren) {
      await _parkeInPruefliste(g,
          korrigiereAuto: korrigiereAuto, korrigiereManuell: korrigiereManuell);
      return;
    }
    if (ok == true) {
      // Lernen nur bei eindeutigem Betrieb der gewählten Forderungen.
      final betriebIds =
          gewaehlt.map((r) => r.betriebId).whereType<String>().toSet();
      if (betriebIds.length == 1) {
        await _lerneAlias(betriebIds.first, g);
      }
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        final gebuchteIds = gewaehlt.map((r) => r.id).toSet();
        if (korrigiereAuto != null) {
          // Falschen Auto-Treffer entfernen; seine (nicht gebuchten)
          // Forderungen wieder als „Keine Zahlung" anzeigen.
          widget.ergebnis.auto.remove(korrigiereAuto);
          for (final r in korrigiereAuto.forderungen) {
            if (!gebuchteIds.contains(r.id) &&
                widget.alleOffenen.any((o) => o.id == r.id) &&
                !widget.ergebnis.keineZahlung.any((k) => k.id == r.id)) {
              widget.ergebnis.keineZahlung.add(r);
            }
          }
        } else if (korrigiereManuell != null) {
          // Diese Gutschrift aus dem Manuell-Fall entfernen; bleibt keine
          // Zahlung übrig, fällt der Fall weg (Forderungen → „Keine Zahlung").
          korrigiereManuell.gutschriften.remove(g);
          if (korrigiereManuell.gutschriften.isEmpty) {
            for (final r in korrigiereManuell.forderungen) {
              if (!gebuchteIds.contains(r.id) &&
                  widget.alleOffenen.any((o) => o.id == r.id) &&
                  !widget.ergebnis.keineZahlung.any((k) => k.id == r.id)) {
                widget.ergebnis.keineZahlung.add(r);
              }
            }
            widget.ergebnis.manuell.remove(korrigiereManuell);
          }
        } else {
          widget.ergebnis.unbekannteGutschriften.remove(g);
        }
        _entferneVerbuchte(gebuchteIds);
        widget.alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
        widget.ergebnis.keineZahlung
            .removeWhere((r) => gebuchteIds.contains(r.id));
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    }
  }

  /// Parkt eine Kundenzahlung in der Prüfliste (Status offen, Kategorie
  /// „kundenzahlung") — für die seltenen Fälle, in denen die Zuordnung erst
  /// nach Recherche möglich ist. Aus der Prüfliste lässt sie sich später über
  /// „Zuordnen" verbuchen; der nächste Import bewertet offene Einträge neu.
  Future<void> _parkeInPruefliste(CamtTransaction g,
      {AutoTreffer? korrigiereAuto, ManuellFall? korrigiereManuell}) async {
    try {
      await CamtPrueflisteRepository.insert(CamtPrueflisteEintrag(
        txKey: g.txKey,
        bookingDatum: g.bookingDate,
        betrag: g.amount,
        istGutschrift: g.isCredit,
        parteiName: effektiverZahlername(
                partyName: g.partyName, additionalInfo: g.additionalInfo) ??
            g.partyName,
        parteiIban: g.partyIban,
        belegRef: g.accountServiceRef,
        referenz: g.remittanceInfo ?? g.additionalInfo,
        kategorie: 'kundenzahlung',
      ));
      ref.invalidate(camtPrueflisteProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Parken fehlgeschlagen: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (korrigiereAuto != null) {
        // Auto-Treffer auflösen; seine Forderungen bleiben sichtbar offen.
        widget.ergebnis.auto.remove(korrigiereAuto);
        for (final r in korrigiereAuto.forderungen) {
          if (widget.alleOffenen.any((o) => o.id == r.id) &&
              !widget.ergebnis.keineZahlung.any((k) => k.id == r.id)) {
            widget.ergebnis.keineZahlung.add(r);
          }
        }
      } else if (korrigiereManuell != null) {
        korrigiereManuell.gutschriften.remove(g);
        if (korrigiereManuell.gutschriften.isEmpty) {
          for (final r in korrigiereManuell.forderungen) {
            if (widget.alleOffenen.any((o) => o.id == r.id) &&
                !widget.ergebnis.keineZahlung.any((k) => k.id == r.id)) {
              widget.ergebnis.keineZahlung.add(r);
            }
          }
          widget.ergebnis.manuell.remove(korrigiereManuell);
        }
      } else {
        widget.ergebnis.unbekannteGutschriften.remove(g);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('In die Prüfliste gelegt — dort später über „Zuordnen" verbuchen.')));
    }
  }

  /// Lernt den Zahlernamen einer Gutschrift als Alias des Betriebs [betriebId].
  /// Zeigt bei Konflikt (Name schon bei anderem Betrieb) einen Hinweis.
  Future<void> _lerneAlias(String betriebId, CamtTransaction g) async {
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    if (name == null) return;
    try {
      final res = await BetriebRepository.addZahlerAlias(betriebId, name);
      if (res == AliasLernResultat.konflikt && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Zahlername „$name" ist bereits einem anderen Betrieb zugeordnet — '
              'nicht gelernt.'),
        ));
      }
    } catch (_) {
      // Lernen ist Best-Effort; Verbuchung darf dadurch nicht scheitern.
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Öffnet die erfasste Rechnung (PDF). Gespeicherte signierte Storage-URLs
  /// sind abgelaufen → Pfad extrahieren und frisch signieren.
  Future<void> _oeffneRechnungPdf(String pdfUrl) async {
    try {
      var url = pdfUrl;
      const marker = '/object/sign/';
      final idx = pdfUrl.indexOf(marker);
      if (idx != -1) {
        var rest = pdfUrl.substring(idx + marker.length);
        final q = rest.indexOf('?');
        if (q != -1) rest = rest.substring(0, q);
        final slash = rest.indexOf('/');
        if (slash != -1) {
          final bucket = rest.substring(0, slash);
          final path = Uri.decodeComponent(rest.substring(slash + 1));
          url = await SupabaseService.client.storage
              .from(bucket)
              .createSignedUrl(path, 3600);
        }
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF konnte nicht geöffnet werden: $e')));
      }
    }
  }

  /// „Rechnung ansehen"-Link für eine Forderung mit erfasstem PDF (GestureDetector,
  /// da Material-Buttons in CanvasKit teils nicht rendern). Null ohne PDF.
  Widget? _forderungPdfLink(Rechnung r) {
    final pdf = r.pdfUrl;
    if (pdf == null || pdf.isEmpty) return null;
    return GestureDetector(
      onTap: () => _oeffneRechnungPdf(pdf),
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.picture_as_pdf, size: 16, color: AppColors.primary),
          SizedBox(width: 3),
          Text('Rechnung',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// „Nicht zugeordnet": Zahlungen gleicher Einzahler gruppieren (Header +
  /// Zeilen). Auch Sammelzahler (Davos Klosters, Weisse Arena, Goodfast)
  /// werden gruppiert — der Gruppen-Dialog zeigt alle ihre Zahlungen
  /// beisammen, mit 💰-Betrags-Markierung und Paar-Punkten (vorher standen
  /// sie einzeln verstreut in der Liste, Wunsch Daniel 07.08.2026).
  List<Widget> _unbekanntZeilen(List<CamtTransaction> guts) {
    final sortiert = [...guts]
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    final gruppen = <String, List<CamtTransaction>>{};
    final einzeln = <CamtTransaction>[];
    for (final g in sortiert) {
      final name = effektiverZahlername(
          partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null) {
        einzeln.add(g);
      } else {
        gruppen.putIfAbsent(zahlernameNorm(name), () => []).add(g);
      }
    }
    final widgets = <Widget>[];
    gruppen.forEach((_, list) {
      if (list.length >= 2) {
        final name = effektiverZahlername(
                partyName: list.first.partyName,
                additionalInfo: list.first.additionalInfo) ??
            '?';
        final summe = list.fold<double>(0, (s, g) => s + g.amount);
        widgets.add(InkWell(
          onTap: () => _ordneZuGruppe(list),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$name · ${list.length} Zahlungen · ${summe.toStringAsFixed(2)} CHF',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const Icon(Icons.playlist_add_check,
                    size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ));
        for (final g in list) {
          widgets.add(_unbekanntZeile(g, eingerueckt: true));
        }
      } else {
        widgets.add(_unbekanntZeile(list.first));
      }
    });
    for (final g in einzeln) {
      widgets.add(_unbekanntZeile(g));
    }
    return widgets;
  }

  Widget _unbekanntZeile(CamtTransaction g, {bool eingerueckt = false}) {
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    final remit = g.remittanceInfo?.trim();
    // Ohne Zahlername (Schalter-/Automaten-/Posteinzahlung): den rohen
    // Bank-Text zeigen — der enthält bei Automaten Ort/Datum/Uhrzeit und ist
    // die einzige Spur, welche Einzahlung das war.
    final addtl = g.additionalInfo?.trim();
    final adr = g.partyAddress.trim();
    final sub = [
      _dateFormat.format(g.bookingDate),
      if (adr.isNotEmpty) adr,
      if (remit != null && remit.isNotEmpty) remit,
      if (name == null && addtl != null && addtl.isNotEmpty) addtl,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.only(left: eingerueckt ? 32 : 16, right: 8),
      title: Text('${g.amount.toStringAsFixed(2)} CHF — '
          '${name ?? 'Einzahlung ohne Zahlername (Schalter/Automat)'}'),
      subtitle: Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _ordneZu(g),
    );
  }

  /// Zuordnung mehrerer Zahlungseingänge gleicher Einzahler: oben die Zahlungen
  /// (Mehrfachauswahl), unten Suche über den offenen Forderungs-Pool — wie die
  /// Manuelle Zuordnung, aber ohne fixen Betrieb.
  Future<void> _ordneZuGruppe(List<CamtTransaction> guts) async {
    final sortiertGuts = [...guts]
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    final gewaehlteGuts = <CamtTransaction>{if (guts.length == 1) guts.first};
    final gewaehlteForderungen = <Rechnung>{};
    var suche = '';
    var zeigeAlte = false;
    final jetzt = DateTime.now();
    final anzahlAlte = widget.alleOffenen
        .where((r) => !istImAbgleichsfenster(r.rechnungsdatum, jetzt))
        .length;
    final name = effektiverZahlername(
            partyName: guts.first.partyName,
            additionalInfo: guts.first.additionalInfo) ??
        '?';
    // Betrags-Treffer gegen IRGENDEINE Zahlung der Gruppe nach oben + markieren.
    bool passtBetrag(Rechnung r) =>
        guts.any((g) => (r.betragBrutto - g.amount).abs() < 0.005);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final gefiltert = widget.alleOffenen.where((r) {
            if (!zeigeAlte && !istImAbgleichsfenster(r.rechnungsdatum, jetzt)) {
              return false;
            }
            if (suche.isEmpty) return true;
            final q = suche.toLowerCase();
            return (r.rechnungsnummer ?? '').toLowerCase().contains(q) ||
                (widget.betriebName[r.betriebId] ?? '').toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) {
              final ba = passtBetrag(a) ? 0 : 1;
              final bb = passtBetrag(b) ? 0 : 1;
              if (ba != bb) return ba - bb;
              return b.rechnungsdatum.compareTo(a.rechnungsdatum);
            });
          final zahlSumme =
              gewaehlteGuts.fold<double>(0, (s, g) => s + g.amount);
          final fordSumme = gewaehlteForderungen.fold<double>(
              0, (s, r) => s + r.betragBrutto);
          final info = bewerteDifferenz(zahlSumme, fordSumme);
          final kannVerbuchen =
              gewaehlteGuts.isNotEmpty && gewaehlteForderungen.isNotEmpty;
          final badges = _paarNummern(
            gutsAnzeige: sortiertGuts,
            gewaehlteGuts: gewaehlteGuts,
            gewaehlteForderungen: gewaehlteForderungen,
          );
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            title: Text('Zuordnen — $name'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zahlungseingänge',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final g in sortiertGuts)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteGuts.contains(g),
                        title: _mitPaarBadge(
                            badges.gut[g],
                            '${_dateFormat.format(g.bookingDate)} — '
                            '${g.amount.toStringAsFixed(2)} CHF'),
                        subtitle: _zahlungInfoText(g),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteGuts.add(g);
                          } else {
                            gewaehlteGuts.remove(g);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    const Text('Offene Forderungen',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Suche (Rechnungsnr. oder Betrieb)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setDialogState(() => suche = v),
                    ),
                    if (anzahlAlte > 0)
                      _altpostenSchalter(
                        an: zeigeAlte,
                        anzahl: anzahlAlte,
                        umschalten: () =>
                            setDialogState(() => zeigeAlte = !zeigeAlte),
                      ),
                    const SizedBox(height: 8),
                    for (final r in gefiltert.take(50))
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteForderungen.contains(r),
                        tileColor: passtBetrag(r)
                            ? AppColors.success.withAlpha(20)
                            : null,
                        title: _mitPaarBadge(
                            badges.ford[r.id],
                            '${_dateFormat.format(r.rechnungsdatum)} — '
                            '${r.betragBrutto.toStringAsFixed(2)} CHF'),
                        subtitle: Text('Rechnung ${r.rechnungsnummer ?? '?'} · '
                            '${widget.betriebName[r.betriebId] ?? '?'}'
                            '${passtBetrag(r) ? ' · 💰 Betrag passt' : ''}'),
                        secondary: _forderungPdfLink(r),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteForderungen.add(r);
                          } else {
                            gewaehlteForderungen.remove(r);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    if (badges.ford.isNotEmpty) ...[
                      Row(
                        children: [
                          const PaarBadge(nummer: 1),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gleicher Punkt = Zahlung und Rechnung werden '
                              'einander zugeordnet.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Zahlung: CHF ${zahlSumme.toStringAsFixed(2)}\n'
                      'Forderung: CHF ${fordSumme.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (!info.istKeine)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          info.text,
                          style: TextStyle(
                              fontSize: 12,
                              color: info.istMinder
                                  ? AppColors.error
                                  : AppColors.success),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              FilledButton(
                onPressed: kannVerbuchen
                    ? () async {
                        if (!await _pruefeDatumsfolge(
                            gewaehlteGuts.toList(), gewaehlteForderungen)) {
                          return;
                        }
                        try {
                          await ForderungsAbgleichService.verbuche(
                            zahlbetrag: zahlSumme,
                            datum: gewaehlteGuts.first.bookingDate,
                            forderungen: gewaehlteForderungen.toList(),
                            camtTxKey: gewaehlteGuts.first.txKey,
                            gutschriften: gewaehlteGuts.toList(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('Verbuchungs-Fehler: $e')));
                          }
                        }
                      }
                    : null,
                child: const Text('Verbuchen'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final betriebIds =
          gewaehlteForderungen.map((r) => r.betriebId).whereType<String>().toSet();
      if (betriebIds.length == 1) {
        await _lerneAlias(betriebIds.first, gewaehlteGuts.first);
      }
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        widget.ergebnis.unbekannteGutschriften
            .removeWhere((g) => gewaehlteGuts.contains(g));
        _entferneVerbuchte(gewaehlteForderungen.map((r) => r.id).toSet());
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    }
  }
}

/// Klappbare Gruppen-Karte: Header (Emoji · Titel · Anzahl-Badge · CHF-Summe)
/// und darunter die Einträge. Standard-Zustand über [initiallyExpanded].
class _GruppeCard extends StatelessWidget {
  final String emoji;
  final String titel;
  final int anzahl;
  final double? summe;
  final Color farbe;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _GruppeCard({
    required this.emoji,
    required this.titel,
    required this.anzahl,
    required this.summe,
    required this.farbe,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile zieht sonst Trennlinien über die Kartenkanten.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Text(emoji, style: const TextStyle(fontSize: 20)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  titel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: farbe.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$anzahl',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: farbe,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          subtitle: summe == null ? null : Text('${chf(summe!)} CHF'),
          childrenPadding: EdgeInsets.zero,
          children: children.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('—',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ]
              : children,
        ),
      ),
    );
  }
}

/// Kompakte Kennzahl-Kachel in der Kopf-Übersicht (umbruchfähig via Wrap).
class _Kpi extends StatelessWidget {
  final Color farbe;
  final String label;
  final int anzahl;
  final String? sub;

  const _Kpi({
    required this.farbe,
    required this.label,
    required this.anzahl,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: farbe.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: farbe.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$anzahl',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (sub != null)
            Text(
              sub!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
