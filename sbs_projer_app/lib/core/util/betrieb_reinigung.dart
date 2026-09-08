import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Eine berechnete Saison-/Ferien-Reinigung eines Betriebs.
class BetriebReinigung {
  final String slotKey; // stabiler Schlüssel, z.B. 'sommer_eroeffnung', 'ferien1_endreinigung'
  final String art; // 'endreinigung' | 'eroeffnung'
  final DateTime datum;
  final String label; // "Name, Ort"
  const BetriebReinigung({
    required this.slotKey,
    required this.art,
    required this.datum,
    required this.label,
  });
}

String _label(BetriebLocal b) {
  final ort = b.ort?.trim() ?? '';
  return ort.isEmpty ? b.name : '${b.name}, $ort';
}

/// Berechnet die Eröffnung/Endreinigung aus Saison- und Ferien-Daten.
///
/// **Nur Termine ab [heute]** (Standard: jetzt). Die Saison- und Ferienfelder
/// halten konkrete Daten je Saison, kein wiederkehrendes Muster — steht dort
/// noch die letzte Saison, sind ihre Termine schlicht vorbei. Ohne diesen
/// Filter schlug das Speichern eines Betriebs sie weiter für den Google-
/// Kalender vor: Acla Grischuna bot am 08.09.2026 die Wintersaison
/// 13.12.2025–29.03.2026 an. Ins nächste Jahr schieben wäre geraten — wann
/// die neue Saison beginnt, weiss nur der Betrieb.
List<BetriebReinigung> betriebReinigungen(BetriebLocal b, {DateTime? heute}) {
  final jetzt = heute ?? DateTime.now();
  final grenze = DateTime(jetzt.year, jetzt.month, jetzt.day);
  final label = _label(b);
  final out = <BetriebReinigung>[];
  void add(String slotKey, String art, DateTime? d) {
    if (d == null) return;
    final tag = DateTime(d.year, d.month, d.day);
    if (tag.isBefore(grenze)) return; // vorbei — nicht mehr vorschlagen
    out.add(
        BetriebReinigung(slotKey: slotKey, art: art, datum: tag, label: label));
  }

  if (b.istSaisonbetrieb) {
    if (b.sommerSaisonAktiv) {
      add('sommer_eroeffnung', 'eroeffnung', b.sommerStartDatum);
      add('sommer_endreinigung', 'endreinigung', b.sommerEndeDatum);
    }
    if (b.winterSaisonAktiv) {
      add('winter_eroeffnung', 'eroeffnung', b.winterStartDatum);
      add('winter_endreinigung', 'endreinigung', b.winterEndeDatum);
    }
  }

  if (!b.keineBetriebsferien) {
    final slots = ferienSlots(b);
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.start != null && s.ende != null) {
        add('ferien${i + 1}_endreinigung', 'endreinigung',
            s.start!.subtract(const Duration(days: 1)));
        add('ferien${i + 1}_eroeffnung', 'eroeffnung',
            s.ende!.add(const Duration(days: 1)));
      }
    }
  }

  out.sort((x, y) => x.datum.compareTo(y.datum));
  return out;
}
