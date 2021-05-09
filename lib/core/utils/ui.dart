import 'dart:io';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/mapping/presentation/models/map_widget_state_model.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart' as sarsys;
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/mapping/presentation/screens/map_screen.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:SarSys/core/callbacks.dart';

const FIT_BOUNDS_OPTIONS = const FitBoundsOptions(
  zoom: Defaults.zoom,
  maxZoom: Defaults.zoom,
  padding: EdgeInsets.all(48.0),
);

Future<void> alert(BuildContext context, {String title, Widget content}) {
  // flutter defined function
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return AlertDialog(
        title: title == null ? Container() : Text(title),
        content: content,
        actions: <Widget>[
          TextButton(
            child: Text("LUKK"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

Future<bool> prompt(BuildContext context, String title, String message) async {
  // flutter defined function
  final answer = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text("AVBRYT"),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          TextButton(
            child: Text("FORTSETT"),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
  return answer ?? false;
}

FormBuilderField<T> buildReadOnlyField<T>(
  BuildContext context,
  String name,
  String label,
  String title,
  T value,
) {
  return FormBuilderField<T>(
    name: name,
    enabled: false,
    initialValue: value,
    builder: (FormFieldState<T> field) => InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        enabled: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          title ?? '-',
        ),
      ),
    ),
  );
}

Widget buildDropDownField<T>({
  @required String name,
  @required T initialValue,
  @required List<DropdownMenuItem<T>> items,
  @required FormFieldValidator validator,
  String label,
  String helperText,
  bool isDense = true,
  bool enabled = true,
  EdgeInsetsGeometry contentPadding,
  ValueChanged<T> onChanged,
}) =>
    FormBuilderField(
      name: name,
      enabled: enabled,
      initialValue: initialValue,
      builder: (FormFieldState<T> field) => buildDropdown<T>(
        value: _ensureLegalItem(field, items),
        hasError: field.hasError,
        errorText: field.errorText,
        label: label,
        helperText: helperText,
        items: items,
        isDense: isDense,
        enabled: enabled,
        initialValue: initialValue,
        contentPadding: contentPadding,
        onChanged: (T newValue) {
          field.didChange(newValue);
          if (onChanged != null) onChanged(newValue);
        },
      ),
      validator: validator,
    );

T _ensureLegalItem<T>(FormFieldState field, List<DropdownMenuItem<T>> items) {
  if (items.any((item) => item.value == field.value)) {
    return field.value;
  }
  return items.first.value;
}

Widget buildDropdown<T>({
  @required T value,
  @required List<DropdownMenuItem<T>> items,
  @required ValueChanged<T> onChanged,
  String label,
  String helperText,
  EdgeInsetsGeometry contentPadding,
  T initialValue,
  bool isDense = true,
  bool enabled = true,
  bool hasError = false,
  String errorText,
}) {
  T selected = items.firstWhere((item) => item.value == value, orElse: () => null)?.value ?? initialValue;
  return InputDecorator(
    decoration: InputDecoration(
      errorText: hasError ? errorText : null,
      filled: true,
      isDense: false,
      enabled: enabled,
      labelText: label,
      helperText: helperText,
      contentPadding: contentPadding,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
    child: enabled
        ? DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: false,
              child: Builder(builder: (context) {
                return DropdownButton<T>(
                  value: selected,
                  isDense: isDense,
                  onChanged: (T value) {
                    // Unfocus input-fields with current focus
                    FocusScope.of(context).requestFocus(FocusNode());
                    onChanged?.call(value);
                  },
                  items: items,
                );
              }),
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: items.firstWhere((item) => item.value == selected, orElse: () => null)?.child,
          ),
  );
}

Widget buildChipsField<T>({
  @required String name,
  @required String selectorTitle,
  @required String selectorLabel,
  @required ItemWidgetBuilder<T> builder,
  @required ValueGetter<Iterable<T>> items,
  @required Iterable<T> Function(String category, String query) options,
  String hintText,
  String category,
  String labelText,
  String helperText,
  String emptyText,
  bool enabled = true,
  ValueChanged<Iterable<T>> onChanged,
  Iterable<DropdownMenuItem<String>> categories = const [],
}) {
  var query;
  return FormBuilderField<Iterable<T>>(
    name: name,
    initialValue: items(),
    builder: (FormFieldState<Iterable<T>> field) {
      return Builder(
        builder: (context) {
          final hintStyle = Theme.of(context).textTheme.bodyText2.copyWith(color: Colors.grey);
          final chips = items().map((item) => builder(context, item)).toList();
          return GestureDetector(
            child: InputDecorator(
              child: Wrap(
                spacing: 4.0,
                runSpacing: -4.0,
                clipBehavior: Clip.antiAlias,
                children: chips.isEmpty ? [Text(hintText, style: hintStyle)] : chips,
              ),
              decoration: InputDecoration(
                filled: true,
                enabled: enabled,
                hintText: hintText,
                labelText: labelText,
                helperText: chips.isEmpty ? emptyText : helperText,
                suffix: Icon(
                  Icons.edit,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (_) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(selectorTitle),
                    ),
                    body: StatefulBuilder(builder: (context, setState) {
                      final found = options(category, query)
                          .map((item) => FormBuilderFieldOption<T>(
                                value: item,
                                child: builder(context, item),
                              ))
                          .toList();
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              if (categories != null)
                                DropdownButton<String>(
                                  isExpanded: true,
                                  items: categories.toList(),
                                  onChanged: (value) => setState(
                                    () => category = value,
                                  ),
                                  value: category ?? categories.first.value,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: FormBuilderTextField(
                                  name: 'query',
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    hintText: hintText,
                                    hintStyle: hintStyle,
                                  ),
                                  initialValue: query,
                                  onChanged: (value) {
                                    setState(
                                      () => query = value,
                                    );
                                  },
                                ),
                              ),
                              FormBuilderFilterChip<T>(
                                name: 'selectables',
                                spacing: 4.0,
                                initialValue: items(),
                                selectedColor: Colors.green.shade200,
                                checkmarkColor: Colors.green.shade900,
                                padding: const EdgeInsets.all(0),
                                labelPadding: const EdgeInsets.all(0),
                                options: found,
                                decoration: InputDecoration(
                                  filled: false,
                                  isDense: true,
                                  hintText: hintText,
                                  hintStyle: hintStyle,
                                  helperText: found.isEmpty ? emptyText : helperText,
                                  labelText: selectorLabel,
                                ),
                                onChanged: (items) {
                                  field.didChange(items);
                                  if (onChanged != null) {
                                    onChanged(items);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

Widget buildTwoCellRow(Widget left, Widget right, {double spacing = 16.0, int lflex = 6, rflex = 6}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        flex: lflex,
        child: left,
      ),
      SizedBox(width: spacing),
      Expanded(
        flex: rflex,
        child: right,
      ),
    ],
  );
}

Color toTrackingStatusColor(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.tracking:
      return Colors.green;
    case TrackingStatus.paused:
      return Colors.orange;
    case TrackingStatus.closed:
      return Colors.brown;
    case TrackingStatus.ready:
      return Colors.grey;
    case TrackingStatus.none:
    default:
      return Colors.red;
  }
}

IconData toTrackingIconData(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.ready:
      return Icons.more_horiz;
    case TrackingStatus.paused:
      return Icons.pause;
    case TrackingStatus.closed:
      return Icons.check_circle;
    case TrackingStatus.tracking:
      return Icons.play_circle_filled;
    default:
      return Icons.warning;
  }
}

Color toUnitStatusColor(UnitStatus status) {
  switch (status) {
    case UnitStatus.deployed:
      return Colors.green;
    case UnitStatus.retired:
      return Colors.brown;
    case UnitStatus.mobilized:
    default:
      return Colors.orange;
  }
}

IconData toUnitIconData(UnitType type) {
  switch (type) {
    case UnitType.atv:
    case UnitType.snowmobile:
    case UnitType.vehicle:
      return MdiIcons.carEstate;
    case UnitType.boat:
      return Icons.directions_boat;
    case UnitType.k9:
      return FontAwesomeIcons.dog;
    case UnitType.commandpost:
      return FontAwesomeIcons.shieldAlt;
    case UnitType.team:
    case UnitType.other:
    default:
      return Icons.people;
  }
}

IconData toDeviceIconData(DeviceType type) {
  switch (type) {
    case DeviceType.app:
      return Icons.phone_android;
    case DeviceType.ais:
      return MdiIcons.ferry;
    case DeviceType.aprs:
      return MdiIcons.radioHandheld;
    case DeviceType.tetra:
    default:
      return MdiIcons.cellphoneBasic;
  }
}

IconData toDialerIconData(DeviceType type) {
  switch (type) {
    case DeviceType.app:
      return Icons.phone;
    case DeviceType.ais:
    case DeviceType.aprs:
    case DeviceType.tetra:
    default:
      return Icons.headset_mic;
  }
}

Color toPersonnelStatusColor(PersonnelStatus status) {
  switch (status) {
    case PersonnelStatus.onscene:
      return Colors.green;
    case PersonnelStatus.retired:
      return Colors.brown;
    case PersonnelStatus.alerted:
    default:
      return Colors.orange;
  }
}

IconData toPersonnelIconData(Personnel personnel) {
  return Icons.person;
}

Color toAffiliationStandbyStatusColor(AffiliationStandbyStatus status) {
  switch (status) {
    case AffiliationStandbyStatus.available:
      return Colors.green;
    case AffiliationStandbyStatus.unavailable:
      return Colors.brown;
    case AffiliationStandbyStatus.short_notice:
    default:
      return Colors.orange;
  }
}

IconData toAffiliationIconData(BuildContext context, Affiliation affiliation) {
  return SarSysIcons.of(
    context.bloc<AffiliationBloc>().orgs[affiliation?.org?.uuid]?.prefix,
  ).icon;
}

Color toPositionStatusColor(Position position) {
  final since = (position == null ? null : DateTime.now().difference(position.timestamp).inMinutes);
  return since == null || since > 5 ? Colors.red : (since > 1 ? Colors.orange : Colors.green);
}

void jumpToPoint(BuildContext context, {sarsys.Point center, Operation operation}) {
  jumpToLatLng(context, center: toLatLng(center), operation: operation);
}

void jumpToLatLng(BuildContext context, {LatLng center, Operation operation}) {
  if (center != null) {
    _stopFollowMe(context);
    Navigator.pushReplacementNamed(context, MapScreen.ROUTE, arguments: {
      "center": center,
      "operation": operation,
    });
  }
}

void jumpToLatLngBounds(
  BuildContext context, {
  Operation operation,
  LatLngBounds fitBounds,
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  if (fitBounds != null && fitBounds.isValid) {
    _stopFollowMe(context);
    Navigator.pushReplacementNamed(context, MapScreen.ROUTE, arguments: {
      "operation": operation,
      "fitBounds": fitBounds,
      "fitBoundOptions": fitBoundOptions,
    });
  }
}

void _stopFollowMe(BuildContext context) {
  // Disable location lock?
  var model = getPageState<MapWidgetStateModel>(context, MapWidgetState.STATE, defaultValue: MapWidgetStateModel());
  if (model?.following == true) {
    putPageState(context, MapWidgetState.STATE, model.cloneWith(following: false));
    writePageStorageBucket(PageStorage.of(context));
  }
}

void jumpToMe(
  BuildContext context, {
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) async {
  final service = LocationService();
  var status = await service.status;
  if (PermissionStatus.undetermined == status) {
    await service.configure();
  }
  if (status == PermissionStatus.granted) {
    var current = service.current;
    if (current != null) {
      jumpToLatLng(
        context,
        center: current.toLatLng(),
      );
    }
  }
}

void jumpToOperation(
  BuildContext context,
  Operation operation, {
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  final ipp = operation.ipp != null ? toLatLng(operation.ipp.point) : null;
  final meetup = operation.meetup != null ? toLatLng(operation.meetup.point) : null;
  final fitBounds = LatLngBounds(ipp, meetup);
  if (ipp == null || meetup == null || fitBounds.isValid == false)
    jumpToLatLng(
      context,
      center: meetup ?? ipp,
      operation: operation,
    );
  else
    jumpToLatLngBounds(
      context,
      fitBounds: fitBounds,
      fitBoundOptions: fitBoundOptions,
    );
}

Future<bool> navigateToLatLng(BuildContext context, LatLng point) async {
  final url = Platform.isIOS ? "comgooglemaps://?q" : "google.navigation:q";
  var success = await launch("$url=${point.latitude},${point.longitude}");
  if (success == false && Platform.isIOS) {
    final service = LocationService();
    var status = await service.status;
    if (PermissionStatus.undetermined == status) {
      await service.configure();
    }
    if (status == PermissionStatus.granted) {
      var current = service.current;
      if (current != null) {
        success = await launch(
          "https://maps.apple.com/maps?"
          "saddr=${current.lat},${current.lon}&"
          "daddr=${point.latitude},${point.longitude}",
        );
      }
    }
  }
  return success;
}

Widget buildCopyableText({
  BuildContext context,
  String label,
  Icon icon,
  String value,
  Icon action,
  int hintMaxLines = 3,
  bool isDense = false,
  bool selectable = false,
  EdgeInsetsGeometry contentPadding,
  GestureTapCallback onAction,
  ValueChanged<String> onCopy,
  MessageCallback onMessage,
  GestureTapCallback onTap,
  VoidCallback onComplete,
}) =>
    GestureDetector(
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: isDense,
            hintMaxLines: hintMaxLines,
            contentPadding: contentPadding,
            prefixIcon: icon,
            suffixIcon: action != null
                ? IconButton(
                    icon: action,
                    onPressed: onAction,
                  )
                : null,
            border: InputBorder.none,
          ),
          child: selectable ? SelectableText(value) : Text(value),
        ),
        onTap: onTap,
        onLongPress: () {
          if (onCopy != null) onCopy(value);
          if (onComplete != null) onComplete();
          copy(value, onMessage, message: '"$value" kopiert til utklippstavlen');
        });

void copy(String value, MessageCallback onMessage, {String message: 'Kopiert til utklippstavlen'}) {
  Clipboard.setData(ClipboardData(text: value));
  if (onMessage != null) {
    onMessage(message);
  }
}

void setText(TextEditingController controller, String value) {
  // Workaround for errors when clearing TextField,
  // see https://github.com/flutter/flutter/issues/17647
  if (emptyAsNull(value) == null)
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.clear());
  else if (value != null) {
    final selection = controller.selection;

    controller.value = TextEditingValue(
      text: value,
      selection:
          selection.extentOffset > value?.length ?? 0 ? TextSelection.collapsed(offset: value?.length ?? 0) : selection,
    );
  }
}

SingleChildScrollView toRefreshable(
  BoxConstraints viewportConstraints, {
  Widget child,
  List<Widget> children,
  String message,
}) =>
    SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: viewportConstraints.maxHeight,
        ),
        child: child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children ??
                  [
                    Container(
                      alignment: Alignment.center,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
            ),
      ),
    );

Widget keyboardDismisser({BuildContext context, Widget child}) {
  final gesture = GestureDetector(
    onTap: () {
      FocusScope.of(context).requestFocus(FocusNode());
    },
    child: child,
  );
  return gesture;
}
