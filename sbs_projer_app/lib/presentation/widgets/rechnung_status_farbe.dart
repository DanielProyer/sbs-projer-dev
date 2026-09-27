import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';

/// Farbe eines Rechnungsstatus — die EINE Farbtabelle für Rechnungslisten
/// und -details (Kunden- wie Heineken-Rechnungen).
///
/// [schluessel] ist der Anzeige-Schlüssel aus [anzeigeSchluessel], NICHT der
/// rohe `zahlungsstatus`: Text und Farbe kommen so aus derselben Ableitung.
///
/// WARUM (Review 27.09.2026, K1): Vier Screens färbten je mit einer eigenen
/// Tabelle, und keine kannte `gesendet`, `uebergeben` oder `freigegeben` —
/// «Gesendet» stand grau neben orangem «Offen», obwohl beide unbezahlt sind,
/// und die Rechnungsliste färbte nach dem rohen Status, während der Text
/// schon die Mahnstufe aus `mahnung_stufe` zeigte.
/// - offen, gesendet, übergeben: unbezahlt, noch nicht gemahnt → orange;
/// - freigegeben (Heineken-Monatsrechnung, Ertrag gebucht) → blau;
/// - Mahnstufen von orange-rot bis dunkelrot, bezahlt grün, abgeschrieben grau.
Color rechnungStatusFarbe(String schluessel) => switch (schluessel) {
  Zahlungsstatus.offen ||
  Zahlungsstatus.gesendet ||
  kAnzeigeUebergeben => AppColors.warning,
  Zahlungsstatus.freigegeben => AppColors.info,
  Zahlungsstatus.bezahlt => AppColors.success,
  Zahlungsstatus.erinnert => const Color(0xFFE65100),
  Zahlungsstatus.mahnung1 => AppColors.error,
  Zahlungsstatus.mahnung2 => const Color(0xFF8B0000),
  Zahlungsstatus.abgeschrieben => AppColors.inaktiv,
  _ => AppColors.textSecondary,
};
