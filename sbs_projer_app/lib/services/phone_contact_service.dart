import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneContactService {
  /// Berechtigung prüfen/anfordern
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    return await FlutterContacts.requestPermission();
  }

  /// Kontakt aus Handykontakten importieren (Picker öffnen)
  static Future<Map<String, String>?> pickContact() async {
    if (kIsWeb) return null;

    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return null;

    // Vollständigen Kontakt laden (Picker gibt nur Basis-Daten)
    final full = await FlutterContacts.getContact(contact.id,
        withProperties: true);
    if (full == null) return null;

    final result = <String, String>{
      'phoneContactId': full.id,
    };

    if (full.name.first.isNotEmpty) result['vorname'] = full.name.first;
    if (full.name.last.isNotEmpty) result['nachname'] = full.name.last;
    if (full.phones.isNotEmpty) result['telefon'] = full.phones.first.number;

    return result;
  }

  /// App-Kontakt auf Handy speichern/aktualisieren
  static Future<String?> saveToPhone({
    required String vorname,
    String? nachname,
    String? telefon,
    required String betriebName,
    String? existingPhoneContactId,
  }) async {
    if (kIsWeb) return null;

    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      // Bestehenden Kontakt aktualisieren
      if (existingPhoneContactId != null) {
        final existing = await FlutterContacts.getContact(
          existingPhoneContactId,
          withProperties: true,
        );
        if (existing != null) {
          existing.name = Name(first: vorname, last: nachname ?? '');
          existing.organizations = [Organization(company: betriebName)];
          existing.phones = telefon != null && telefon.isNotEmpty
              ? [Phone(telefon)]
              : [];
          await existing.update();
          return existing.id;
        }
      }

      // Neuen Kontakt erstellen
      final newContact = Contact(
        name: Name(first: vorname, last: nachname ?? ''),
        organizations: [Organization(company: betriebName)],
        phones: telefon != null && telefon.isNotEmpty ? [Phone(telefon)] : [],
      );
      final inserted = await newContact.insert();
      return inserted.id;
    } catch (_) {
      return null;
    }
  }

  /// Handykontakt löschen
  static Future<void> deleteFromPhone(String phoneContactId) async {
    if (kIsWeb) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    try {
      final contact = await FlutterContacts.getContact(phoneContactId);
      if (contact != null) {
        await contact.delete();
      }
    } catch (_) {
      // Ignorieren wenn Kontakt nicht mehr existiert
    }
  }
}
