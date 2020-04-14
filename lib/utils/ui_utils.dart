import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/app_state.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/map/models/map_widget_state_model.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/services/location_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:latlong/latlong.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

typedef MessageCallback = void Function(String message);
typedef PromptCallback = Future<bool> Function(String title, String message);
typedef ActionCallback<T> = void Function(String message, {String action, VoidCallback onPressed, T data});
typedef AsyncActionCallback<T> = Future Function(String message, {String action, VoidCallback onPressed, T data});

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
          FlatButton(
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
  return showDialog<bool>(
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
  @required T initialValue,
  @required List<DropdownMenuItem<T>> items,
  @required List<FormFieldValidator> validators,
  String label,
  String helperText,
  bool isDense = true,
  bool enabled = true,
  EdgeInsetsGeometry contentPadding,
  ValueChanged<T> onChanged,
}) =>
    FormBuilderCustomField(
      attribute: attribute,
      formField: FormField<T>(
        enabled: enabled,
        initialValue: initialValue,
        builder: (FormFieldState<T> field) => buildDropdown<T>(
          value: field.value,
          hasError: field.hasError,
          errorText: field.errorText,
          label: label,
          helperText: helperText,
          items: items,
          isDense: isDense,
          initialValue: initialValue,
          contentPadding: contentPadding,
          onChanged: (T newValue) {
            field.didChange(newValue);
            if (onChanged != null) onChanged(newValue);
          },
        ),
      ),
      validators: validators,
    );

Widget buildDropdown<T>({
  @required T value,
  @required List<DropdownMenuItem<T>> items,
  @required ValueChanged<T> onChanged,
  String label,
  String helperText,
  EdgeInsetsGeometry contentPadding,
  T initialValue,
  bool isDense = true,
  bool hasError = false,
  String errorText,
}) {
  T selected = items.firstWhere((item) => item.value == value, orElse: () => null)?.value ?? initialValue;
  return InputDecorator(
    decoration: InputDecoration(
      hasFloatingPlaceholder: true,
      errorText: hasError ? errorText : null,
      filled: true,
      isDense: false,
      labelText: label,
      helperText: helperText,
      contentPadding: contentPadding,
    ),
    child: DropdownButtonHideUnderline(
      child: ButtonTheme(
        alignedDropdown: false,
        child: DropdownButton<T>(
          value: selected,
          isDense: isDense,
          onChanged: onChanged,
          items: items,
        ),
      ),
    ),
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
    case TrackingStatus.Tracking:
      return Colors.green;
    case TrackingStatus.Paused:
      return Colors.orange;
    case TrackingStatus.Closed:
      return Colors.brown;
    case TrackingStatus.Created:
      return Colors.grey;
    case TrackingStatus.None:
    default:
      return Colors.red;
  }
}

IconData toTrackingIconData(TrackingStatus status) {
  switch (status) {
    case TrackingStatus.Created:
      return Icons.more_horiz;
    case TrackingStatus.Paused:
      return Icons.pause;
    case TrackingStatus.Closed:
      return Icons.check_circle;
    case TrackingStatus.Tracking:
      return Icons.play_circle_filled;
    default:
      return Icons.warning;
  }
}

Color toUnitStatusColor(UnitStatus status) {
  switch (status) {
    case UnitStatus.Deployed:
      return Colors.green;
    case UnitStatus.Retired:
      return Colors.brown;
    case UnitStatus.Mobilized:
    default:
      return Colors.orange;
  }
}

IconData toUnitIconData(UnitType type) {
  switch (type) {
    case UnitType.ATV:
    case UnitType.Snowmobile:
    case UnitType.Vehicle:
      return MdiIcons.carEstate;
    case UnitType.Boat:
      return Icons.directions_boat;
    case UnitType.K9:
      return FontAwesomeIcons.dog;
    case UnitType.CommandPost:
      return FontAwesomeIcons.shieldAlt;
    case UnitType.Team:
    case UnitType.Other:
    default:
      return Icons.people;
  }
}

IconData toDeviceIconData(DeviceType type) {
  switch (type) {
    case DeviceType.App:
      return Icons.phone_android;
    case DeviceType.AIS:
      return MdiIcons.ferry;
    case DeviceType.APRS:
      return MdiIcons.radioHandheld;
    case DeviceType.Tetra:
    default:
      return MdiIcons.cellphoneBasic;
  }
}

IconData toDialerIconData(DeviceType type) {
  switch (type) {
    case DeviceType.App:
      return Icons.phone;
    case DeviceType.AIS:
    case DeviceType.APRS:
    case DeviceType.Tetra:
    default:
      return Icons.headset_mic;
  }
}

Color toPersonnelStatusColor(PersonnelStatus status) {
  switch (status) {
    case PersonnelStatus.OnScene:
      return Colors.green;
    case PersonnelStatus.Retired:
      return Colors.brown;
    case PersonnelStatus.Mobilized:
    default:
      return Colors.orange;
  }
}

IconData toPersonnelIconData(Personnel personnel) {
  return Icons.person;
}

Color toPointStatusColor(Point point) {
  final since = (point == null ? null : DateTime.now().difference(point.timestamp).inMinutes);
  return since == null || since > 5 ? Colors.red : (since > 1 ? Colors.orange : Colors.green);
}

void jumpToPoint(BuildContext context, {Point center, Incident incident}) {
  jumpToLatLng(context, center: toLatLng(center), incident: incident);
}

void jumpToLatLng(BuildContext context, {LatLng center, Incident incident}) {
  if (center != null) {
    _stopFollowMe(context);
    Navigator.pushReplacementNamed(context, MapScreen.ROUTE, arguments: {"center": center, "incident": incident});
  }
}

void jumpToLatLngBounds(
  BuildContext context, {
  Incident incident,
  LatLngBounds fitBounds,
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  if (fitBounds != null && fitBounds.isValid) {
    _stopFollowMe(context);
    Navigator.pushReplacementNamed(context, MapScreen.ROUTE, arguments: {
      "incident": incident,
      "fitBounds": fitBounds,
      "fitBoundOptions": fitBoundOptions,
    });
  }
}

void _stopFollowMe(BuildContext context) {
  // Disable location lock?
  var model = readState<MapWidgetStateModel>(context, MapWidgetState.STATE, defaultValue: MapWidgetStateModel());
  if (model?.following == true) {
    writeState(context, MapWidgetState.STATE, model.cloneWith(following: false));
    writeAppState(PageStorage.of(context));
  }
}

void jumpToMe(
  BuildContext context, {
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) async {
  final service = LocationService(BlocProvider.of<AppConfigBloc>(context));
  var status = service.status;
  if (PermissionStatus.unknown == status) {
    status = await service.configure();
  }
  if ([PermissionStatus.granted].contains(status)) {
    var current = service.current;
    if (current != null) {
      jumpToLatLng(
        context,
        center: LatLng(
          current.latitude,
          current.longitude,
        ),
      );
    }
  }
}

void jumpToIncident(
  BuildContext context,
  Incident incident, {
  FitBoundsOptions fitBoundOptions = FIT_BOUNDS_OPTIONS,
}) {
  final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
  final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
  final fitBounds = LatLngBounds(ipp, meetup);
  if (ipp == null || meetup == null || fitBounds.isValid == false)
    jumpToLatLng(context, center: meetup ?? ipp, incident: incident);
  else
    jumpToLatLngBounds(context, fitBounds: fitBounds, fitBoundOptions: fitBoundOptions);
}

Future<bool> navigateToLatLng(BuildContext context, LatLng point) async {
  final url = Platform.isIOS ? "comgooglemaps://?q" : "google.navigation:q";
  var success = await launch("$url=${point.latitude},${point.longitude}");
  if (success == false && Platform.isIOS) {
    final service = LocationService(BlocProvider.of<AppConfigBloc>(context));
    var status = service.status;
    if (PermissionStatus.unknown == status) {
      status = await service.configure();
    }
    if ([PermissionStatus.granted].contains(status)) {
      var current = service.current;
      if (current != null) {
        success = await launch(
          "http://maps.apple.com/maps?"
          "saddr=${current.latitude},${current.longitude}&"
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
  bool selectable = false,
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
            hintMaxLines: 3,
            prefixIcon: icon == null ? Container(width: 24.0) : icon,
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
