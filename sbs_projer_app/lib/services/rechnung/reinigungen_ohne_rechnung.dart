import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Eine abgeschlossene Reinigung, die eine Kundenrechnung bräuchte — aber keine hat.
class ReinigungOhneRechnung {
  final String reinigungId;
  final DateTime datum;
  final String betriebName;
  final double brutto;
  final bool fehltBuchung;

  const ReinigungOhneRechnung({
    required this.reinigungId,
    required this.datum,
    required this.betriebName,
    required this.brutto,
    this.fehltBuchung = false,
  });

  String get zeile =>
      '${datum.day.toString().padLeft(2, '0')}.'
      '${datum.month.toString().padLeft(2, '0')}.${datum.year} · '
      '$betriebName · ${brutto.toStringAsFixed(2)} CHF'
      '${fehltBuchung ? ' · OHNE BUCHUNG' : ''}';
}

/// Findet abgeschlossene Reinigungen ohne Kundenrechnung.
///
/// **Warum es das gibt:** Zwischen dem 26.06. und 13.07.2026 blieben 38
/// Tresen-Reinigungen ohne Rechnung (CHF 3'656.05) — drei Wochen lang
/// unbemerkt, weil bei Tresen Protokoll und Einzahlungsschein direkt aus der
/// Reinigung kommen und ohne Rechnung funktionieren. Die Ursache ist bis heute
/// ungeklärt und nicht reproduzierbar. Diese Prüfung interessiert sich nicht
/// dafür, WARUM eine Rechnung fehlt — sie zeigt, DASS eine fehlt. Das wirkt bei
/// jeder Ursache, auch bei einer, die nie verstanden wird.
///
/// Sie meldet nur, sie repariert nichts: Nachholen geht über den bestehenden
/// Weg im Reinigungs-Detail.
class ReinigungenOhneRechnung {
  /// Davor liegt die Excel-Historie — die ist über den Voll-Import abgedeckt und
  /// hat bewusst keine Einzelrechnungen (1519 Zeilen). Würde man sie mitzählen,
  /// stünde die Warnung dauerhaft auf Alarm und wäre wertlos.
  static final stichtag = DateTime(2025, 12, 1);

  static Future<List<ReinigungOhneRechnung>> finde() async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser!.id;

    final rows = List<Map<String, dynamic>>.from(
      await client
          .from('reinigungen')
          .select()
          .eq('user_id', userId)
          .eq('status', 'abgeschlossen')
          .gte('datum', stichtag.toIso8601String().split('T').first)
          .neq('quelle', 'excel_import')
          .order('datum', ascending: false),
    );
    if (rows.isEmpty) return [];

    // Verrechnete Reinigungen GEZIELT nachschlagen, in Blöcken. Ein select()
    // über die ganze Positionstabelle liefert nur die ersten 1000 Zeilen — bei
    // ~5000 Positionen würden Rechnungen übersehen und die Warnung schlüge
    // grundlos Alarm. (Genau dieser Fehler ist am 15.07. im Nachtrag passiert.)
    final ids = rows
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();
    final verrechnet = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final teil = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final pos = List<Map<String, dynamic>>.from(
        await client
            .from('rechnungs_positionen')
            .select('service_id')
            .eq('service_typ', 'reinigung')
            .inFilter('service_id', teil),
      );
      for (final p in pos) {
        final id = p['service_id']?.toString();
        if (id != null && id.isNotEmpty) verrechnet.add(id);
      }
    }

    // Tatsächliche Verbuchung je Reinigung: Kasse (1000) = bar erledigt,
    // KEINE Rechnung nötig (Entscheid Daniel 16.07. — die Betriebs-Einstellung
    // kann sich seither geändert haben). Debitor (1100) erwartet eine Rechnung.
    final kasseGebucht = <String>{};
    final hatBuchung = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final teil = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final bu = List<Map<String, dynamic>>.from(
        await client
            .from('buchungen')
            .select('beleg_id, soll_konto, beleg_typ')
            .inFilter('beleg_id', teil)
            .eq('ist_storniert', false),
      );
      for (final b in bu) {
        final id = b['beleg_id']?.toString();
        if (id == null || id.isEmpty) continue;
        hatBuchung.add(id);
        if (b['beleg_typ'] == 'rechnung' &&
            (b['soll_konto'] as num?)?.toInt() == 1000) {
          kasseGebucht.add(id);
        }
      }
    }

    final treffer = <ReinigungOhneRechnung>[];
    for (final row in rows) {
      final r = ReinigungMapper.fromDto(Reinigung.fromJson(row));
      final sid = r.serverId;
      if (sid == null) continue;
      if (r.istKulanz || r.istHeinekenMonteur) continue;

      final betrieb = await BetriebRepository.getByServerId(r.betriebId);
      if (betrieb == null) continue;

      final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
      final grund = warnungsGrund(
        art: art,
        hatRechnung: verrechnet.contains(sid),
        hatBuchung: hatBuchung.contains(sid),
        kasseGebucht: kasseGebucht.contains(sid),
      );
      if (grund == null) continue;

      treffer.add(
        ReinigungOhneRechnung(
          reinigungId: sid,
          datum: r.datum,
          betriebName: betrieb.ort != null && betrieb.ort!.isNotEmpty
              ? '${betrieb.name} ${betrieb.ort}'
              : betrieb.name,
          brutto: r.preisBrutto ?? 0,
          fehltBuchung: grund == WarnungsGrund.ohneBuchung,
        ),
      );
    }
    return treffer;
  }
}
