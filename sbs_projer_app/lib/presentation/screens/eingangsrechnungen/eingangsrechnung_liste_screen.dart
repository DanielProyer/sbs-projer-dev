import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Listen-Screen für Eingangsrechnungen (Kreditoren).
///
/// Platzhalter (TP-0) — wird in TP-1/TP-2 mit Upload, Erkennung und
/// nach Status gruppierter Liste gefüllt.
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
            'Upload & KI-Erkennung folgen in Kürze.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
