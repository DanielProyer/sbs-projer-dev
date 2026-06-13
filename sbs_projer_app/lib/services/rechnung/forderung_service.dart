import '../../data/models/rechnung.dart';

/// Zentrale Forderungs-Logik: empfohlene Mahn-Aktion (bildet
/// view_mahnwesen_dashboard in Dart ab).
class ForderungService {
  static String empfohleneAktion(Rechnung r, {DateTime? heute}) {
    final h = heute ?? DateTime.now();
    if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') {
      return 'warten';
    }
    if (r.rechnungstyp == 'heineken_monat') return 'warten';
    int tage(DateTime d) => h.difference(d).inDays;
    switch (r.zahlungsstatus) {
      case 'offen':
        return tage(r.faelligkeitsdatum) >= 5 ? 'erinnerung_faellig' : 'warten';
      case 'erinnert':
        return (r.erinnerungAm != null && tage(r.erinnerungAm!) >= 25)
            ? 'mahnung_1_faellig'
            : 'warten';
      case 'mahnung_1':
        return (r.mahnung1Am != null && tage(r.mahnung1Am!) >= 30)
            ? 'mahnung_2_faellig'
            : 'warten';
      case 'mahnung_2':
        return 'eskalation';
      default:
        return 'warten';
    }
  }

  static bool istMahnfaellig(Rechnung r, {DateTime? heute}) =>
      empfohleneAktion(r, heute: heute) != 'warten';
}
