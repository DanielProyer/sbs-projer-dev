/// Übersetzt Fehler der Google-Edge-Functions in Sätze, mit denen man etwas
/// anfangen kann.
///
/// Die Rohmeldungen kommen von Google und sind für den Anwender unbrauchbar
/// («People API has not been used in project 1040401919292 before or it is
/// disabled…»). Wichtiger als der Wortlaut ist, was zu tun ist.

/// Was hinter dem Fehler steckt — bestimmt, ob und wie gemeldet wird.
enum GoogleFehlerArt {
  /// Die API ist im Google-Cloud-Projekt nicht freigeschaltet.
  apiNichtAktiviert,

  /// Angemeldet, aber ohne die nötige Freigabe (Scope fehlt).
  keineBerechtigung,

  /// Token abgelaufen oder zurückgezogen.
  verbindungAbgelaufen,

  /// Gar kein Google-Konto verbunden — kein Fehler, nur nichts zu tun.
  nichtVerbunden,

  /// Alles andere; der Originaltext wird durchgereicht.
  unbekannt,
}

class GoogleFehler {
  final GoogleFehlerArt art;

  /// Was dem Anwender angezeigt wird.
  final String text;

  /// Seite, die das Problem behebt — sofern Google eine mitgeliefert hat.
  final String? link;

  const GoogleFehler(this.art, this.text, {this.link});

  /// Lohnt es, den Anwender damit zu behelligen? Ein fehlendes Google-Konto
  /// ist kein Fehler, sondern eine bewusste Einstellung.
  bool get istMeldenswert => art != GoogleFehlerArt.nichtVerbunden;
}

/// Erste http(s)-Adresse aus dem Text — Google hängt die Freischaltseite an.
String? _linkAus(String s) =>
    RegExp(r'https?://[^\s,}\)]+').firstMatch(s)?.group(0);

/// Fehler einordnen und in einen brauchbaren Satz übersetzen.
GoogleFehler googleFehler(Object fehler) {
  final roh = fehler.toString();
  final k = roh.toLowerCase();

  if (k.contains('has not been used in project') ||
      k.contains('it is disabled') ||
      (k.contains('accessnotconfigured'))) {
    final dienst = k.contains('people')
        ? 'Google Kontakte'
        : k.contains('calendar')
            ? 'Google Kalender'
            : 'Der Google-Dienst';
    return GoogleFehler(
      GoogleFehlerArt.apiNichtAktiviert,
      '$dienst ist für dein Google-Projekt nicht freigeschaltet. '
          'In der Google Cloud Console aktivieren, ein paar Minuten warten, '
          'dann erneut versuchen.',
      link: _linkAus(roh),
    );
  }

  if (k.contains('insufficient') ||
      k.contains('missing_scope') ||
      k.contains('scope')) {
    return const GoogleFehler(
      GoogleFehlerArt.keineBerechtigung,
      'Der App fehlt die Freigabe für Google Kontakte. Verbindung in den '
          'Einstellungen trennen und neu verbinden — dabei den Zugriff auf '
          'Kontakte bestätigen.',
    );
  }

  if (k.contains('invalid_grant') ||
      k.contains('token expired') ||
      k.contains('unauthorized') ||
      k.contains('401')) {
    return const GoogleFehler(
      GoogleFehlerArt.verbindungAbgelaufen,
      'Die Google-Verbindung ist abgelaufen. Bitte in den Einstellungen neu '
          'verbinden.',
    );
  }

  if (k.contains('not_connected') ||
      k.contains('no_token') ||
      k.contains('skipped')) {
    return const GoogleFehler(
      GoogleFehlerArt.nichtVerbunden,
      'Kein Google-Konto verbunden — der Kontakte-Sync ist inaktiv.',
    );
  }

  return GoogleFehler(GoogleFehlerArt.unbekannt, roh);
}
