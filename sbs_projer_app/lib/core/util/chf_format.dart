import 'package:intl/intl.dart';

final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

/// Schweizer Betragsformat: Tausender-Apostroph, 2 Dezimalstellen.
/// Beispiele: 1234.5 -> "1'234.50", -1234.55 -> "-1'234.55", 0 -> "0.00".
String chf(double v) => _fmt.format(v).replaceAll(',', "'");
