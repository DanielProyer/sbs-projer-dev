import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Eine abgeschlossene Reinigung, die gebucht gehört, aber keine Buchung hat.
class FehlendeBuchung {
  final ReinigungLocal reinigung;
  final BetriebLocal betrieb;
  final double brutto;
  const FehlendeBuchung(this.reinigung, this.betrieb, this.brutto);

  String get label => betrieb.ort != null && betrieb.ort!.isNotEmpty
      ? '${betrieb.name} ${betrieb.ort}'
      : betrieb.name;
}

class NachholErgebnis {
  final int gebucht;
  final List<String> fehler;
  const NachholErgebnis(this.gebucht, this.fehler);
  bool get leer => gebucht == 0 && fehler.isEmpty;
}

/// Holt Ertragsbuchungen nach, die beim Abschluss einer Reinigung nicht
/// zustande kamen.
///
/// **Warum es das gibt (04.09.2026):** Beim Abschliessen läuft im Browser eine
/// Kette von rund zehn Serveranfragen. Wird das Handy in dem Moment
/// weggesteckt oder bricht die Verbindung ab, friert der Tab ein und der Rest
/// der Kette geht verloren. Die Buchung ist der letzte Schritt und damit das
/// erste Opfer: Am 03.09. (Kreuz Inwil) und 04.09. (Vincenz) fehlte je die
/// Ertragsbuchung, einmal ganz ohne Fehlermeldung. Rechnung und Protokoll
/// waren da, der Ertrag fehlte in der Erfolgsrechnung.
///
/// Die Suche ist idempotent: [ReinigungBuchungService.createFromReinigung]
/// prüft selbst noch einmal auf eine vorhandene Buchung.
class BuchungNachholService {
  /// Davor liegt die Excel-Historie ohne Einzelbuchungen — die darf ein
  /// Nachlauf nie anfassen (gleiche Grenze wie in ReinigungenOhneRechnung).
  static final stichtag = DateTime(2025, 12, 1);

  static String _tag(DateTime d) => d.toIso8601String().split('T').first;

  /// Findet abgeschlossene Reinigungen ohne Ertragsbuchung.
  /// [ab] begrenzt zusätzlich nach hinten (nie vor dem [stichtag]).
  static Future<List<FehlendeBuchung>> finde({DateTime? ab}) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final grenze = (ab != null && ab.isAfter(stichtag)) ? ab : stichtag;
    final rows = List<Map<String, dynamic>>.from(
      await client
          .from('reinigungen')
          .select()
          .eq('user_id', userId)
          .eq('status', 'abgeschlossen')
          .gte('datum', _tag(grenze))
          .neq('quelle', 'excel_import')
          .order('datum', ascending: false)
          .order('id'),
    );
    if (rows.isEmpty) return [];

    final ids = rows
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();

    // Gezielt in Blöcken nachschlagen: ein select() über die ganze
    // Buchungstabelle liefert nur die ersten 1000 Zeilen und würde vorhandene
    // Buchungen übersehen — dann würde doppelt gebucht.
    final hatBuchung = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final teil = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final bu = List<Map<String, dynamic>>.from(
        await client
            .from('buchungen')
            .select('beleg_id')
            .eq('user_id', userId)
            .eq('ist_storniert', false)
            .inFilter('beleg_id', teil),
      );
      for (final b in bu) {
        final id = b['beleg_id']?.toString();
        if (id != null && id.isNotEmpty) hatBuchung.add(id);
      }
    }

    final betriebe = {
      for (final b in await BetriebRepository.getAll())
        if (b.serverId != null) b.serverId!: b,
    };

    final treffer = <FehlendeBuchung>[];
    for (final row in rows) {
      final r = ReinigungMapper.fromDto(Reinigung.fromJson(row));
      final sid = r.serverId;
      if (sid == null || hatBuchung.contains(sid)) continue;
      final betrieb = betriebe[r.betriebId];
      if (betrieb == null) continue;

      final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
      if (!brauchtErtragsbuchung(
        art: art,
        netto: ReinigungBuchungService.netto(r),
        istKulanz: r.istKulanz,
        istHeinekenMonteur: r.istHeinekenMonteur,
      )) {
        continue;
      }
      treffer.add(FehlendeBuchung(r, betrieb, r.preisBrutto ?? 0));
    }
    return treffer;
  }

  /// Findet und bucht nach. Ein Fehler bei einer Reinigung stoppt die
  /// übrigen nicht — gemeldet wird alles.
  static Future<NachholErgebnis> nachholen({DateTime? ab}) async {
    final offen = await finde(ab: ab);
    var gebucht = 0;
    final fehler = <String>[];
    for (final e in offen) {
      try {
        final b = await ReinigungBuchungService.createFromReinigung(
          e.reinigung,
          e.betrieb,
        );
        if (b != null) gebucht++;
      } catch (fehlschlag) {
        debugPrint('[Nachbuchung] ${e.label}: $fehlschlag');
        fehler.add('${e.label}: $fehlschlag');
      }
    }
    return NachholErgebnis(gebucht, fehler);
  }

  /// Für die Abschlussprüfung: nur die Anzeige-Daten, ohne zu buchen.
  static Future<List<UnverbuchteReinigung>> fuerAbschluss() async {
    final offen = await finde();
    return [
      for (final e in offen)
        UnverbuchteReinigung(
          datum: e.reinigung.datum,
          betrieb: e.label,
          brutto: e.brutto,
        ),
    ];
  }
}
