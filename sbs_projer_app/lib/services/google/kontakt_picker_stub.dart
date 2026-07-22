/// Native/Test-Stub: Die Contact Picker API gibt es nur im Web
/// (Chrome/Android) — hier immer nicht verfügbar.
bool get kontaktPickerVerfuegbar => false;

Future<({String? name, String? telefon, String? email})?>
    waehleHandyKontakt() async => null;
