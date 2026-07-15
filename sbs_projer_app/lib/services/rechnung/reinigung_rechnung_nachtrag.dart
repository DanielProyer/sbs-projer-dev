import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/mappers/reinigung_mapper.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Eine abgeschlossene Reinigung ohne Rechnung.
class NachtragKandidat {
  final String reinigungId;
  final DateTime datum;
  final String betriebName;
  final String rechnungsstellung;
  final double brutto;

  /// Nach dem Lauf gesetzt: null = erfolgreich, sonst der Fehlertext.
  String? fehler;

  /// Der Rechnungs-Service hat bewusst null geliefert (kein Rechnungs-Betrieb).
  bool uebersprungen = false;

  /// Betrag, den die Rechnung bekommen WIRD — im Trockenlauf vorausberechnet
  /// mit demselben Code, der ihn danach schreibt.
  double? berechnetBrutto;

  NachtragKandidat({
    required this.reinigungId,
    required this.datum,
    required this.betriebName,
    required this.rechnungsstellung,
    required this.brutto,
  });

  String get zeile {
    final d = '${datum.day.toString().padLeft(2, '0')}.'
        '${datum.month.toString().padLeft(2, '0')}.${datum.year}';
    final b = berechnetBrutto;
    // Weicht der berechnete Betrag von der Reinigung ab, muss man das SEHEN,
    // bevor 38 Rechnungen entstehen.
    final betrag = b == null || b == brutto
        ? '${brutto.toStringAsFixed(2)} CHF'
        : '${brutto.toStringAsFixed(2)} → ${b.toStringAsFixed(2)} CHF  ⚠';
    return '$d · $betriebName · $betrag';
  }
}

class NachtragErgebnis {
  final List<NachtragKandidat> kandidaten;
  const NachtragErgebnis(this.kandidaten);

  int get erstellt =>
      kandidaten.where((k) => k.fehler == null && !k.uebersprungen).length;
  int get uebersprungen => kandidaten.where((k) => k.uebersprungen).length;
  List<NachtragKandidat> get fehlgeschlagen =>
      kandidaten.where((k) => k.fehler != null).toList();
  double get summe => kandidaten.fold<double>(0, (s, k) => s + k.brutto);
}

/// Trägt Kundenrechnungen für abgeschlossene Reinigungen nach, bei denen beim
/// Abschluss keine erzeugt wurde (26.06.–13.07.2026, 38 Tresen-Fälle).
///
/// **Einmal-Werkzeug.** Nach dem Lauf wieder entfernen — die Ursache gehört
/// behoben, nicht dauerhaft repariert.
///
/// Wichtig zur Abgrenzung:
/// - Erzeugt **keine Buchung**. Die Ertragsbuchungen dieser Reinigungen wurden
///   am 14.07. bereits nachgetragen; [RechnungService.createFromReinigung]
///   bucht nicht, das macht der getrennte ReinigungBuchungService.
/// - Versendet **keine Mail**. Mail geht nur bei `rechnung_mail` raus, und die
///   betroffenen Fälle sind alle `rechnung_tresen`. Sicherheitshalber
///   überspringt [nachtragen] `rechnung_mail` trotzdem per Vorgabe — sonst
///   bekäme ein Kunde drei Wochen später unerwartet Post.
/// - Setzt `versendet_am` auf das Reinigungsdatum: Bei Tresen erhält der Kunde
///   Protokoll und Einzahlungsschein vor Ort, die Rechnung gilt als abgegeben.
///
/// Diagnose-Zweck: Der Lauf geht durch exakt denselben Code, der beim Abschluss
/// still scheiterte. [NachtragKandidat.fehler] macht die damals verschluckte
/// Ausnahme sichtbar.
class ReinigungRechnungNachtrag {
  /// Nur Reinigungen ab hier — davor ist die Historie über den Excel-Import
  /// abgedeckt, ein Nachtrag würde doppelt erfassen.
  static const stichtag = '2026-06-26';

  /// NUR Tresen. Bei `rechnung_mail`/`rechnung_post` merkt Daniel den Ausfall
  /// sofort selbst (keine Mail ging raus, nichts zu drucken) — und
  /// `versendet_am = Reinigungsdatum` wäre dort schlicht gelogen, weil nichts
  /// übergeben wurde. Der belegte Ausfall betrifft ohnehin nur Tresen.
  static const _nurNachtragen = {'rechnung_tresen'};

  static Future<NachtragErgebnis> nachtragen({bool dryRun = true}) async {
    final client = SupabaseService.client;
    final userId = SupabaseService.currentUser!.id;

    // 1. Abgeschlossene Reinigungen ab Stichtag.
    final rows = List<Map<String, dynamic>>.from(
      await client
          .from('reinigungen')
          .select()
          .eq('user_id', userId)
          .eq('status', 'abgeschlossen')
          .gte('datum', stichtag)
          .order('datum'),
    );

    // 2. Bereits verrechnete Reinigungen (Verknüpfung läuft über die Position).
    //    GEZIELT für genau diese Reinigungen abfragen — ein `select()` über die
    //    ganze Tabelle liefert nur die ersten 1000 Zeilen (PostgREST-Limit), und
    //    alles darüber hinaus gälte fälschlich als unverrechnet. Bei ~5000
    //    Positionen hätte das echte Doppelrechnungen erzeugt.
    final alleIds = rows
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();
    final verrechnet = <String>{};
    for (var i = 0; i < alleIds.length; i += 200) {
      final teil = alleIds.sublist(i, (i + 200).clamp(0, alleIds.length));
      final posRows = List<Map<String, dynamic>>.from(
        await client
            .from('rechnungs_positionen')
            .select('service_id')
            .eq('service_typ', 'reinigung')
            .inFilter('service_id', teil),
      );
      for (final p in posRows) {
        final id = p['service_id']?.toString();
        if (id != null && id.isNotEmpty) verrechnet.add(id);
      }
    }

    // 3. Lücken sammeln.
    final kandidaten = <NachtragKandidat>[];
    final reinigungen = <String, dynamic>{};
    for (final row in rows) {
      final r = ReinigungMapper.fromDto(Reinigung.fromJson(row));
      final sid = r.serverId;
      if (sid == null || verrechnet.contains(sid)) continue;
      if (r.istKulanz || r.istHeinekenMonteur) continue;

      final betrieb = await BetriebRepository.getByServerId(r.betriebId);
      if (betrieb == null) continue;
      final art = betrieb.rechnungsstellung;
      if (!RechnungService.brauchtRechnung(art)) continue;
      if (!_nurNachtragen.contains(art)) continue;

      kandidaten.add(NachtragKandidat(
        reinigungId: sid,
        datum: r.datum,
        betriebName: betrieb.ort != null && betrieb.ort!.isNotEmpty
            ? '${betrieb.name} ${betrieb.ort}'
            : betrieb.name,
        rechnungsstellung: art,
        brutto: r.preisBrutto ?? 0,
      ));
      reinigungen[sid] = [r, betrieb];
    }

    if (dryRun) {
      // Betrag mit demselben Code vorausberechnen, der ihn danach schreibt.
      for (final k in kandidaten) {
        final paar = reinigungen[k.reinigungId] as List;
        try {
          k.berechnetBrutto = await RechnungService.vorschauBrutto(paar[0]);
        } catch (e) {
          k.fehler = e.toString();
        }
      }
      return NachtragErgebnis(kandidaten);
    }

    // 4. Rechnungen erzeugen — Fehler pro Fall festhalten, nicht abbrechen.
    for (final k in kandidaten) {
      final paar = reinigungen[k.reinigungId] as List;
      try {
        // Letzter Schutz vor einer Doppelrechnung: unmittelbar vor dem Anlegen
        // nochmals gezielt für GENAU diese Reinigung prüfen. Die Mengenabfrage
        // oben kann irren (sie tat es bereits, siehe 1000-Zeilen-Limit) — diese
        // Einzelabfrage kann es nicht.
        final schon = await RechnungsPositionRepository.getRechnungIdByServiceId(
            k.reinigungId);
        if (schon != null) {
          k.uebersprungen = true;
          continue;
        }

        final rechnung =
            await RechnungService.createFromReinigung(paar[0], paar[1]);
        if (rechnung == null) {
          k.uebersprungen = true;
          continue;
        }
        // Bei Tresen wurde die Rechnung dem Kunden vor Ort abgegeben.
        await RechnungRepository.update(rechnung.id, {
          'versendet_am': k.datum.toIso8601String().split('T').first,
        });
      } catch (e) {
        debugPrint('[RechnungNachtrag] ${k.reinigungId}: $e');
        k.fehler = e.toString();
      }
    }

    return NachtragErgebnis(kandidaten);
  }
}
