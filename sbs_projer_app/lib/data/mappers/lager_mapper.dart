import 'package:sbs_projer_app/data/local/lager_local.dart';
import 'package:sbs_projer_app/data/models/lager.dart';

class LagerMapper {
  static LagerLocal fromDto(Lager dto, {LagerLocal? existing}) {
    final local = existing ?? LagerLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.kategorieId = dto.kategorieId;
    local.materialId = dto.materialId;
    local.dboNr = dto.dboNr;
    local.name = dto.name;
    local.beschreibung = dto.beschreibung;
    local.einheit = dto.einheit;
    local.bestandAktuell = dto.bestandAktuell;
    local.bestandMindest = dto.bestandMindest;
    local.bestandOptimal = dto.bestandOptimal;
    // bestandNiedrig is GENERATED, not stored locally
    local.lieferant = dto.lieferant;
    local.lieferantenArtikelNr = dto.lieferantenArtikelNr;
    local.preisEinkauf = dto.preisEinkauf;
    local.istAktiv = dto.istAktiv;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(LagerLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'kategorie_id': local.kategorieId,
      'material_id': local.materialId,
      'dbo_nr': local.dboNr,
      'name': local.name,
      'beschreibung': local.beschreibung,
      'einheit': local.einheit,
      'bestand_aktuell': local.bestandAktuell,
      'bestand_mindest': local.bestandMindest,
      'bestand_optimal': local.bestandOptimal,
      // bestandNiedrig is GENERATED, not included
      'lieferant': local.lieferant,
      'lieferanten_artikel_nr': local.lieferantenArtikelNr,
      'preis_einkauf': local.preisEinkauf,
      'ist_aktiv': local.istAktiv,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
