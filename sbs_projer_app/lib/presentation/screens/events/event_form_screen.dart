import 'package:flutter/material.dart';

/// Platzhalter-Stub — wird in Task 8 (E1) durch das echte Formular ersetzt.
class EventFormScreen extends StatelessWidget {
  final String? eventId;

  const EventFormScreen({super.key, this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(eventId == null ? 'Neues Event' : 'Event bearbeiten'),
      ),
      body: const Center(
        child: Text('Event-Formular folgt.'),
      ),
    );
  }
}
