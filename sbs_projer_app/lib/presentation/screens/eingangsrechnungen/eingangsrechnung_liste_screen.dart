import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Listen-Screen für Eingangsrechnungen (Kreditoren).
///
/// Platzhalter (TP-0) — wird in TP-1/TP-2 mit Upload, Erkennung und
/// nach Status gruppierter Liste gefüllt. Der Upload-/Erkennungs-Screen ist
/// über den FloatingActionButton erreichbar (TP-1).
class EingangsrechnungListeScreen extends ConsumerWidget {
  const EingangsrechnungListeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eingangsrechnungen')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Eingangsrechnungen werden hier erfasst und bestätigt.\n'
            'Tippe auf "Rechnung hochladen", um zu starten.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/buchhaltung/eingangsrechnungen/upload'),
        icon: const Icon(Icons.upload_file),
        label: const Text('Rechnung hochladen'),
      ),
    );
  }
}
