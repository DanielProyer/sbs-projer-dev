class BierleitungLocal {
  int id = 0;

  String get routeId => serverId!;

  // Supabase Sync
  String? serverId;
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  String anlageId = '';
  int leitungsNummer = 0;
  String? biersorte;
  String? hahnTyp;
  double? niederdruckBar;
  bool hatFobStop = false;
  bool istGekoppelt = false;
}
