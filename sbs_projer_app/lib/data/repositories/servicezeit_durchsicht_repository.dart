import 'package:sbs_projer_app/core/util/oeffnungszeiten_text.dart';
import 'package:sbs_projer_app/core/util/servicezeit_vorschlag.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ein einzelner Besuch, wie er unten auf der Karte steht.
class Besuch {
  final DateTime datum;
  final String von;
  final String? bis;
  const Besuch({required this.datum, required this.von, this.bis});

  String get zeile {
    final d =
        '${datum.day.toString().padLeft(2, '0')}.'
        '${datum.month.toString().padLeft(2, '0')}.${datum.year}';
    return '$d   $von${bis == null ? '' : '–$bis'}';
  }
}

/// Ein Betrieb in der Servicezeiten-Durchsicht: Stammdaten, bisher
/// hinterlegte Zeiten und der aus den Besuchen abgeleitete Vorschlag.
class ServicezeitKandidat {
  final String betriebId;
  final String name;
  final String? ort;
  final String? bisherMorgenAb;
  final String? bisherMorgenBis;
  final String? bisherNachmittagAb;
  final String? bisherNachmittagBis;
  final ServicezeitVorschlag vorschlag;

  /// Die zugrunde liegenden Besuche, neueste zuerst — damit sich der
  /// Vorschlag am Rohmaterial nachprüfen lässt.
  final List<Besuch> besuchsliste;

  /// Spanne und häufigste Startstunde über alle Besuche.
  final BesuchsUebersicht? uebersicht;

  /// Öffnungszeiten des Betriebs als eine Zeile — damit beim Festlegen der
  /// Servicezeit daneben steht, wann überhaupt offen ist.
  final String? oeffnungszeiten;

  const ServicezeitKandidat({
    required this.betriebId,
    required this.name,
    this.ort,
    this.bisherMorgenAb,
    this.bisherMorgenBis,
    this.bisherNachmittagAb,
    this.bisherNachmittagBis,
    required this.vorschlag,
    this.besuchsliste = const [],
    this.uebersicht,
    this.oeffnungszeiten,
  });

  String get label =>
      (ort == null || ort!.isEmpty) ? name : '$name, $ort';

  int get besuche =>
      vorschlag.morgenBesuche + vorschlag.nachmittagBesuche;

  bool get hatBisherZeiten =>
      bisherMorgenAb != null || bisherNachmittagAb != null;

  /// Womit die Felder starten: dem Vorschlag, wenn es einen gibt — sonst den
  /// bereits hinterlegten Zeiten.
  ///
  /// Der Rückfall ist wichtig: Ohne ihn stünde ein Betrieb ohne Datenbasis
  /// mit leeren Feldern da, und ein Wisch nach rechts würde seine bestehenden
  /// Servicezeiten löschen.
  ({String? morgenAb, String? morgenBis, String? nachmittagAb,
    String? nachmittagBis}) get vorbelegung => vorschlag.hatVorschlag
      ? (
          morgenAb: vorschlag.morgenAb,
          morgenBis: vorschlag.morgenBis,
          nachmittagAb: vorschlag.nachmittagAb,
          nachmittagBis: vorschlag.nachmittagBis,
        )
      : (
          morgenAb: bisherMorgenAb,
          morgenBis: bisherMorgenBis,
          nachmittagAb: bisherNachmittagAb,
          nachmittagBis: bisherNachmittagBis,
        );
}

/// Lädt die Betriebe für die Servicezeiten-Durchsicht und schreibt das
/// Ergebnis zurück.
///
/// Ohne Isar-/Offline-Pfad: Die Durchsicht wertet die gesamte Besuchshistorie
/// aus und läuft am Schreibtisch, nicht unterwegs.
class ServicezeitDurchsichtRepository {
  /// Besuche ab hier fliessen in den Vorschlag ein.
  static final _ab = DateTime(2019, 1, 1);

  static int? _minuten(dynamic zeit) {
    if (zeit == null) return null;
    final t = zeit.toString().split(':');
    if (t.length < 2) return null;
    final h = int.tryParse(t[0]);
    final m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Alle noch nicht geprüften aktiven Betriebe, mit Vorschlag.
  ///
  /// Reihenfolge: erst die mit der breitesten Datenbasis — dort sitzt der
  /// Vorschlag am sichersten und die Durchsicht kommt schnell voran.
  static Future<List<ServicezeitKandidat>> offeneBetriebe() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];
    final client = SupabaseService.client;

    final betriebe = List<Map<String, dynamic>>.from(
      await client
          .from('betriebe')
          .select(
            'id, name, ort, oeffnungszeiten, servicezeit_morgen_ab, '
            'servicezeit_morgen_bis, servicezeit_nachmittag_ab, '
            'servicezeit_nachmittag_bis',
          )
          .eq('user_id', userId)
          .eq('status', 'aktiv')
          .isFilter('servicezeit_geprueft_am', null)
          .order('name')
          .order('id'),
    );
    if (betriebe.isEmpty) return [];

    // Besuchszeiten seitenweise: über 7000 Reinigungen tragen Uhrzeiten, ein
    // ungeteiltes select() liefert stumm nur die ersten 1000.
    const pageSize = 1000;
    final zeiten = <String, List<Besuchszeit>>{};
    final besuche = <String, List<Besuch>>{};
    for (var seite = 0; ; seite++) {
      final teil = List<Map<String, dynamic>>.from(
        await client
            .from('reinigungen')
            .select('betrieb_id, datum, uhrzeit_start, uhrzeit_ende')
            .eq('user_id', userId)
            .eq('status', 'abgeschlossen')
            .gte('datum', _ab.toIso8601String().split('T').first)
            .order('datum')
            .order('id')
            .range(seite * pageSize, (seite + 1) * pageSize - 1),
      );
      for (final r in teil) {
        final bid = r['betrieb_id']?.toString();
        final start = _minuten(r['uhrzeit_start']);
        final ende = _minuten(r['uhrzeit_ende']) ?? start;
        if (bid == null || start == null || ende == null) continue;
        (zeiten[bid] ??= []).add(
          Besuchszeit(startMinuten: start, endeMinuten: ende),
        );
        final datum = DateTime.tryParse(r['datum']?.toString() ?? '');
        if (datum != null) {
          (besuche[bid] ??= []).add(
            Besuch(
              datum: datum,
              von: r['uhrzeit_start'].toString().substring(0, 5),
              bis: r['uhrzeit_ende']?.toString().substring(0, 5),
            ),
          );
        }
      }
      if (teil.length < pageSize) break;
    }

    final liste = [
      for (final b in betriebe)
        ServicezeitKandidat(
          betriebId: b['id'].toString(),
          name: b['name']?.toString() ?? '',
          ort: b['ort']?.toString(),
          bisherMorgenAb: b['servicezeit_morgen_ab']?.toString(),
          bisherMorgenBis: b['servicezeit_morgen_bis']?.toString(),
          bisherNachmittagAb: b['servicezeit_nachmittag_ab']?.toString(),
          bisherNachmittagBis: b['servicezeit_nachmittag_bis']?.toString(),
          vorschlag: servicezeitVorschlag(zeiten[b['id'].toString()] ?? []),
          besuchsliste: [
            // Neueste zuoberst — die letzten Besuche sagen am meisten
            // darüber, wie es heute läuft.
            ...(besuche[b['id'].toString()] ?? [])
              ..sort((x, y) => y.datum.compareTo(x.datum)),
          ],
          uebersicht: besuchsUebersicht(zeiten[b['id'].toString()] ?? []),
          oeffnungszeiten: oeffnungszeitenKompakt(
            b['oeffnungszeiten'] is Map<String, dynamic>
                ? b['oeffnungszeiten'] as Map<String, dynamic>
                : null,
          ),
        ),
    ];
    liste.sort((a, b) {
      final va = a.vorschlag.hatVorschlag ? 1 : 0;
      final vb = b.vorschlag.hatVorschlag ? 1 : 0;
      if (va != vb) return vb - va; // mit Vorschlag zuerst
      if (a.besuche != b.besuche) return b.besuche - a.besuche;
      return a.name.compareTo(b.name);
    });
    return liste;
  }

  /// Übernimmt die Zeiten und markiert den Betrieb als geprüft.
  /// Leere Felder werden bewusst als «keine Einschränkung» gespeichert.
  static Future<void> uebernehmen(
    String betriebId, {
    String? morgenAb,
    String? morgenBis,
    String? nachmittagAb,
    String? nachmittagBis,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    String? leerZuNull(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    await SupabaseService.client
        .from('betriebe')
        .update({
          'servicezeit_morgen_ab': leerZuNull(morgenAb),
          'servicezeit_morgen_bis': leerZuNull(morgenBis),
          'servicezeit_nachmittag_ab': leerZuNull(nachmittagAb),
          'servicezeit_nachmittag_bis': leerZuNull(nachmittagBis),
          'servicezeit_geprueft_am': DateTime.now().toIso8601String(),
        })
        .eq('id', betriebId)
        .eq('user_id', userId);
  }
}
