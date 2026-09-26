import 'package:sbs_projer_app/core/util/mwst_satz.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';

export 'package:sbs_projer_app/core/util/mwst_satz.dart';

/// MwSt-Satz für eine Leistung am [datum], aus der an diesem Tag gültigen
/// Preisliste (`preise.mwst_satz`) — dieselbe Quelle wie bisher. Fehlt eine
/// Preisliste, gilt [MwstAngabe.fallback].
///
/// Kein Zwischenspeicher über Aufrufe hinweg — genau der war der Fehler
/// (siehe `core/util/mwst_satz.dart`).
Future<MwstAngabe> mwstAusPreisliste(DateTime datum) async {
  final preis = await PreisRepository.getAktuell(datum: datum);
  if (preis == null) return MwstAngabe.fallback;
  return MwstAngabe(prozent: preis.mwstSatz, faktor: preis.mwstFaktor);
}

/// Nur der Faktor (0.081) für [datum] — siehe [mwstAusPreisliste].
Future<double> mwstFaktorFuer(DateTime datum) async =>
    (await mwstAusPreisliste(datum)).faktor;
