import 'package:sbs_projer_app/data/models/fehlersuche.dart';
import 'package:sbs_projer_app/data/fehlersuche/david_data.dart';
import 'package:sbs_projer_app/data/fehlersuche/konventionell_data.dart';
import 'package:sbs_projer_app/data/fehlersuche/orion_data.dart';
import 'package:sbs_projer_app/data/fehlersuche/heigenie_data.dart';

List<TsSystem> getAllSystems() => [
      davidSystem,
      konventionellSystem,
      orionSystem,
      heigenieSystem,
    ];

TsSystem? getSystemById(String id) {
  final systems = getAllSystems();
  try {
    return systems.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
}
