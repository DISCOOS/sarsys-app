import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

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

void jumpToPoint(BuildContext context, Point location) {
  if (location != null) {
    Navigator.pushNamed(context, "map", arguments: toLatLng(location));
  }
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
