import 'package:sbs_projer_app/data/repositories/kreditor_regel_repository.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_matcher.dart';

/// Lernt Lieferanten-Vorbelegungen aus bestätigten Eingangsrechnungen.
///
/// Wird nach dem erfolgreichen Buchen (Stufe 1) aufgerufen. Legt für einen
/// neuen Lieferanten eine [KreditorRegel] an oder aktualisiert eine bestehende,
/// wenn der User das Aufwandskonto korrigiert hat (Korrektur-Lernen).
class KreditorLernService {
  /// Lernt aus den finalen Werten einer bestätigten Eingangsrechnung.
  ///
  /// - Ohne [ausstellerName] (null/leer) passiert nichts.
  /// - Existiert keine passende Regel → neue Regel anlegen (`lernquelle: scan`).
  /// - Existiert eine Regel mit abweichendem Aufwandskonto → Regel aktualisieren
  ///   (User hat korrigiert).
  /// - Existiert eine Regel mit gleichem Aufwandskonto → nichts tun.
  static Future<void> lerne({
    required String? ausstellerName,
    String? iban,
    String? referenz,
    required int aufwandskonto,
    int? vorsteuerKonto,
    double? mwstSatz,
    required bool mwstPflichtig,
  }) async {
    final name = ausstellerName?.trim();
    if (name == null || name.isEmpty) return;

    final regeln = await KreditorRegelRepository.getAllActive();
    final m = matchKreditorRegel(
      regeln,
      ausstellerName: name,
      iban: iban,
      referenz: referenz,
    );

    final nowIso = DateTime.now().toIso8601String();

    if (m == null) {
      // Neuer Lieferant → Regel anlegen.
      await KreditorRegelRepository.create({
        'lieferant_name_pattern': name,
        'lieferant_iban': iban,
        'aufwandskonto': aufwandskonto,
        'vorsteuer_konto': vorsteuerKonto,
        'mwst_satz_percent': mwstSatz,
        'mwst_pflichtig': mwstPflichtig,
        'prioritaet': 10,
        'ist_aktiv': true,
        'lernquelle': 'scan',
        'gelernt_am': nowIso,
      });
    } else if (m.aufwandskonto != aufwandskonto) {
      // User hat korrigiert → bestehende Regel aktualisieren.
      await KreditorRegelRepository.update(m.id, {
        'aufwandskonto': aufwandskonto,
        'vorsteuer_konto': vorsteuerKonto,
        'mwst_satz_percent': mwstSatz,
        'mwst_pflichtig': mwstPflichtig,
        'gelernt_am': nowIso,
      });
    }
    // sonst: passende Regel ohne Korrektur → nichts tun.
  }
}
