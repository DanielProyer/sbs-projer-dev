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

  /// Liegt in einem bereits abgeschlossenen Geschäftsjahr: wird gemeldet,
  /// aber NIE automatisch gebucht (siehe [BuchungNachholService.nachholen]).
  final bool gesperrt;

  const FehlendeBuchung(
    this.reinigung,
    this.betrieb,
    this.brutto, {
    this.gesperrt = false,
  });

  String get label => betrieb.ort != null && betrieb.ort!.isNotEmpty
      ? '${betrieb.name} ${betrieb.ort}'
      : betrieb.name;

  /// Eine Zeile für die Vorschau — gleiches Format wie in der Warnung der
  /// Forderungen-Liste, damit beide Listen vergleichbar bleiben.
  String get zeile {
    final d = reinigung.datum;
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year} · '
        '$label · ${brutto.toStringAsFixed(2)} CHF';
  }
}

class NachholErgebnis {
  final int gebucht;
  final int gesperrt;
  final List<String> fehler;
  const NachholErgebnis(this.gebucht, {this.gesperrt = 0, this.fehler = const []});
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
/// **Zwei Sicherungen**, weil hier ohne Rückfrage gebucht wird:
/// 1. Ein abgeschlossenes Geschäftsjahr wird nie nachträglich bebucht — der
///    Gewinn 2025 ist am 02.09.2026 ermittelt und die Bilanz erstellt. Solche
///    Fälle erscheinen als Befund, gebucht wird nur nach Rücksprache.
/// 2. Zwei Läufe gleichzeitig (zwei Tabs, Knopf + Abschluss) würden denselben
///    Ertrag doppelt buchen — auf `beleg_id` gibt es keinen Unique-Index.
///    Deshalb hängt sich ein zweiter Aufruf an den laufenden an.
class BuchungNachholService {
  /// Davor liegt die Excel-Historie ohne Einzelbuchungen — die darf ein
  /// Nachlauf nie anfassen (gleiche Grenze wie in ReinigungenOhneRechnung).
  static final stichtag = DateTime(2025, 12, 1);

  static Future<NachholErgebnis>? _laufend;

  static String _tag(DateTime d) => d.toIso8601String().split('T').first;

  /// Nur diese Spalten braucht die Prüfung — `select()` überträgt sonst über
  /// 2 MB, bei einem Aufruf pro Jahreswechsel im Audit-Screen.
  static const _spalten =
      'id, betrieb_id, datum, status, zahlungsart, ist_kulanz, '
      'ist_heineken_monteur, preis_brutto, preis_grundtarif, '
      'anzahl_haehne_eigen, anzahl_haehne_orion, anzahl_haehne_fremd, '
      'anzahl_haehne_wein, anzahl_haehne_anderer_standort, quelle';

  /// Frühester Tag, der automatisch gebucht werden darf: der 1. Januar des
  /// ersten Geschäftsjahres ohne Abschlussbuchung. Alles davor ist bilanziert.
  static Future<DateTime> nachbuchGrenze() async {
    final jetzt = DateTime.now();
    final vorjahr = jetzt.year - 1;
    final abschluss = await SupabaseService.client
        .from('buchungen')
        .select('id')
        .eq('user_id', SupabaseService.currentUser!.id)
        .eq('beleg_typ', 'abschluss')
        .lte('datum', '$vorjahr-12-31')
        .limit(1);
    // Vorjahr abgeschlossen -> erst ab 01.01. des laufenden Jahres buchen.
    final ab = abschluss.isEmpty
        ? DateTime(vorjahr, 1, 1)
        : DateTime(jetzt.year, 1, 1);
    return ab.isBefore(stichtag) ? stichtag : ab;
  }

  /// Findet abgeschlossene Reinigungen ohne Ertragsbuchung.
  /// [ab] begrenzt zusätzlich nach hinten (nie vor dem [stichtag]).
  static Future<List<FehlendeBuchung>> finde({DateTime? ab}) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final grenze = (ab != null && ab.isAfter(stichtag)) ? ab : stichtag;
    final gesperrtVor = await nachbuchGrenze();

    // Seitenweise laden: über 1000 Reinigungen liegen im Fenster, und ein
    // ungeteiltes select() liefert stumm nur die ersten 1000 — die ältesten
    // Fälle wären dauerhaft unsichtbar (Review-Befund 04.09.2026).
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var seite = 0; ; seite++) {
      final teil = List<Map<String, dynamic>>.from(
        await client
            .from('reinigungen')
            .select(_spalten)
            .eq('user_id', userId)
            .eq('status', 'abgeschlossen')
            .gte('datum', _tag(grenze))
            .neq('quelle', 'excel_import')
            .order('datum', ascending: false)
            .order('id')
            .range(seite * pageSize, (seite + 1) * pageSize - 1),
      );
      rows.addAll(teil);
      if (teil.length < pageSize) break;
    }
    if (rows.isEmpty) return [];

    final ids = rows
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();

    // Gezielt in Blöcken nachschlagen — dieselbe 1000-Zeilen-Falle.
    // Bewusst OHNE Storno-Filter: dieselbe Sicht wie der Duplikat-Check in
    // createFromReinigung (`getByBeleg`). Ein bewusst stornierter Ertrag darf
    // nicht automatisch wieder auferstehen.
    final hatBuchung = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final teil = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final bu = List<Map<String, dynamic>>.from(
        await client
            .from('buchungen')
            .select('beleg_id')
            .eq('user_id', userId)
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
      if (betrieb == null) {
        debugPrint('[Nachbuchung] Betrieb ${r.betriebId} fehlt — übersprungen');
        continue;
      }

      final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
      if (!brauchtErtragsbuchung(
        art: art,
        netto: ReinigungBuchungService.netto(r),
        istKulanz: r.istKulanz,
        istHeinekenMonteur: r.istHeinekenMonteur,
      )) {
        continue;
      }
      treffer.add(
        FehlendeBuchung(
          r,
          betrieb,
          r.preisBrutto ?? 0,
          gesperrt: r.datum.isBefore(gesperrtVor),
        ),
      );
    }
    return treffer;
  }

  /// Findet und bucht nach — nur, was nicht in einem abgeschlossenen
  /// Geschäftsjahr liegt. Ein Fehler bei einer Reinigung stoppt die übrigen
  /// nicht. Zwei gleichzeitige Aufrufe teilen sich denselben Lauf.
  static Future<NachholErgebnis> nachholen({DateTime? ab}) {
    return _laufend ??= _nachholenIntern(ab: ab).whenComplete(() {
      _laufend = null;
    });
  }

  static Future<NachholErgebnis> _nachholenIntern({DateTime? ab}) async {
    final offen = await finde(ab: ab);
    var gebucht = 0;
    var gesperrt = 0;
    final fehler = <String>[];
    for (final e in offen) {
      if (e.gesperrt) {
        gesperrt++;
        continue;
      }
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
    return NachholErgebnis(gebucht, gesperrt: gesperrt, fehler: fehler);
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
