import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class AffiliationCommand<S, T> extends BlocCommand<S, T> {
  AffiliationCommand(
    S data, {
    props = const [],
  }) : super(data, props);
}

class LoadAffiliations extends AffiliationCommand<void, List<Affiliation>> {
  LoadAffiliations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}

class FetchAffiliations extends AffiliationCommand<List<String>, List<Affiliation>> {
  FetchAffiliations({List<String> uuids = const []}) : super(uuids);

  @override
  String toString() => '$runtimeType {uuids: $data}';
}

class SearchAffiliations extends AffiliationCommand<String, List<Affiliation>> {
  SearchAffiliations(
    String filter, {
    this.offset = 0,
    this.limit = 20,
  }) : super(filter);

  final int limit;
  final int offset;

  @override
  String toString() => '$runtimeType {filter: $data, limit: $limit, offset: $offset}';
}

class OnboardUser extends AffiliationCommand<String?, Affiliation> {
  OnboardUser(String? userId, this.affiliation) : super(userId, props: [affiliation]);
  final Affiliation affiliation;

  @override
  String toString() => '$runtimeType {userId: $data, affiliation: $affiliation}';
}

class CreateAffiliation extends AffiliationCommand<Affiliation, Affiliation> {
  CreateAffiliation(Affiliation affiliation) : super(affiliation);

  Person get person => data.person!;

  @override
  String toString() => '$runtimeType {affiliation: $data}';
}

class UpdateAffiliation extends AffiliationCommand<Affiliation, Affiliation> {
  UpdateAffiliation(Affiliation affiliation) : super(affiliation);

  @override
  String toString() => '$runtimeType {affiliation: $data}';
}

class UnloadAffiliations extends AffiliationCommand<void, List<Affiliation>> {
  UnloadAffiliations() : super(null);

  @override
  String toString() => '$runtimeType {}';
}
