// Contact Picker API (navigator.contacts.select) — nur Chrome/Android.
// Zugriff über dart:js_interop (untypisiert via js_interop_unsafe, weil es
// keine Dart-Typen für die Picker-API gibt). Abbruch des Pickers wirft eine
// Exception — der Aufrufer fängt sie.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _navigator {
  final nav = globalContext.getProperty('navigator'.toJS);
  return nav.isUndefinedOrNull ? null : nav as JSObject;
}

bool get kontaktPickerVerfuegbar =>
    _navigator?.hasProperty('contacts'.toJS).toDart ?? false;

Future<({String? name, String? telefon, String? email})?>
    waehleHandyKontakt() async {
  final nav = _navigator;
  if (nav == null || !kontaktPickerVerfuegbar) return null;
  final contacts = nav.getProperty('contacts'.toJS) as JSObject;
  final props = ['name', 'tel', 'email'].map((e) => e.toJS).toList().toJS;
  final opts = JSObject()..setProperty('multiple'.toJS, false.toJS);
  final promise =
      contacts.callMethod('select'.toJS, props, opts) as JSPromise<JSArray>;
  final liste = (await promise.toDart).toDart;
  if (liste.isEmpty) return null;
  final k = liste.first as JSObject;

  String? erst(String feld) {
    final arr = k.getProperty(feld.toJS);
    if (arr.isUndefinedOrNull) return null;
    final l = (arr as JSArray).toDart;
    if (l.isEmpty) return null;
    return l.first?.dartify()?.toString();
  }

  return (name: erst('name'), telefon: erst('tel'), email: erst('email'));
}
