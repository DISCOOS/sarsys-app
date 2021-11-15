

import 'package:uuid/uuid.dart';

import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/affiliation/domain/entities/OperationalFunction.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroupCatalog.dart';

import 'domain/entities/Affiliation.dart';
import 'domain/entities/FleetMap.dart';
import 'domain/entities/TalkGroup.dart';

class AffiliationUtils {
  /// Create [Affiliation] reference
  static AggregateRef<Affiliation> newRef({String? auuid}) => AggregateRef.fromType<Affiliation>(
        auuid ?? Uuid().v4(),
      );

  /// Ensure tracking reference
  static AggregateRef<Affiliation>? ensureRef<T extends Affiliate>(T affiliate, {String? auuid}) =>
      affiliate.affiliation.uuid == null
          // Create new ref
          ? newRef(auuid: auuid)
          // Use old ref
          : affiliate.affiliation as AggregateRef<Affiliation>?;

  /// Asserts if [Affiliation] reference is valid.
  ///
  /// [Affiliate]s should contain a [Affiliation]
  /// reference when  they are created.
  static String assertRef<T extends Affiliate?>(T affiliate) {
    final auuid = affiliate!.affiliation.uuid;
    if (auuid == null) {
      throw ArgumentError(
        "${typeOf<T>()} is not configured correctly: AggregateRef is null",
      );
    }
    return auuid;
  }

  /// Get [FleetMap.prefix] from [FleetMap] number
  static String? toPrefix(String? number) => emptyAsNull(
        number?.isEmpty == false && number!.length >= 3 ? number.substring(0, 2) : null,
      );

  /// Get [FleetMapNumber.suffix] from [FleetMap] number
  static String? toSuffix(String? number) => emptyAsNull(
        number?.isEmpty == false && number!.length >= 5 ? number.substring(2, 5) : null,
      );

  static OperationalFunction? findFunction(FleetMap map, String? number) =>
      map.functions!.where((test) => number != null && RegExp(test.pattern!).hasMatch(number)).firstOrNull;

  static TalkGroupCatalog? findCatalog(FleetMap map, String? name) =>
      map.catalogs!.where((test) => test.name == name).firstOrNull;

  static List<TalkGroup> findTalkGroups(TalkGroupCatalog? catalog, String query) {
    final match = query.toLowerCase();
    return catalog?.groups
            .where((tg) => tg.name!.toLowerCase().contains(match) || tg.type.toString().toLowerCase().contains(match))
            .take(5)
            .toList(growable: false) ??
        [];
  }
}
