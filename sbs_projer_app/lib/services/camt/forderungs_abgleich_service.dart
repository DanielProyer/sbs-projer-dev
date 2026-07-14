import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';
import 'package:sbs_projer_app/services/camt/vermerk_parser.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';

/// Ein eindeutiger Auto-Treffer: eine Gutschrift schliesst eine/mehrere Forderungen.
class AutoTreffer {
  final CamtTransaction gutschrift;
  final List<Rechnung> forderungen;
  AutoTreffer(this.gutschrift, this.forderungen);
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
      refTreffer.add(AutoTreffer(g, [r]));
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
    final gutProBetrieb = <String, List<CamtTransaction>>{};
    final unscharfeGuts = <CamtTransaction>{};
    for (final g in gutschriftenAktiv.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      final sicher = name == null
          ? null
          : (CamtBetriebMatcher.matchByAlias(name, betriebe) ??
              CamtBetriebMatcher.matchExakt(name, betriebe));
      // Auflösungs-Reihenfolge: sicher → Vermerk-Betriebnummer (Betreiber-
      // Sammelzahlung) → unscharfer Name. Nur „sicher" ist auto-fähig; alles
      // andere landet als Vorschlag in der manuellen Prüfung.
      final vermerk = parseVermerk(g.remittanceInfo);
      final match = sicher ??
          CamtBetriebMatcher.matchByNummer(vermerk.betriebNummer, betriebe) ??
          (name == null ? null : CamtBetriebMatcher.findBestMatch(name, betriebe));
      if (match == null) continue;
      gutProBetrieb.putIfAbsent(match['id']!, () => []).add(g);
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
          auto.add(AutoTreffer(g, m.rechnungen));
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
  static Future<void> verbuche({
    required double zahlbetrag,
    required DateTime datum,
    required List<Rechnung> forderungen,
    String? camtTxKey,
  }) async {
    if (forderungen.isEmpty) return;
    final buchungen = await ZahlungsdifferenzService.verbuchenSammel(
      rechnungen: forderungen, zahlungBetrag: zahlbetrag, datum: datum,
    );
    if (camtTxKey != null) {
      for (final b in buchungen) {
        await BuchungRepository.setCamtTxKey(b.id, camtTxKey);
      }
    }
    final datumStr = datum.toIso8601String().split('T').first;
    for (final r in forderungen) {
      await RechnungRepository.update(r.id, {
        'zahlungsstatus': 'bezahlt',
        'zahlung_eingegangen_am': datumStr,
        'zahlung_betrag': r.betragBrutto,
      });
    }
  }
}
