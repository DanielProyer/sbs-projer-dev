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
List<BetriebReinigung> betriebReinigungen(BetriebLocal b) {
  final label = _label(b);
  final out = <BetriebReinigung>[];
  void add(String slotKey, String art, DateTime? d) {
    if (d == null) return;
    out.add(BetriebReinigung(
        slotKey: slotKey,
        art: art,
        datum: DateTime(d.year, d.month, d.day),
        label: label));
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
