import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnung_status.dart';

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
/// - nicht zugestellt, gesendet, übergeben: unbezahlt, noch nicht gemahnt →
///   orange;
/// - freigegeben (Heineken-Monatsrechnung, Ertrag gebucht) → blau;
/// - Mahnstufen von orange-rot bis dunkelrot, bezahlt grün, abgeschrieben grau.
Color rechnungStatusFarbe(String schluessel) => switch (schluessel) {
  RechnungAnzeige.nichtZugestellt ||
  RechnungAnzeige.gesendet ||
  RechnungAnzeige.uebergeben => AppColors.warning,
  RechnungAnzeige.freigegeben => AppColors.info,
  RechnungAnzeige.bezahlt => AppColors.success,
  RechnungAnzeige.erinnert => const Color(0xFFE65100),
  RechnungAnzeige.mahnung1 => AppColors.error,
  RechnungAnzeige.mahnung2 => const Color(0xFF8B0000),
  RechnungAnzeige.abgeschrieben => AppColors.inaktiv,
  _ => AppColors.textSecondary,
};

/// Symbol eines Rechnungsstatus — wie [rechnungStatusFarbe] aus dem
/// Anzeige-Schlüssel. Vorher führten Heineken-Liste und -Detail je eine
/// eigene Tabelle.
IconData rechnungStatusSymbol(String schluessel) => switch (schluessel) {
  RechnungAnzeige.nichtZugestellt => Icons.hourglass_empty,
  RechnungAnzeige.gesendet => Icons.send,
  RechnungAnzeige.uebergeben => Icons.handshake_outlined,
  RechnungAnzeige.freigegeben => Icons.task_alt,
  RechnungAnzeige.bezahlt => Icons.check_circle,
  RechnungAnzeige.erinnert => Icons.notifications,
  RechnungAnzeige.mahnung1 => Icons.warning,
  RechnungAnzeige.mahnung2 => Icons.gavel,
  RechnungAnzeige.abgeschrieben => Icons.block,
  _ => Icons.receipt,
};
