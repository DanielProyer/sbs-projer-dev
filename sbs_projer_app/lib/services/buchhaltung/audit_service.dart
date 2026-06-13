import 'bilanz_service.dart' show KontoInfo;

/// Ein auffälliger Posten aus der Buchhaltung.
class AuditBefund {
  final String kategorie;
  final int konto;
  final String bezeichnung;
  final double saldo;
  final String hinweis;
  const AuditBefund(this.kategorie, this.konto, this.bezeichnung, this.saldo, this.hinweis);
}

/// Findet verdächtige Salden (reine Regeln; Eingabe = Anzeige-Saldi wie getAllSaldi).
class AuditService {
  static const _eps = 0.05;

  static List<AuditBefund> befunde(Map<int, double> saldi, List<KontoInfo> konten) {
    final byNr = {for (final k in konten) k.kontonummer: k};
    String bez(int nr) => byNr[nr]?.bezeichnung ?? '—';
    final out = <AuditBefund>[];

    saldi.forEach((konto, saldo) {
      final name = byNr[konto]?.bezeichnung ?? '';
      final klasse = konto ~/ 1000;

      if (name.toUpperCase().contains('FEHLER') && saldo.abs() > _eps) {
        out.add(AuditBefund('Fehler-Konto', konto, bez(konto), saldo,
            'Falsches Konto — umbuchen'));
      }
      if (saldo < -_eps && (klasse == 1 || konto == 2200 || konto == 8900)) {
        out.add(AuditBefund('Negativer Saldo', konto, bez(konto), saldo,
            'Negativer Saldo prüfen'));
      }
      if ((klasse == 9 || konto == 2980) && saldo.abs() > _eps) {
        out.add(AuditBefund('Abschluss-Rest', konto, bez(konto), saldo,
            'Abschlussbuchung unvollständig'));
      }
      if (konto == 1100 && saldo > _eps) {
        out.add(AuditBefund('Debitoren', konto, bez(konto), saldo,
            'Offene Forderungen prüfen/abschreiben (Phase 2c)'));
      }
    });

    out.sort((a, b) => a.kategorie.compareTo(b.kategorie) == 0
        ? a.konto.compareTo(b.konto)
        : a.kategorie.compareTo(b.kategorie));
    return out;
  }
}
