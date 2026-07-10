import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

/// Kennzahlen über eine Anlagenliste (nur aktive Anlagen zählen).
class AnlagenKennzahlen {
  final int gesamt;
  final Map<String, int> nachTyp;
  final int ueberfaellig;
  final int ohneRhythmus;
  AnlagenKennzahlen({
    required this.gesamt,
    required this.nachTyp,
    required this.ueberfaellig,
    required this.ohneRhythmus,
  });
}

const _bekannteTypen = {'Warmanstich', 'Kaltanstich', 'Buffetanstich', 'Orion'};

AnlagenKennzahlen anlagenKennzahlen(List<AnlageLocal> anlagen, DateTime jetzt) {
  final aktive = anlagen.where((a) => a.status == 'aktiv').toList();
  final nachTyp = <String, int>{};
  var ueberfaellig = 0;
  var ohneRhythmus = 0;
  for (final a in aktive) {
    final typ = _bekannteTypen.contains(a.typAnlage) ? a.typAnlage : 'Sonstige';
    nachTyp[typ] = (nachTyp[typ] ?? 0) + 1;
    final n = a.naechsteReinigung;
    if (n != null && n.isBefore(jetzt)) ueberfaellig++;
    final r = a.reinigungRhythmus.trim().toLowerCase();
    if (r.isEmpty || r == 'keiner') ohneRhythmus++;
  }
  return AnlagenKennzahlen(
    gesamt: aktive.length,
    nachTyp: nachTyp,
    ueberfaellig: ueberfaellig,
    ohneRhythmus: ohneRhythmus,
  );
}

String _safe(String s) => s
    .trim()
    .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
    .replaceAll(' ', '-')
    .replaceAll(RegExp('-+'), '-');

/// Dateiname für den Steckbrief (z. B. `Steckbrief_Sonne_Warm-1.pdf`).
String anlageSteckbriefDateiname(String betriebName, String anlageBezeichnung) {
  final b = _safe(betriebName.isEmpty ? 'Betrieb' : betriebName);
  final a = _safe(anlageBezeichnung.isEmpty ? 'Anlage' : anlageBezeichnung);
  return 'Steckbrief_${b}_$a.pdf';
}

/// Mail-Betreff für den Steckbrief.
String anlageMailBetreff(String betriebName, String anlageBezeichnung) {
  final a = anlageBezeichnung.isEmpty ? 'Anlage' : anlageBezeichnung;
  return 'Anlagen-Steckbrief: $betriebName — $a';
}
