import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class PointField extends StatelessWidget {
  final String attribute;
  final String hintText;
  final String labelText;
  final String errorText;
  final String helperText;
  final Point initialValue;
  final Incident incident;
  final bool optional;
  final bool enabled;
  final ValueChanged<Point> onChanged;
  final PermissionController controller;

  const PointField({
    Key key,
    @required this.attribute,
    @required this.labelText,
    @required this.hintText,
    @required this.errorText,
    @required this.controller,
    this.incident,
    this.initialValue,
    this.onChanged,
    this.helperText,
    this.enabled = true,
    this.optional = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormBuilderCustomField(
      attribute: attribute,
      formField: FormField<Point>(
        enabled: enabled,
        initialValue: initialValue,
        builder: (FormFieldState<Point> field) => GestureDetector(
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              enabled: true,
              labelText: labelText,
              helperText: helperText,
              suffixIcon: enabled ? Icon(Icons.map) : null,
              contentPadding: EdgeInsets.fromLTRB(12.0, 16.0, 8.0, 16.0),
              errorText: field.hasError ? field.errorText : null,
              border: enabled ? UnderlineInputBorder() : InputBorder.none,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: field.value == null
                  ? Text(hintText, style: Theme.of(context).textTheme.caption.copyWith(fontSize: 16))
                  : Text(
                      toUTM(field.value),
                      style: Theme.of(context).textTheme.subhead.copyWith(fontSize: 16),
                    ),
            ),
          ),
          onTap: enabled ? () => _selectLocation(context, field) : null,
        ),
      ),
      valueTransformer: (point) => point?.toJson(),
      validators: [
        if (optional == false) FormBuilderValidators.required(errorText: errorText),
      ],
    );
  }

  void _selectLocation(BuildContext context, FormFieldState<Point> field) async {
    final selected = await showDialog<Point>(
      context: context,
      builder: (context) => PointEditor(
        field.value,
        title: hintText,
        incident: incident,
        controller: controller,
      ),
    );
    if (selected != field.value) {
      field.didChange(selected);
      if (onChanged != null) onChanged(selected);
    }
  }
}
