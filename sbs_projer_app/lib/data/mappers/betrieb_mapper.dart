import 'dart:convert';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';

class BetriebMapper {
  static BetriebLocal fromDto(Betrieb dto, {BetriebLocal? existing}) {
    final local = existing ?? BetriebLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.name = dto.name;
    local.strasse = dto.strasse;
    local.nr = dto.nr;
    local.plz = dto.plz;
    local.ort = dto.ort;
    local.telefon = dto.telefon;
    local.regionId = dto.regionId;
    local.email = dto.email;
    local.website = dto.website;
    local.zugangNotizen = dto.zugangNotizen;
    local.betriebNr = dto.betriebNr;
    local.weNummer = dto.weNummer;
    local.agNummer = dto.agNummer;
    local.status = dto.status;
    local.istMeinKunde = dto.istMeinKunde;
    local.istBergkunde = dto.istBergkunde;
    local.istSaisonbetrieb = dto.istSaisonbetrieb;
    local.winterSaisonAktiv = dto.winterSaisonAktiv;
    local.winterStartDatum = dto.winterStartDatum;
    local.winterEndeDatum = dto.winterEndeDatum;
    local.sommerSaisonAktiv = dto.sommerSaisonAktiv;
    local.sommerStartDatum = dto.sommerStartDatum;
    local.sommerEndeDatum = dto.sommerEndeDatum;
    local.ruhetage = dto.ruhetage;
    local.zapfsysteme = dto.zapfsysteme;
    local.zahlerAliase = dto.zahlerAliase;
    local.rechnungsstellung = dto.rechnungsstellung;
    local.schliessungsgrund = dto.schliessungsgrund;
    local.schliessungsdatum = dto.schliessungsdatum;
    local.latitude = dto.latitude;
    local.longitude = dto.longitude;
    local.ferienStart = dto.ferienStart;
    local.ferienEnde = dto.ferienEnde;
    local.ferien2Start = dto.ferien2Start;
    local.ferien2Ende = dto.ferien2Ende;
    local.ferien3Start = dto.ferien3Start;
    local.ferien3Ende = dto.ferien3Ende;
    local.ferien4Start = dto.ferien4Start;
    local.ferien4Ende = dto.ferien4Ende;
    local.ferien5Start = dto.ferien5Start;
    local.ferien5Ende = dto.ferien5Ende;
    local.keineBetriebsferien = dto.keineBetriebsferien;
    local.oeffnungszeitenJson = dto.oeffnungszeiten != null
        ? jsonEncode(dto.oeffnungszeiten)
        : null;
    local.servicezeitMorgenAb = dto.servicezeitMorgenAb;
    local.servicezeitMorgenBis = dto.servicezeitMorgenBis;
    local.servicezeitNachmittagAb = dto.servicezeitNachmittagAb;
    local.servicezeitNachmittagBis = dto.servicezeitNachmittagBis;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BetriebLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'name': local.name,
      'strasse': local.strasse,
      'nr': local.nr,
      'plz': local.plz,
      'ort': local.ort,
      'telefon': local.telefon,
      'region_id': local.regionId,
      'email': local.email,
      'website': local.website,
      'zugang_notizen': local.zugangNotizen,
      'heineken_nr': local.betriebNr,
      'we_nummer': local.weNummer,
      'ag_nummer': local.agNummer,
      'status': local.status,
      'ist_mein_kunde': local.istMeinKunde,
      'ist_bergkunde': local.istBergkunde,
      'ist_saisonbetrieb': local.istSaisonbetrieb,
      'winter_saison_aktiv': local.winterSaisonAktiv,
      'winter_start_datum': local.winterStartDatum?.toIso8601String().split('T').first,
      'winter_ende_datum': local.winterEndeDatum?.toIso8601String().split('T').first,
      'sommer_saison_aktiv': local.sommerSaisonAktiv,
      'sommer_start_datum': local.sommerStartDatum?.toIso8601String().split('T').first,
      'sommer_ende_datum': local.sommerEndeDatum?.toIso8601String().split('T').first,
      'ruhetage': local.ruhetage,
      'zapfsysteme': local.zapfsysteme,
      'zahler_aliase': local.zahlerAliase,
      'rechnungsstellung': local.rechnungsstellung,
      'schliessungsgrund': local.schliessungsgrund,
      'schliessungsdatum':
          local.schliessungsdatum?.toIso8601String().split('T').first,
      'latitude': local.latitude,
      'longitude': local.longitude,
      'ferien_start': local.ferienStart?.toIso8601String().split('T').first,
      'ferien_ende': local.ferienEnde?.toIso8601String().split('T').first,
      'ferien2_start': local.ferien2Start?.toIso8601String().split('T').first,
      'ferien2_ende': local.ferien2Ende?.toIso8601String().split('T').first,
      'ferien3_start': local.ferien3Start?.toIso8601String().split('T').first,
      'ferien3_ende': local.ferien3Ende?.toIso8601String().split('T').first,
      'ferien4_start': local.ferien4Start?.toIso8601String().split('T').first,
      'ferien4_ende': local.ferien4Ende?.toIso8601String().split('T').first,
      'ferien5_start': local.ferien5Start?.toIso8601String().split('T').first,
      'ferien5_ende': local.ferien5Ende?.toIso8601String().split('T').first,
      'keine_betriebsferien': local.keineBetriebsferien,
      'oeffnungszeiten': local.oeffnungszeitenJson != null
          ? jsonDecode(local.oeffnungszeitenJson!)
          : {},
      'servicezeit_morgen_ab': local.servicezeitMorgenAb,
      'servicezeit_morgen_bis': local.servicezeitMorgenBis,
      'servicezeit_nachmittag_ab': local.servicezeitNachmittagAb,
      'servicezeit_nachmittag_bis': local.servicezeitNachmittagBis,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
