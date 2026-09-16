import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';

/// Umsatzbetrag einer Reinigung: bei Kulanz 0, sonst der Bruttopreis.
///
/// WARUM: Bis Migration 192 rechnete der Preis-Trigger auch bei Kulanz den
/// Listenpreis in die Zeile (Napoli Stories 31.07.2026: 94.05 ohne Rechnung
/// und ohne Buchung). Die Summen der Startseite zählten das mit. Die Regel
/// steht hier einmal — für Tages-, Monats- und Jahresumsatz und die
/// Einsätze-Liste.
double reinigungBetrag(ReinigungLocal r) =>
    r.istKulanz ? 0 : (r.preisBrutto ?? 0);
