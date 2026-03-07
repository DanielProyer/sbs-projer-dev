import 'package:sbs_projer_app/data/local/region_local.dart';
import 'package:sbs_projer_app/data/models/region.dart';

class RegionMapper {
  static RegionLocal fromDto(Region dto, {RegionLocal? existing}) {
    final local = existing ?? RegionLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.name = dto.name;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(RegionLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'name': local.name,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
