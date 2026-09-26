import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Eine berechnete Saison-/Ferien-Reinigung eines Betriebs.
class BetriebReinigung {
  /// Stabiler Schlüssel für die Kalender-Zuordnung, z.B. 'sommer_eroeffnung'
  /// oder 'ferien_2026-10-11_endreinigung' (siehe [ferienSlotKey]).
  final String slotKey;
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

  for (final s in wirksameFerienSlots(b)) {
    if (s.start != null && s.ende != null) {
      add(ferienSlotKey(s.start!, 'endreinigung'), 'endreinigung',
          s.start!.subtract(const Duration(days: 1)));
      add(ferienSlotKey(s.start!, 'eroeffnung'), 'eroeffnung',
          s.ende!.add(const Duration(days: 1)));
    }
  }

  out.sort((x, y) => x.datum.compareTo(y.datum));
  return out;
}

/// Kalender-Schlüssel einer Ferien-Reinigung, gebildet aus dem Ferienbeginn:
/// `ferien_2026-10-11_endreinigung`.
///
/// WARUM nicht mehr `ferien1_…` nach Index: Seit die Ferien aus der Tabelle
/// `betrieb_ferien` kommen (beliebig viele, nach `von` sortiert), verschiebt
/// jede neu erfasste frühere oder gelöschte Periode den Index — die Edge
/// Function hätte Einträge doppelt angelegt oder verwaist stehen lassen
/// (Review R7, 26.09.2026). Migration 208 schreibt die Alt-Schlüssel um.
String ferienSlotKey(DateTime von, String art) {
  final y = von.year.toString().padLeft(4, '0');
  final m = von.month.toString().padLeft(2, '0');
  final d = von.day.toString().padLeft(2, '0');
  return 'ferien_$y-$m-${d}_$art';
}

/// Alle Ferien-Schlüssel des Betriebs — auch vergangener Perioden, beide
/// Arten. Die Edge Function räumt jede `<betriebId>:ferien…`-Zuordnung weg,
/// die hier nicht vorkommt (gelöschte oder verschobene Perioden). Leer bei
/// `keineBetriebsferien`: dann gehören alle Ferien-Termine weg.
Set<String> alleFerienSlotKeys(BetriebLocal b) => {
  for (final s in wirksameFerienSlots(b))
    if (s.start != null && s.ende != null) ...[
      ferienSlotKey(s.start!, 'endreinigung'),
      ferienSlotKey(s.start!, 'eroeffnung'),
    ],
};
