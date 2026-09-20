import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';

final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

/// Schweizer Betragsformat: Tausender-Apostroph, 2 Dezimalstellen.
/// Beispiele: 1234.5 -> "1'234.50", -1234.55 -> "-1'234.55", 0 -> "0.00".
///
/// Erst auf Rappen runden, dann `+ 0.0`: beides zusammen hält die negative
/// Null vom Bildschirm fern. Sie entsteht laufend durch Vorzeichenumkehr
/// eines Saldos (`-(saldi[3400] ?? 0)`) und ebenso aus Restbeträgen unter
/// einem halben Rappen. `NumberFormat` schriebe in beiden Fällen «-0.00»;
/// in der MwSt-Abrechnung eines leeren Quartals stand das am 20.09.2026 in
/// jeder Zeile und sah nach einem Rechenfehler aus.
///
/// `-0.0 + 0.0` ist nach IEEE 754 genau `+0.0`; für jeden anderen Wert
/// ändert die Addition nichts. Die Rundung ist reine Anzeige — gerechnet
/// wird ohnehin überall auf Rappen.
String chf(double v) =>
    _fmt.format(rundeAufRappen(v) + 0.0).replaceAll(',', "'");
