import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/IncidentService.dart';
import 'package:SarSys/services/UserService.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/matcher.dart';

void main() {
  /// TODO: Mock UserService
  final baseUrl = 'https://sporing.rodekors.no';
  final UserService userService = UserService('$baseUrl/auth/login');

  final IncidentService incidentService = IncidentServiceMock.build(userService, 2, "T123");

  IncidentBloc bloc;

  setUp(() => {bloc = IncidentBloc(incidentService)});

  tearDown(() => bloc.dispose());

  test('Incident bloc should be empty and unset', () async {
    expect(bloc.isEmpty, isTrue, reason: "Incident bloc should be empty");
    expect(bloc.isUnset, isTrue, reason: "Incident bloc should be unset");
    expect(bloc.initialState, TypeMatcher<IncidentUnset>(), reason: "Unexpected incident state");
    expect(
      bloc.state,
      emitsInOrder([emits(TypeMatcher<IncidentUnset>())]),
      reason: "First state is not IncidentUnset",
    );
    bloc.state.listen(expectAsync1(
      (state) {
        expect(true, isTrue);
      },
      reason: "Bloc contained more states than expected",
    ));
  });

  test('Incident bloc should contain two incidents', () async {
    List<Incident> incidents = await bloc.fetch();
    expect(incidents.length, 2, reason: "Bloc should return two incidents");
    expect(bloc.isEmpty, isFalse, reason: "Bloc should not be empty");
    expect(bloc.isUnset, isTrue, reason: "Bloc should be unset");
  });

  test('Incident bloc should be in selected state', () async {
    var count = 0;
    List<Incident> incidents = await bloc.fetch();
    bloc.select(incidents.first.id);
    bloc.state.listen(expectAsync1(
      (state) {
        count++;
      },
      count: 2,
      reason: "Bloc contained ${count + 1} states, expected 2",
    ));
    expect(
      bloc.state,
      emitsInOrder([
        emits(TypeMatcher<IncidentUnset>()),
        emits(TypeMatcher<IncidentSelected>()),
      ]),
      reason: "Bloc contained unexpected stream of events",
    );
  });

  test('First incident should be selected in last state', () async {
    List<Incident> incidents = await bloc.fetch();
    bloc.select(incidents.first.id);
    var last = await bloc.state.elementAt(1);
    expect(last.data, incidents.first, reason: "First incident was not selected");
    expect(bloc.current, last.data, reason: "Selected incident is different than last incident");
  });
}
