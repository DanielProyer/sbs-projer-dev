import 'package:flutter/material.dart';

/// Platzhalter-Stub — wird in Task 9 (E1) durch den echten Detail-Screen ersetzt.
class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: const Center(
        child: Text('Event-Detail folgt.'),
      ),
    );
  }
}
