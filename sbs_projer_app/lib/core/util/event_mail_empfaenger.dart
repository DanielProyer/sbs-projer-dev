/// Ein Empfänger-Vorschlag fürs Abschluss-Sheet (E5).
typedef EmpfaengerVorschlag = ({String name, String rolle, String? email});

/// Baut Vorschläge aus (name, rolle, email)-Tripeln: nur Rollen
/// 'event_heineken' (Eventverantwortlicher) und 'rsl'; Eventverantwortlicher
/// zuerst. Einträge ohne E-Mail bleiben gelistet (im Sheet ausgegraut).
List<EmpfaengerVorschlag> abschlussEmpfaenger(
    List<({String name, String rolle, String? email})> kontakte) {
  const reihenfolge = ['event_heineken', 'rsl'];
  final gefiltert = kontakte
      .where((k) => reihenfolge.contains(k.rolle))
      .map((k) => (name: k.name, rolle: k.rolle, email: k.email))
      .toList();
  gefiltert.sort((a, b) =>
      reihenfolge.indexOf(a.rolle).compareTo(reihenfolge.indexOf(b.rolle)));
  return gefiltert;
}

/// Mail-Betreff: „Abschlussbericht `Event` `Jahr`".
String abschlussBetreff(String eventName, int jahr) =>
    'Abschlussbericht $eventName $jahr';

/// PDF-Dateiname: bereinigt auf [A-Za-z0-9_-], Leerzeichen → '_'.
String abschlussDateiname(String eventName, int jahr) {
  final clean = eventName
      .replaceAll(' ', '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  return 'Abschlussbericht_${clean}_$jahr.pdf';
}
