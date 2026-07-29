import 'package:flutter/material.dart';

/// Einheitliche Zeitauswahl der App: immer 24-Stunden-Format, ohne AM/PM
/// (Regel Daniel 29.07.2026 — «wie die Servicezeit am Betrieb, überall»).
///
/// Ohne den MediaQuery-Eingriff richtet sich der TimePicker nach dem
/// Gebietsschema des Geräts und zeigt je nach Einstellung AM/PM.
Future<TimeOfDay?> zeigeZeitauswahl(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
