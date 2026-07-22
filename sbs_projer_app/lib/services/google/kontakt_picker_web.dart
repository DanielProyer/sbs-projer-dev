// Contact Picker API (navigator.contacts.select) — nur Chrome/Android.
// Zugriff über js_util, weil dart:html keine Typen dafür hat. Abbruch des
// Pickers wirft eine Exception — der Aufrufer fängt sie.
import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool get kontaktPickerVerfuegbar =>
    js_util.hasProperty(html.window.navigator, 'contacts');

Future<({String? name, String? telefon, String? email})?>
    waehleHandyKontakt() async {
  if (!kontaktPickerVerfuegbar) return null;
  final contacts = js_util.getProperty<Object>(
    html.window.navigator,
    'contacts',
  );
  final liste = await js_util.promiseToFuture<List<Object?>>(
    js_util.callMethod(contacts, 'select', [
      js_util.jsify(['name', 'tel', 'email']),
      js_util.jsify({'multiple': false}),
    ]),
  );
  if (liste.isEmpty) return null;
  final k = liste.first;
  if (k == null) return null;

  String? erst(String feld) {
    final arr = js_util.getProperty<Object?>(k, feld);
    if (arr is List && arr.isNotEmpty) return arr.first?.toString();
    return null;
  }

  return (name: erst('name'), telefon: erst('tel'), email: erst('email'));
}
