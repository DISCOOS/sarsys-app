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
