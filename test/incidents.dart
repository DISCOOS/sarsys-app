import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/matcher.dart';

void main() {
  final UserService userService = UserServiceMock.build(
    enumName(UserRole.Commander),
    'test@local',
    'password',
  );
  final IncidentService incidentService = IncidentServiceMock.build(
    userService,
    2,
    enumName(UserRole.Commander),
    "T123",
  );

  UserBloc userBloc;
  IncidentBloc incidentBloc;

  setUp(() {
    userBloc = UserBloc(userService);
    incidentBloc = IncidentBloc(incidentService, userBloc);
  });

  tearDown(() => incidentBloc.dispose());

  test('Incident bloc should be empty and unset', () async {
    expect(incidentBloc.isEmpty, isTrue, reason: "Incident bloc should be empty");
    expect(incidentBloc.isUnset, isTrue, reason: "Incident bloc should be unset");
    expect(incidentBloc.initialState, TypeMatcher<IncidentUnset>(), reason: "Unexpected incident state");
    expect(
      incidentBloc.state,
      emitsInOrder([emits(TypeMatcher<IncidentUnset>())]),
      reason: "First state is not IncidentUnset",
    );
    incidentBloc.state.listen(expectAsync1(
      (state) {
        expect(true, isTrue);
      },
      reason: "Bloc contained more states than expected",
    ));
  });

  test('Incident bloc should contain two incidents', () async {
    List<Incident> incidents = await incidentBloc.fetch();
    expect(incidents.length, 2, reason: "Bloc should return two incidents");
    expect(incidentBloc.isEmpty, isFalse, reason: "Bloc should not be empty");
    expect(incidentBloc.isUnset, isTrue, reason: "Bloc should be unset");
  });

  test('Incident bloc should be in selected state', () async {
    var count = 0;
    List<Incident> incidents = await incidentBloc.fetch();
    incidentBloc.select(incidents.first.id);
    incidentBloc.state.listen(expectAsync1(
      (state) {
        count++;
      },
      count: 2,
      reason: "Bloc contained ${count + 1} states, expected 2",
    ));
    expect(
      incidentBloc.state,
      emitsInOrder([
        emits(TypeMatcher<IncidentUnset>()),
        emits(TypeMatcher<IncidentSelected>()),
      ]),
      reason: "Bloc contained unexpected stream of events",
    );
  });

  test('First incident should be selected in last state', () async {
    List<Incident> incidents = await incidentBloc.fetch();
    incidentBloc.select(incidents.first.id);
    var last = await incidentBloc.state.elementAt(1);
    expect(last.data, incidents.first, reason: "First incident was not selected");
    expect(incidentBloc.current, last.data, reason: "Selected incident is different than last incident");
  });
}
