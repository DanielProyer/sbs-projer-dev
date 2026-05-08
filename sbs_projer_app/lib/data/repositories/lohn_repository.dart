import 'package:sbs_projer_app/data/models/lohn_einstellungen.dart';
import 'package:sbs_projer_app/data/models/lohn_abrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class LohnRepository {
  static String get _userId => SupabaseService.dataUserId;

  // ── Einstellungen ──

  static Future<LohnEinstellungen?> getEinstellungen(int jahr) async {
    final rows = await SupabaseService.client
        .from('lohn_einstellungen')
        .select()
        .eq('user_id', _userId)
        .eq('jahr', jahr)
        .limit(1);
    if (rows.isEmpty) return null;
    return LohnEinstellungen.fromJson(rows.first);
  }

  static Future<LohnEinstellungen> saveEinstellungen(
      LohnEinstellungen e) async {
    final json = e.toJson();
    json['user_id'] = _userId;
    final rows = await SupabaseService.client
        .from('lohn_einstellungen')
        .upsert(json, onConflict: 'user_id,jahr')
        .select();
    return LohnEinstellungen.fromJson(rows.first);
  }

  // ── Abrechnungen ──

  static Future<List<LohnAbrechnung>> getAbrechnungen(int jahr) async {
    final rows = await SupabaseService.client
        .from('lohn_abrechnungen')
        .select()
        .eq('user_id', _userId)
        .eq('jahr', jahr)
        .order('datum', ascending: false);
    return rows.map((r) => LohnAbrechnung.fromJson(r)).toList();
  }

  /// Berechnet die Lohnabrechnung aus den Einstellungen + variablem Bruttolohn.
  static LohnAbrechnung berechnen(
      LohnEinstellungen e, DateTime datum, double brutto) {
    final ahvAn = _runden5(brutto * e.ahvIvEoAnSatz / 100);
    final alvAn = _runden5(brutto * e.alvAnSatz / 100);
    final nbuAn = _runden5(brutto * e.nbuAnSatz / 100);
    final bvgAn = _runden5(e.bvgAnBetrag);
    final ktgAn = _runden5(brutto * e.ktgAnSatz / 100);
    final netto = _runden5(brutto - ahvAn - alvAn - nbuAn - bvgAn - ktgAn);

    final ahvAg = _runden5(brutto * e.ahvIvEoAgSatz / 100);
    final alvAg = _runden5(brutto * e.alvAgSatz / 100);
    final buAg = _runden5(brutto * e.buAgSatz / 100);
    final fakAg = _runden5(brutto * e.fakAgSatz / 100);
    final bvgAg = _runden5(e.bvgAgBetrag);
    final ktgAg = _runden5(brutto * e.ktgAgSatz / 100);

    return LohnAbrechnung(
      id: '',
      userId: _userId,
      jahr: datum.year,
      monat: datum.month,
      datum: datum,
      bruttolohn: brutto,
      ahvIvEoAn: ahvAn,
      alvAn: alvAn,
      nbuAn: nbuAn,
      bvgAn: bvgAn,
      ktgAn: ktgAn,
      nettolohn: netto,
      ahvIvEoAg: ahvAg,
      alvAg: alvAg,
      buAg: buAg,
      fakAg: fakAg,
      bvgAg: bvgAg,
      ktgAg: ktgAg,
    );
  }

  /// Speichert die Abrechnung und erstellt alle Buchungen.
  static Future<LohnAbrechnung> lohnlaufBuchen(LohnAbrechnung abr) async {
    // 1. Abrechnung speichern
    final json = abr.toJson();
    json['user_id'] = _userId;
    json['ist_gebucht'] = true;
    final rows = await SupabaseService.client
        .from('lohn_abrechnungen')
        .insert(json)
        .select();
    final saved = LohnAbrechnung.fromJson(rows.first);

    // 2. Buchungen erstellen
    final datumStr = abr.datum.toIso8601String().split('T').first;
    final prefix = 'Lohn ${abr.datumFormatiert}';

    // Bruttolohn: 5000 → 2002
    await _buche(datumStr, 5000, 2002, abr.bruttolohn, '$prefix: Bruttolohn',
        abr.jahr, abr.monat, saved.id);

    // AN-Abzüge: 2002 → Passivkonten
    if (abr.ahvIvEoAn > 0) {
      await _buche(datumStr, 2002, 2270, abr.ahvIvEoAn,
          '$prefix: AHV/IV/EO AN', abr.jahr, abr.monat, saved.id);
    }
    if (abr.alvAn > 0) {
      await _buche(datumStr, 2002, 2270, abr.alvAn,
          '$prefix: ALV AN', abr.jahr, abr.monat, saved.id);
    }
    if (abr.nbuAn > 0) {
      await _buche(datumStr, 2002, 2272, abr.nbuAn,
          '$prefix: NBU AN', abr.jahr, abr.monat, saved.id);
    }
    if (abr.bvgAn > 0) {
      await _buche(datumStr, 2002, 2271, abr.bvgAn,
          '$prefix: BVG AN', abr.jahr, abr.monat, saved.id);
    }
    if (abr.ktgAn > 0) {
      await _buche(datumStr, 2002, 2273, abr.ktgAn,
          '$prefix: KTG AN', abr.jahr, abr.monat, saved.id);
    }

    // Nettolohn: 2002 → 1020 (Bank)
    await _buche(datumStr, 2002, 1020, abr.nettolohn,
        '$prefix: Nettolohn Auszahlung', abr.jahr, abr.monat, saved.id);

    // AG-Beiträge: Aufwandkonten → Passivkonten
    if (abr.ahvIvEoAg > 0) {
      await _buche(datumStr, 5700, 2270, abr.ahvIvEoAg,
          '$prefix: AHV/IV/EO AG', abr.jahr, abr.monat, saved.id);
    }
    if (abr.alvAg > 0) {
      await _buche(datumStr, 5700, 2270, abr.alvAg,
          '$prefix: ALV AG', abr.jahr, abr.monat, saved.id);
    }
    if (abr.buAg > 0) {
      await _buche(datumStr, 5730, 2272, abr.buAg,
          '$prefix: BU/UVG AG', abr.jahr, abr.monat, saved.id);
    }
    if (abr.fakAg > 0) {
      await _buche(datumStr, 5710, 2270, abr.fakAg,
          '$prefix: FAK AG', abr.jahr, abr.monat, saved.id);
    }
    if (abr.bvgAg > 0) {
      await _buche(datumStr, 5720, 2271, abr.bvgAg,
          '$prefix: BVG AG', abr.jahr, abr.monat, saved.id);
    }
    if (abr.ktgAg > 0) {
      await _buche(datumStr, 5740, 2273, abr.ktgAg,
          '$prefix: KTG AG', abr.jahr, abr.monat, saved.id);
    }

    return saved;
  }

  static Future<void> _buche(String datum, int soll, int haben,
      double betrag, String beschreibung, int jahr, int monat,
      String lohnAbrechnungId) async {
    await BuchungRepository.create({
      'datum': datum,
      'soll_konto': soll,
      'haben_konto': haben,
      'betrag_netto': betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': betrag,
      'beschreibung': beschreibung,
      'geschaeftsjahr': jahr,
      'monat': monat,
      'belegordner': 'lohn',
      'beleg_id': lohnAbrechnungId,
    });
  }

  /// Löscht eine Abrechnung per ID und alle zugehörigen Buchungen.
  static Future<void> abrechnungLoeschen(String abrechnungId) async {
    // Buchungen mit beleg_id = abrechnungId löschen
    await BuchungRepository.deleteByBeleg(abrechnungId);

    // Abrechnung löschen
    await SupabaseService.client
        .from('lohn_abrechnungen')
        .delete()
        .eq('id', abrechnungId);
  }

  // ── Jahrestotale für Lohnausweis ──

  static Future<Map<String, double>> jahresTotale(int jahr) async {
    final abrechnungen = await getAbrechnungen(jahr);
    double brutto = 0, ahvAn = 0, alvAn = 0, nbuAn = 0, bvgAn = 0, ktgAn = 0;
    double netto = 0, ahvAg = 0, alvAg = 0, buAg = 0, fakAg = 0, bvgAg = 0, ktgAg = 0;

    for (final a in abrechnungen) {
      brutto += a.bruttolohn;
      ahvAn += a.ahvIvEoAn;
      alvAn += a.alvAn;
      nbuAn += a.nbuAn;
      bvgAn += a.bvgAn;
      ktgAn += a.ktgAn;
      netto += a.nettolohn;
      ahvAg += a.ahvIvEoAg;
      alvAg += a.alvAg;
      buAg += a.buAg;
      fakAg += a.fakAg;
      bvgAg += a.bvgAg;
      ktgAg += a.ktgAg;
    }

    return {
      'brutto': brutto,
      'ahv_an': ahvAn,
      'alv_an': alvAn,
      'nbu_an': nbuAn,
      'bvg_an': bvgAn,
      'ktg_an': ktgAn,
      'netto': netto,
      'ahv_ag': ahvAg,
      'alv_ag': alvAg,
      'bu_ag': buAg,
      'fak_ag': fakAg,
      'bvg_ag': bvgAg,
      'ktg_ag': ktgAg,
      'total_an_abzuege': ahvAn + alvAn + nbuAn + bvgAn + ktgAn,
      'total_ag_beitraege': ahvAg + alvAg + buAg + fakAg + bvgAg + ktgAg,
      'anzahl_auszahlungen': abrechnungen.length.toDouble(),
    };
  }

  static double _runden5(double betrag) {
    return (betrag * 20).round() / 20;
  }
}
