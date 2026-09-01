import 'package:intl/intl.dart';

/// Ergebnis einer Saldo-Prüfung (camt-Saldo gegen Journal).
class SaldoCheck {
  final bool ok;
  final String text;
  const SaldoCheck(this.ok, this.text);
}

/// Wächter rund um den Bankabgleich (Einbau 01.09.2026, Wunsch Daniel).
///
/// Zwei Sorgen aus dem ersten Echtbetriebstag des camt-Abgleichs:
/// 1. **Lücken**: Ein Export mitten am Tag gezogen — erwischt der nächste
///    wirklich alles? Antwort der Bank selbst: OPBD/CLBD. Stimmt der
///    Anfangssaldo der neuen Datei mit dem Journal überein, ist die Kette
///    lückenlos — egal wann exportiert wurde.
/// 2. **Tilgung ohne Aufbau**: Zweimal am selben Tag zahlte eine Buchung ein
///    Verbindlichkeitskonto ins Soll (Franchise Januar: Kreditor 2000 ohne
///    Abgrenzung · Lohn August: 2002 ohne Lohnlauf). Ein Soll-Saldo auf einem
///    Verbindlichkeitskonto heisst praktisch immer: Die Gegenseite
///    (Lohnlauf, Eingangsrechnung, Abgrenzung) fehlt noch.
///
/// Reine Funktionen — Salden und Daten liefert der Aufrufer.
class BankWaechter {
  static final _datum = DateFormat('dd.MM.yyyy');
  static const _toleranz = 0.005;

  /// Verbindlichkeitskonten, deren Soll-Überhang eine Warnung auslöst.
  /// Konvention wie `getAllSaldi`: Passivkonten positiv im Haben —
  /// ein NEGATIVER Wert ist ein Soll-Überhang.
  static const kontenNamen = {
    2000: 'Kreditoren',
    2002: 'Lohnverbindlichkeit',
    2202: 'MWST-Abrechnungskonto',
    2270: 'SVA-Verbindlichkeit',
    2271: 'AXA-Verbindlichkeit',
    2272: 'Verbindlichkeit Sozialversicherungen',
    2273: 'Verbindlichkeit Quellensteuer',
  };

  static String _chf(double v) => v.toStringAsFixed(2);

  /// Anfangssaldo der neuen camt-Datei gegen den Journal-Saldo 1020 per
  /// Vortag. Stimmen beide, ist die Kette lückenlos.
  static SaldoCheck pruefeAnschluss({
    required double opbd,
    required double journalVortag,
  }) {
    final diff = opbd - journalVortag;
    if (diff.abs() < _toleranz) {
      return SaldoCheck(
          true, 'Anschluss lückenlos: Anfangssaldo ${_chf(opbd)} = Journal.');
    }
    return SaldoCheck(
        false,
        'Anfangssaldo ${_chf(opbd)} weicht vom Journal '
        '(${_chf(journalVortag)}) um ${_chf(diff.abs())} ab — '
        'es fehlen Transaktionen (Lücke zum letzten Import?).');
  }

  /// Schlusssaldo der camt-Datei gegen den Journal-Saldo 1020 per
  /// Zeitraum-Ende. Grün erst, wenn ALLE Transaktionen verbucht sind.
  static SaldoCheck pruefeSchluss({
    required double clbd,
    required double journal,
  }) {
    final diff = clbd - journal;
    if (diff.abs() < _toleranz) {
      return SaldoCheck(
          true, 'Bank stimmt: Schlusssaldo ${_chf(clbd)} = Journal.');
    }
    return SaldoCheck(
        false,
        'Journal (${_chf(journal)}) weicht vom Bank-Schlusssaldo '
        '(${_chf(clbd)}) um ${_chf(diff.abs())} ab — '
        'noch nicht alles verbucht oder Fehlbuchung.');
  }

  /// Warnt, wenn zwischen dem letzten importierten Zeitraum und der neuen
  /// Datei ganze Tage fehlen. Überlappung ist harmlos (Import ist über
  /// tx_keys idempotent); `null` = kein Befund.
  static String? luecke({
    required DateTime? letztesBis,
    required DateTime neuesVon,
  }) {
    if (letztesBis == null) return null;
    final ende = DateTime(letztesBis.year, letztesBis.month, letztesBis.day);
    final start = DateTime(neuesVon.year, neuesVon.month, neuesVon.day);
    final ersterFehlender = ende.add(const Duration(days: 1));
    if (!start.isAfter(ersterFehlender)) return null;
    final letzterFehlender = start.subtract(const Duration(days: 1));
    return 'Lücke: ${_datum.format(ersterFehlender)}–'
        '${_datum.format(letzterFehlender)} ist von keinem Export abgedeckt.';
  }

  /// Soll-Überhänge auf Verbindlichkeitskonten («Tilgung ohne Aufbau»).
  /// [saldi] in der Konvention von `getAllSaldi` (Passiv positiv im Haben).
  static List<String> verbindlichkeitsWarnungen(Map<int, double> saldi) {
    final warnungen = <String>[];
    for (final e in kontenNamen.entries) {
      final s = saldi[e.key] ?? 0;
      if (s < -_toleranz) {
        warnungen.add(
            'Konto ${e.key} (${e.value}) steht ${_chf(s.abs())} im Soll — '
            'Tilgung ohne Aufbau: Gegenstück (Lohnlauf/Eingangsrechnung/'
            'Abrechnung) fehlt.');
      }
    }
    return warnungen;
  }
}
