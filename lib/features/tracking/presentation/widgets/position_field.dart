// @dart=2.11

import 'package:SarSys/features/tracking/presentation/editors/position_editor.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class PositionField extends StatelessWidget {
  final String name;
  final String hintText;
  final String labelText;
  final String errorText;
  final String helperText;
  final Position initialValue;
  final Operation operation;
  final bool optional;
  final bool enabled;
  final ValueChanged<Position> onChanged;

  const PositionField({
    Key key,
    @required this.name,
    @required this.labelText,
    @required this.hintText,
    @required this.errorText,
    this.operation,
    this.initialValue,
    this.onChanged,
    this.helperText,
    this.enabled = true,
    this.optional = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormBuilderField(
      name: name,
//      formField: FormField<Position>(
      enabled: enabled,
      initialValue: initialValue,
      builder: (FormFieldState<Position> field) => GestureDetector(
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
                ? Text(hintText, style: Theme.of(context).textTheme.bodyText2.copyWith(color: Colors.grey))
                : Text(
                    toUTM(field.value?.geometry),
                    style: Theme.of(context).textTheme.subtitle2.copyWith(fontSize: 16),
                  ),
          ),
        ),
        onTap: enabled ? () => _selectLocation(context, field) : null,
      ),
//      ),
      valueTransformer: (point) => point?.toJson(),
      validator: FormBuilderValidators.compose([
        if (optional == false) FormBuilderValidators.required(context, errorText: errorText),
      ]),
    );
  }

  void _selectLocation(BuildContext context, FormFieldState<Position> field) async {
    final selected = await showDialog<Position>(
      context: context,
      builder: (context) => PositionEditor(
        field.value,
        title: hintText,
        operation: operation,
      ),
    );
    if (selected != field.value) {
      field.didChange(selected ?? initialValue);
      if (onChanged != null) onChanged(selected ?? initialValue);
    }
  }
}
