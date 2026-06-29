import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_kategorie_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kreditor_regel_repository.dart';

/// Eingangsrechnungen (Kreditoren) für die Listen-/Bestätigungsansicht.
/// Lädt alle relevanten Stati (ohne `verworfen`).
final eingangsrechnungenProvider =
    FutureProvider<List<Eingangsrechnung>>((ref) async {
  return EingangsrechnungRepository.getByStatus(const [
    'erkannt',
    'bestaetigt',
    'gebucht',
    'zahlung_vorgemerkt',
    'exportiert',
    'bezahlt',
    'abgelegt',
  ]);
});

/// Lieferanten-Lernregeln (Kreditor-Vorbelegung) für den Verwaltungs-Screen.
/// Liefert alle Regeln (inkl. inaktive), höchste Priorität zuerst.
final kreditorRegelnProvider =
    FutureProvider<List<KreditorRegel>>((ref) async {
  return KreditorRegelRepository.getAll();
});

/// Eingangsrechnung-Kategorien (Config, global). Für Dropdown + Konto-Vorschlag.
final eingangsrechnungKategorienProvider =
    FutureProvider<List<EingangsrechnungKategorie>>((ref) async {
  return EingangsrechnungKategorieRepository.getAll();
});
