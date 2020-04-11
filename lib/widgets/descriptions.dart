import 'package:flutter/material.dart';

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
