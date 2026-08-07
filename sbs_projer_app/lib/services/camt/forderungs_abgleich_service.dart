import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/sammelzahler.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';
import 'package:sbs_projer_app/services/camt/vermerk_parser.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/core/util/zahlung_paarung.dart';

/// Ein eindeutiger Auto-Treffer: eine Gutschrift schliesst eine/mehrere Forderungen.
class AutoTreffer {
  final CamtTransaction gutschrift;
  final List<Rechnung> forderungen;

  /// Wie der Treffer zustande kam ('QR-Referenz', 'Zahler-Alias · Betrag passt',
  /// 'Zahlername exakt · Betrag passt') — wird dem User zur Kontrolle angezeigt.
  final String grund;
  AutoTreffer(this.gutschrift, this.forderungen, {this.grund = ''});
}

/// Ein manuell zu klärender Fall: ein Betrieb mit übrigen Gutschriften + Forderungen.
class ManuellFall {
  final String betriebId;
  final String betriebName;
  final List<CamtTransaction> gutschriften;
  final List<Rechnung> forderungen;
  ManuellFall(this.betriebId, this.betriebName, this.gutschriften, this.forderungen);
}

class AbgleichErgebnis {
  final List<AutoTreffer> auto;
  final List<ManuellFall> manuell;
  final List<Rechnung> keineZahlung; // offene Forderungen ohne passende Gutschrift
  final List<CamtTransaction> unbekannteGutschriften; // benannte Zahlungseingänge ohne Zuordnung
  AbgleichErgebnis(this.auto, this.manuell, this.keineZahlung, this.unbekannteGutschriften);
}

class ForderungsAbgleichService {
  /// Forderungs-getriebener Abgleich (rein, ohne IO — testbar).
  static AbgleichErgebnis abgleich({
    required List<CamtTransaction> gutschriften,
    required List<Rechnung> offeneForderungen,
    required List<Map<String, String>> betriebe,
  }) {
    // STUFE 1: deterministischer QR-/SCOR-Referenz-Match (vor der Gruppierung).
    final refTreffer = <AutoTreffer>[];
    final verbrauchteGuts = <CamtTransaction>{};
    final verbrauchteFordIds = <String>{};
    final refIndex = <String, Rechnung>{};
    for (final r in offeneForderungen) {
      final ref = r.qrReferenz;
      if (ref != null && ref.trim().isNotEmpty) {
        refIndex[scorRefNorm(ref)] = r;
      }
    }
    for (final g in gutschriften.where((g) => g.isCredit)) {
      final sref = g.strukturierteReferenz;
      if (sref == null || sref.trim().isEmpty) continue;
      final r = refIndex[scorRefNorm(sref)];
      if (r == null || verbrauchteFordIds.contains(r.id)) continue;
      refTreffer.add(AutoTreffer(g, [r], grund: 'QR-Referenz'));
      verbrauchteGuts.add(g);
      verbrauchteFordIds.add(r.id);
    }
    final gutschriftenAktiv =
        gutschriften.where((g) => !verbrauchteGuts.contains(g)).toList();
    final offeneAktiv = offeneForderungen
        .where((r) => !verbrauchteFordIds.contains(r.id))
        .toList();

    // 1. Gutschriften pro Betrieb gruppieren (über effektiven Zahlernamen).
    // Vertrauensstufe je Gutschrift: SICHER (gelernter Alias ODER exakter Name)
    // ist auto-fähig; UNSCHARF (findBestMatch Contains/Wort-Overlap) dient nur
    // als Betrieb-Vorschlag und wird NIE automatisch verbucht (Schutz gegen
    // Fehlmatch wie „Edelweiss Davos AG" → Betrieb „Edelweiss" in Vals).
    // Index offener Forderungen nach Rechnungsnummer (für Bemerkung-Match, z.B.
    // Davos Klosters Bergbahnen nennt die Rechnungsnummer im Verwendungszweck).
    final fordByNr = <String, Rechnung>{};
    for (final r in offeneAktiv) {
      final nr = r.rechnungsnummer;
      if (nr != null && nr.isNotEmpty && r.betriebId != null) fordByNr[nr] = r;
    }

    final gutProBetrieb = <String, List<CamtTransaction>>{};
    final unscharfeGuts = <CamtTransaction>{};
    // Merkt sich je sicherer Gutschrift, WORÜBER der Betrieb gefunden wurde —
    // fürs Anzeigen des Treffer-Grunds in der Auto-Liste.
    final sicherGrund = <CamtTransaction, String>{};
    for (final g in gutschriftenAktiv.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      final alias =
          name == null ? null : CamtBetriebMatcher.matchByAlias(name, betriebe);
      final treffer = alias ??
          (name == null ? null : CamtBetriebMatcher.matchExakt(name, betriebe));
      // Sammelzahler (Zentrale zahlt für mehrere Objekte) sind nie «sicher» —
      // auch nicht über einen gelernten Alias (Fall Weisse Arena → IKIGAI).
      // Der Treffer bleibt aber als VORSCHLAG für die manuelle Prüfung stehen.
      final sicher = (treffer != null && !istSammelzahler(name)) ? treffer : null;
      if (sicher != null) {
        sicherGrund[g] = alias != null ? 'Zahler-Alias' : 'Zahlername exakt';
      }
      // Auflösungs-Reihenfolge: sicher → Bemerkung-Rechnungsnummer (direkte
      // Forderung) → Vermerk-Betriebnummer → unscharfer Name. Nur „sicher" ist
      // auto-fähig; alles andere landet als Vorschlag in der manuellen Prüfung.
      final vermerk = parseVermerk(g.remittanceInfo);
      final refFord =
          vermerk.rechnungsnummer == null ? null : fordByNr[vermerk.rechnungsnummer!];
      final zielId = sicher?['id'] ??
          refFord?.betriebId ??
          CamtBetriebMatcher.matchByNummer(vermerk.betriebNummer, betriebe)?['id'] ??
          treffer?['id'] ??
          (name == null ? null : CamtBetriebMatcher.findBestMatch(name, betriebe)?['id']);
      if (zielId == null) continue;
      gutProBetrieb.putIfAbsent(zielId, () => []).add(g);
      if (sicher == null) unscharfeGuts.add(g);
    }

    // 2. Offene Forderungen pro Betrieb gruppieren.
    final fordProBetrieb = <String, List<Rechnung>>{};
    for (final r in offeneAktiv) {
      if (r.betriebId == null) continue;
      fordProBetrieb.putIfAbsent(r.betriebId!, () => []).add(r);
    }

    final auto = <AutoTreffer>[];
    final manuell = <ManuellFall>[];
    final keineZahlung = <Rechnung>[];
    final betriebName = {
      for (final b in betriebe)
        b['id']!: (b['ort'] ?? '').isEmpty
            ? b['name']!
            : '${b['name']} · ${b['ort']}'
    };

    // 3. Pro Betrieb mit offenen Forderungen matchen.
    // Forderungs-getrieben: nur Betriebe MIT offenen Forderungen werden betrachtet.
    // Gutschriften zu Betrieben ohne offene Forderung werden bewusst ignoriert (kein Bucket dafür).
    for (final entry in fordProBetrieb.entries) {
      final betriebId = entry.key;
      final offen = List<Rechnung>.from(entry.value);
      final guts = List<CamtTransaction>.from(gutProBetrieb[betriebId] ?? const []);

      if (guts.isEmpty) {
        keineZahlung.addAll(offen);
        continue;
      }

      // Pro SICHER aufgelöster Gutschrift eindeutige Subset-Summe der noch
      // offenen Forderungen. Unscharfe Gutschriften bleiben für die manuelle
      // Prüfung (nie automatisch verbucht).
      for (final g in List<CamtTransaction>.from(guts)) {
        if (unscharfeGuts.contains(g)) continue;
        final m = RechnungMatcher.match(zahlbetrag: g.amount, offeneRechnungen: offen);
        if (m.eindeutig) {
          auto.add(AutoTreffer(g, m.rechnungen,
              grund: '${sicherGrund[g] ?? 'Zahlername'} · Betrag passt'));
          offen.removeWhere((r) => m.rechnungen.any((x) => x.id == r.id));
          guts.remove(g);
        }
      }

      // Rest dieses Betriebs → manuell (wenn Gutschriften ODER Forderungen übrig).
      if (guts.isNotEmpty && offen.isNotEmpty) {
        manuell.add(ManuellFall(betriebId, betriebName[betriebId] ?? '?', guts, offen));
      } else if (offen.isNotEmpty) {
        keineZahlung.addAll(offen);
      }
    }

    // 4. Benannte Gutschriften, die weder auto noch manuell zugeordnet wurden → unbekannt.
    final zugeordnet = <CamtTransaction>{
      ...auto.map((a) => a.gutschrift),
      ...manuell.expand((m) => m.gutschriften),
    };
    final unbekannt = <CamtTransaction>[];
    for (final g in gutschriftenAktiv.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null) continue;
      if (zugeordnet.contains(g)) continue;
      unbekannt.add(g);
    }

    return AbgleichErgebnis([...refTreffer, ...auto], manuell, keineZahlung, unbekannt);
  }

  /// Verbucht eine Zahlung gegen die gewählten Forderungen + markiert sie bezahlt.
  /// Nutzt die bestehende Sammel-Verbuchung (Bank 1020 ← Debitoren 1100 + Differenz).
  /// [camtTxKey] markiert die erzeugten Buchungen → identifizierbar/reversibel.
  ///
  /// [gutschriften] sind die zugeordneten Zahlungseingänge. Sind es mehrere,
  /// werden sie paarweise verteilt — neueste Zahlung auf neueste Forderung
  /// (Regel Daniel 28.07.2026) —, damit jede Rechnung das Datum und den
  /// camt-Schlüssel *ihrer* Zahlung trägt. Vorher bekamen alle Rechnungen
  /// pauschal die Werte der ersten Gutschrift.
  static Future<void> verbuche({
    required double zahlbetrag,
    required DateTime datum,
    required List<Rechnung> forderungen,
    String? camtTxKey,
    List<CamtTransaction> gutschriften = const [],
  }) async {
    if (forderungen.isEmpty) return;

    // Schutz gegen Mehrfachzuordnung (Daniel 28.07.2026): Der Stand wird
    // FRISCH aus der Datenbank geprüft, nicht aus der Bildschirmliste. Wurde
    // eine Forderung zwischenzeitlich anderswo zugeordnet — anderer Fall,
    // zweiter Tab, Doppeltipp —, darf sie nicht ein zweites Mal verbucht
    // werden, sonst entstünde eine Doppelzahlung auf demselben Debitor.
    final bereitsBezahlt = <String>[];
    for (final r in forderungen) {
      final frisch = await RechnungRepository.getById(r.id);
      if (frisch != null && frisch.zahlungsstatus == 'bezahlt') {
        bereitsBezahlt.add(frisch.rechnungsnummer ?? frisch.id);
      }
    }
    if (bereitsBezahlt.isNotEmpty) {
      throw Exception(
          'Bereits bezahlt: ${bereitsBezahlt.join(', ')} — Zuordnung '
          'abgebrochen. Bitte Liste aktualisieren.');
    }

    // Paarung nur nötig, wenn mehrere Zahlungen im Spiel sind.
    // Betrag-exakte Paare zuerst (Sammelzahler: mehrere gleichtägige
    // Zahlungen ↔ gleichtägige Rechnungen), Rest nach Datum.
    final paarung = gutschriften.length < 2
        ? const <String, CamtTransaction>{}
        : paareMitBetrag<CamtTransaction>(
            zahlungen: gutschriften,
            datumVon: (g) => g.bookingDate,
            betragVon: (g) => g.amount,
            forderungen: [
              for (final r in forderungen)
                (
                  id: r.id,
                  rechnungsdatum: r.rechnungsdatum,
                  betrag: r.betragBrutto
                )
            ],
          );

    final buchungen = await ZahlungsdifferenzService.verbuchenSammel(
      rechnungen: forderungen,
      zahlungBetrag: zahlbetrag,
      datum: datum,
      datumProRechnung: {
        for (final e in paarung.entries) e.key: e.value.bookingDate,
      },
    );
    // Jede Buchung trägt den Schlüssel *ihrer* Zahlung — sonst hinge die
    // Buchung beim Rückgängigmachen an der falschen Transaktion.
    for (final b in buchungen) {
      final key = paarung[b.belegId]?.txKey ?? camtTxKey;
      if (key != null) await BuchungRepository.setCamtTxKey(b.id, key);
    }
    for (final r in forderungen) {
      final eingang = paarung[r.id]?.bookingDate ?? datum;
      await RechnungRepository.update(r.id, {
        'zahlungsstatus': 'bezahlt',
        'zahlung_eingegangen_am': eingang.toIso8601String().split('T').first,
        'zahlung_betrag': r.betragBrutto,
      });
    }
  }
}
