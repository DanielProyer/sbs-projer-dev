import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneContactService {
  static final Map<String, Group> _groupCache = {};

  static String groupName(String kategorie) => switch (kategorie) {
    'betrieb' => 'SBS Kunden',
    'heineken' => 'SBS Heineken',
    'event' => 'SBS Event',
    _ => 'SBS Kunden',
  };

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

  /// Kontakt-Gruppe suchen oder erstellen (mit Cache)
  static Future<Group?> _getOrCreateGroup(String name) async {
    if (_groupCache.containsKey(name)) return _groupCache[name];
    try {
      final groups = await FlutterContacts.getGroups();
      for (final g in groups) {
        if (g.name == name) {
          _groupCache[name] = g;
          return g;
        }
      }
      final created = await FlutterContacts.insertGroup(Group('', name));
      _groupCache[name] = created;
      return created;
    } catch (_) {
      return null;
    }
  }

  /// Alle 3 Gruppen vorab erstellen (vor Bulk-Sync aufrufen)
  static Future<void> prepareGroups() async {
    if (kIsWeb) return;
    final hasPermission = await requestPermission();
    if (!hasPermission) return;
    for (final name in ['SBS Kunden', 'SBS Heineken', 'SBS Event']) {
      await _getOrCreateGroup(name);
    }
  }

  /// App-Kontakt auf Handy speichern/aktualisieren (alle Kategorien)
  static Future<String?> syncToPhone({
    required String vorname,
    String? nachname,
    String? telefon,
    String? email,
    String kategorie = 'betrieb',
    String? betriebName,
    String? existingPhoneContactId,
  }) async {
    if (kIsWeb) return null;

    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      final group = await _getOrCreateGroup(groupName(kategorie));
      final groups = group != null ? [group] : <Group>[];

      final company = switch (kategorie) {
        'betrieb' => betriebName ?? '',
        'heineken' => 'Heineken Schweiz',
        'event' => 'Event',
        _ => '',
      };

      if (existingPhoneContactId != null) {
        final existing = await FlutterContacts.getContact(
          existingPhoneContactId,
          withProperties: true,
          withGroups: true,
        );
        if (existing != null) {
          existing.name = Name(first: vorname, last: nachname ?? '');
          if (company.isNotEmpty) {
            existing.organizations = [Organization(company: company)];
          }
          existing.phones = telefon != null && telefon.isNotEmpty
              ? [Phone(telefon)]
              : [];
          existing.emails = email != null && email.isNotEmpty
              ? [Email(email)]
              : [];
          existing.groups = groups;
          await existing.update();
          return existing.id;
        }
      }

      final newContact = Contact(
        name: Name(first: vorname, last: nachname ?? ''),
        organizations:
            company.isNotEmpty ? [Organization(company: company)] : [],
        phones: telefon != null && telefon.isNotEmpty ? [Phone(telefon)] : [],
        emails: email != null && email.isNotEmpty ? [Email(email)] : [],
        groups: groups,
      );
      final inserted = await newContact.insert();
      return inserted.id;
    } catch (_) {
      return null;
    }
  }

  /// Backward-compatible wrapper
  static Future<String?> saveToPhone({
    required String vorname,
    String? nachname,
    String? telefon,
    required String betriebName,
    String? existingPhoneContactId,
  }) =>
      syncToPhone(
        vorname: vorname,
        nachname: nachname,
        telefon: telefon,
        kategorie: 'betrieb',
        betriebName: betriebName,
        existingPhoneContactId: existingPhoneContactId,
      );

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
    } catch (_) {}
  }
}
