/// Zapfsysteme, die einen Betrieb zu einem SBS-Kunden machen (werden von uns
/// serviciert & verrechnet).
const _kundenZapfsysteme = {'Konventionell', 'Orion'};

/// Vorschlag für den "mein Kunde"-Flag aus Status + Zapfsystemen.
///
/// - Status `inaktiv`/`geschlossen` -> immer false (kein Kunde mehr / weg).
/// - sonst (aktiv/saisonpause) -> true, wenn ein Kunden-Zapfsystem vorhanden ist.
///
/// Der zurückgegebene Wert ist nur ein Vorschlag; im Formular kann er manuell
/// übersteuert werden.
bool istMeinKundeVorschlag(String status, List<String> zapfsysteme) {
  if (status == 'inaktiv' || status == 'geschlossen') return false;
  return zapfsysteme.any(_kundenZapfsysteme.contains);
}
