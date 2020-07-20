import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SecurityModePersonalDescription extends StatelessWidget {
  const SecurityModePersonalDescription({
    Key key,
    this.untrusted = false,
  }) : super(key: key);

  final bool untrusted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: 'Personlig modus ${untrusted ? '(begrenset)' : ''}',
              style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "I personlig bruksmodus er det mulig å logge inn med private "
                  "Gmail-kontoer fra Google${untrusted ? ', slik du er nå' : ''}. ",
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "Siden identiteten til Google-brukere "
                  "ikke lar seg bekrefte på en sikker måte, "
                  "får ikke disse brukerne lov til dele data "
                  "med andre brukere. ",
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "For å sikre forsvarlig behandling av persondata "
                  "i tråd personvern-lovgivingen i Norge er denne "
                  "begrensningen lagt inn.",
            ),
          ),
        ),
      ],
    );
  }
}

class SecurityModeSharedDescription extends StatelessWidget {
  const SecurityModeSharedDescription({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: 'Delt modus',
              style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "I delt bruksmodus kan forskjellige brukere "
                  "dele samme enhet, for eksempel et nettbrett som "
                  "deles ut på en aksjon.",
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "Brukere og pinkoder slettes ikke ved utlogging. "
                  "Nye brukere kan enkelt legges til ved innlogging.",
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "For å sikre forsvarlig behandling av persondata "
                  "i tråd personvern-lovgivingen i Norge er kan ikke "
                  "private Gmail-kontoer benyttes i denne modusen.",
            ),
          ),
        ),
      ],
    );
  }
}

class UserRolesDescription extends StatelessWidget {
  const UserRolesDescription({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(text: "Roller tildeles av din organisasjon."),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text.rich(
              TextSpan(
                text: 'Tilgangskoder',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: "Aksjoner krever en kode for å kunne åpnes. "
                    "Denne koden sendes ut med varslingen eller oppgis på annet vis.",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                  text: "Aksjoner du selv har opprettet kan åpnes av deg uten kode. "
                      "Koden for hver aksjon finnes på ",
                  children: [
                    context.bloc<OperationBloc>().isSelected
                        ? TextSpan(text: 'aksjonens side.')
                        : TextSpan(
                            text: 'aksjonens side',
                            style: TextStyle(color: Colors.blue),
                            recognizer: new TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.popAndPushNamed(context, 'incident');
                              },
                            children: [TextSpan(text: '.', style: TextStyle(color: Colors.black))])
                  ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text.rich(
              TextSpan(
                text: '${translateUserRole(UserRole.commander)} (${translateUserRoleAbbr(UserRole.commander)})',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: "Alle som inngår i aksjonsledelse skal ha denne rollen.",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: "Du kan opprette aksjoner og gi andre tilgang ved å dele tilgangkoder.",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: "Du kan administrere aksjoner opprettet av andre ved å oppgi "
                    "tilgangskoden for aksjonleder.",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text.rich(
              TextSpan(
                text: '${translateUserRole(UserRole.unit_leader)} (${translateUserRoleAbbr(UserRole.unit_leader)})',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: "Du kan administrere laget du er tildelt. "
                    "For å delta på aksjoner må du oppgi tilgangskoden for mannskap.",
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: '${translateUserRole(UserRole.personnel)} (${translateUserRoleAbbr(UserRole.personnel)})',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(text: "Du kan delta på aksjoner med tilgangskoden for mannskap."),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(
                text: 'Ingen roller',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text.rich(
              TextSpan(text: "Du kan ikke delta på aksjoner."),
            ),
          ),
        ],
      ),
    );
  }
}

class ManagedProfileDescription extends StatelessWidget {
  const ManagedProfileDescription({
    Key key,
    this.affiliation,
  }) : super(key: key);

  final String affiliation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: 'Styrt profil',
              style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text.rich(
            TextSpan(
              text: "Tilhørighet og persondata er styrt av ${affiliation ?? 'din organisasjon'}.",
            ),
          ),
        ),
      ],
    );
  }
}
