/// Baut eine Google-Maps-Navigations-URL zum Ziel.
/// Koordinaten haben Vorrang; sonst wird die (URL-kodierte) [adresse] genutzt.
/// Gibt `null` zurück, wenn weder vollständige Koordinaten noch Adresse da sind.
String? googleMapsRouteUrl({
  required double? latitude,
  required double? longitude,
  required String adresse,
}) {
  const base = 'https://www.google.com/maps/dir/?api=1&destination=';
  if (latitude != null && longitude != null) {
    final dest = Uri.encodeComponent('$latitude,$longitude');
    return '$base$dest';
  }
  final adr = adresse.trim();
  if (adr.isEmpty) return null;
  return '$base${Uri.encodeQueryComponent(adr)}';
}
