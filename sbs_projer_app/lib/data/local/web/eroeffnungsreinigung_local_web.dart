class EroeffnungsreinigungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String? betriebId;
  String stoerungsnummer = '';
  DateTime datum = DateTime.now();
  bool istBergkunde = false;
  double? preis;
  DateTime? abrechnungsMonat;
  bool abgerechnet = false;
  DateTime? createdAt;
  DateTime? updatedAt;
}
