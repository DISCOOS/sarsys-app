import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/matcher.dart';

void main() {
  final IncidentService service = IncidentServiceMock.build(2);

  IncidentBloc bloc;

  setUp(() => {bloc = IncidentBloc(service)});

  test('Incident bloc should be empty and unset', () async {
    expect(bloc.isEmpty, true, reason: "Incident bloc should be empty");
    expect(bloc.isUnset, true, reason: "Incident bloc should be unset");
    expect(bloc.initialState, TypeMatcher<IncidentUnset>(), reason: "Unexpected incident state");
  });

  test('Incident bloc should contain two incidents', () async {
    List<Incident> incidents = await bloc.fetch();
    expect(incidents.length, 2, reason: "Bloc should return two incidents");
    expect(bloc.isEmpty, false, reason: "Bloc should not be empty");
    expect(bloc.isUnset, true, reason: "Bloc should be unset");
  });
}
