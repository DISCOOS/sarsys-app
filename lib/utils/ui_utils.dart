import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong/latlong.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'defaults.dart';

typedef PromptCallback = Future<bool> Function(String title, String message);
typedef MessageCallback = void Function(String message, {String action, VoidCallback onPressed});

const FIT_BOUNDS_OPTIONS = const FitBoundsOptions(
  zoom: Defaults.zoom,
  maxZoom: Defaults.zoom,
  padding: EdgeInsets.all(48.0),
);

Future<bool> prompt(BuildContext context, String title, String message) async {
  // flutter defined function
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          FlatButton(
            child: Text("AVBRYT"),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          FlatButton(
            child: Text("FORTSETT"),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}

Widget buildDropDownField<T>({
  @required String attribute,
  @required String label,
  @required T initialValue,
  @required List<DropdownMenuItem<T>> items,
  @required List<FormFieldValidator> validators,
  ValueChanged<T> onChanged,
}) =>
    FormBuilderCustomField(
      attribute: attribute,
      formField: FormField<T>(
        enabled: true,
        initialValue: initialValue,
        builder: (FormFieldState<T> field) => buildDropdown<T>(
          field: field,
          label: label,
          items: items,
          onChanged: onChanged,
        ),
      ),
      validators: validators,
    );

Widget buildDropdown<T>({
  @required FormFieldState<T> field,
  @required String label,
  @required List<DropdownMenuItem<T>> items,
  ValueChanged<T> onChanged,
}) =>
    InputDecorator(
      decoration: InputDecoration(
        hasFloatingPlaceholder: true,
        errorText: field.hasError ? field.errorText : null,
        filled: true,
        labelText: label,
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: false,
          child: DropdownButton<T>(
            value: field.value,
            isDense: true,
            onChanged: (T newValue) {
              field.didChange(newValue);
              if (onChanged != null) onChanged(newValue);
            },
            items: items,
          ),
        ),
      ),
    );

Color toTrackingStatusColor(BuildContext context, TrackingStatus status) {
  switch (status) {
    case TrackingStatus.None:
      return Colors.grey;
    case TrackingStatus.Created:
      return Theme.of(context).colorScheme.primary;
    case TrackingStatus.Tracking:
      return Colors.green;
    case TrackingStatus.Paused:
      return Colors.orange;
    case TrackingStatus.Closed:
      return Colors.red;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

IconData toTrackingIconData(BuildContext context, TrackingStatus status) {
  switch (status) {
    case TrackingStatus.Created:
    case TrackingStatus.Paused:
    case TrackingStatus.Closed:
      return Icons.play_arrow;
    case TrackingStatus.Tracking:
    default:
      return Icons.pause;
  }
}

Color toPointStatusColor(BuildContext context, Point point) {
  final since = (point == null ? null : DateTime.now().difference(point.timestamp).inMinutes);
  return since == null || since > 5 ? Colors.red : (since > 1 ? Colors.orange : Colors.green);
}

void jumpToPoint(BuildContext context, {Point center, Incident incident}) {
  jumpToLatLng(context, center: toLatLng(center), incident: incident);
}

void jumpToLatLng(BuildContext context, {LatLng center, Incident incident}) {
  if (center != null) {
    Navigator.pushNamed(context, "map", arguments: {"center": center, "incident": incident});
  }
}

void jumpToLatLngBounds(
  BuildContext context, {
  Incident incident,
  LatLngBounds fitBounds,
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  if (fitBounds != null && fitBounds.isValid) {
    Navigator.pushNamed(context, "map", arguments: {
      "incident": incident,
      "fitBounds": fitBounds,
      "fitBoundOptions": fitBoundOptions,
    });
  }
}

void jumpToIncident(
  BuildContext context,
  Incident incident, {
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  final ipp = incident.ipp != null ? toLatLng(incident.ipp) : null;
  final meetup = incident.meetup != null ? toLatLng(incident.meetup) : null;
  final fitBounds = LatLngBounds(ipp, meetup);
  if (ipp == null || meetup == null || fitBounds.isValid == false)
    jumpToLatLng(context, center: meetup ?? ipp, incident: incident);
  else
    jumpToLatLngBounds(context, fitBounds: fitBounds, fitBoundOptions: fitBoundOptions);
}

Future<Unit> selectUnit(BuildContext context) async {
  // flutter defined function
  return await showDialog<Unit>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Velg enhet", textAlign: TextAlign.start),
        ),
        body: UnitsPage(
          withActions: false,
          onSelection: (unit) => Navigator.pop(context, unit),
        ),
      );
    },
  );
}

Widget buildCopyableText({
  BuildContext context,
  String label,
  Icon icon,
  String value,
  MessageCallback onMessage,
}) {
  return GestureDetector(
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon,
        border: InputBorder.none,
      ),
      child: Text(value),
    ),
    onLongPress: () {
      Navigator.pop(context);
      copy(value, onMessage);
    },
  );
}

void copy(String value, MessageCallback onMessage, {String message: 'Kopiert til utklippstavlen'}) {
  Clipboard.setData(ClipboardData(text: value));
  if (onMessage != null) {
    onMessage(message);
  }
}
