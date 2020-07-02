import 'package:SarSys/features/affiliation/domain/entities/OperationalFunction.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroupCatalog.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/extensions.dart';

import 'domain/entities/FleetMap.dart';
import 'domain/entities/TalkGroup.dart';

class AffiliationUtils {
  /// Get [FleetMap.prefix] from [FleetMap] number
  static String toPrefix(String number) => emptyAsNull(
        number?.isEmpty == false && number.length >= 3 ? number?.substring(0, 2) : null,
      );

  /// Get [FleetMapNumber.suffix] from [FleetMap] number
  static String toSuffix(String number) => emptyAsNull(
        number?.isEmpty == false && number.length >= 5 ? number?.substring(2, 5) : null,
      );

  static OperationalFunction findFunction(FleetMap map, String number) =>
      map.functions.where((test) => number != null && RegExp(test.pattern).hasMatch(number)).firstOrNull;

  static TalkGroupCatalog findCatalog(FleetMap map, String name) =>
      map.catalogs.where((test) => test.name == name).firstOrNull;

  static List<TalkGroup> findTalkGroups(TalkGroupCatalog catalog, String query) {
    final match = query.toLowerCase();
    return catalog?.groups
            ?.where((tg) => tg.name.toLowerCase().contains(match) || tg.type.toString().toLowerCase().contains(match))
            ?.take(5)
            ?.toList(growable: false) ??
        [];
  }
}
