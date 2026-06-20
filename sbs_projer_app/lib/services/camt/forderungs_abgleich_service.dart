import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

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
  AbgleichErgebnis(this.auto, this.manuell, this.keineZahlung);
}

class ForderungsAbgleichService {
  /// Forderungs-getriebener Abgleich (rein, ohne IO — testbar).
  static AbgleichErgebnis abgleich({
    required List<CamtTransaction> gutschriften,
    required List<Rechnung> offeneForderungen,
    required List<Map<String, String>> betriebe,
  }) {
    // 1. Gutschriften pro Betrieb gruppieren (über effektiven Zahlernamen).
    final gutProBetrieb = <String, List<CamtTransaction>>{};
    for (final g in gutschriften.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null) continue;
      final match = CamtBetriebMatcher.findBestMatch(name, betriebe);
      if (match == null) continue;
      gutProBetrieb.putIfAbsent(match['id']!, () => []).add(g);
    }

    // 2. Offene Forderungen pro Betrieb gruppieren.
    final fordProBetrieb = <String, List<Rechnung>>{};
    for (final r in offeneForderungen) {
      if (r.betriebId == null) continue;
      fordProBetrieb.putIfAbsent(r.betriebId!, () => []).add(r);
    }

    final auto = <AutoTreffer>[];
    final manuell = <ManuellFall>[];
    final keineZahlung = <Rechnung>[];
    final betriebName = {for (final b in betriebe) b['id']!: b['name']!};

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

      // Pro Gutschrift eindeutige Subset-Summe der noch offenen Forderungen.
      for (final g in List<CamtTransaction>.from(guts)) {
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

    return AbgleichErgebnis(auto, manuell, keineZahlung);
  }
}
