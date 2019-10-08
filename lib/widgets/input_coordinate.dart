import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:latlong/latlong.dart';

class InputUTM extends StatefulWidget {
  final int zone;
  final bool isSouth;
  final String band;
  final LatLng point;
  final ValueChanged<LatLng> onChanged;
  final VoidCallback onEditingComplete;
  final bool withBorder;

  const InputUTM({
    Key key,
    this.point,
    this.zone = 32,
    this.band = 'V',
    this.isSouth = false,
    this.withBorder = false,
    this.onChanged,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  _InputUTMState createState() => _InputUTMState();
}

class _InputUTMState extends State<InputUTM> {
  FocusNode _northingFocusNode;
  TransverseMercatorProjection proj;

  TextEditingController _eastingController;
  TextEditingController _northingController;

  @override
  void initState() {
    super.initState();
    _northingFocusNode = FocusNode();
    proj = toUTMProj(
      zone: widget.zone,
      isSouth: widget.isSouth,
    );
    _eastingController = TextEditingController();
    _northingController = TextEditingController();
    _setUTM();
  }

  @override
  void didUpdateWidget(InputUTM old) {
    super.didUpdateWidget(old);
    if (widget.point != old.point || widget.isSouth != old.isSouth) {
      _setUTM();
    }
  }

  void _setUTM() {
    final utm = _toUTM(widget.point);
    _eastingController.text = utm?.x?.toStringAsFixed(0) ?? '';
    _northingController.text = utm?.y?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _northingFocusNode.dispose();
    _eastingController.dispose();
    _northingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = _toBand(widget.point);
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: widget.withBorder
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 58.0,
            child: _buildZoneField(),
          ),
          SizedBox(width: 8.0),
          SizedBox(
            width: 56.0,
            child: _buildBandField(band),
          ),
          SizedBox(width: 8.0),
          Flexible(
            flex: 2,
            child: _buildEastingField(),
          ),
          SizedBox(width: 8.0),
          Flexible(
            flex: 2,
            child: buildNorthingField(),
          ),
        ],
      ),
    );
  }

  String _toBand(LatLng point) {
    return point != null
        ? TransverseMercatorProjection.toBand(
            point.latitude,
            isSouth: widget.isSouth,
          )
        : widget.band;
  }

  ProjCoordinate _toUTM(LatLng point) {
    return point != null
        ? proj.project(ProjCoordinate.from2D(
            point.longitude,
            point.latitude,
          ))
        : null;
  }

  Widget _buildEastingField() {
    return TextFormField(
      controller: _eastingController,
      maxLength: 7,
      autovalidate: true,
      decoration: InputDecoration(
        hintText: "Østlig",
        filled: true,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8.0),
      ),
      autocorrect: true,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.number,
      onChanged: (value) => _update(value, _northingController.text),
      validator: (value) => int.tryParse(value) == null ? "Kun heltall" : null,
      onEditingComplete: () {
        FocusScope.of(context).unfocus();
        if (_update(_eastingController.text, _northingController.text)) {
          if (widget.onEditingComplete != null) widget.onEditingComplete();
        } else {
          FocusScope.of(context).requestFocus(_northingFocusNode);
        }
      },
    );
  }

  Widget buildNorthingField() {
    return TextFormField(
      controller: _northingController,
      maxLength: 7,
      autovalidate: true,
      decoration: InputDecoration(
        hintText: "Nordlig",
        filled: true,
        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      ),
      autocorrect: true,
      focusNode: _northingFocusNode,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.number,
      onChanged: (value) => _update(_eastingController.text, value),
      validator: (value) => int.tryParse(value) == null ? "Kun heltall" : null,
      onEditingComplete: () {
        FocusScope.of(context).unfocus();
        _update(_eastingController.text, _northingController.text);
        if (widget.onEditingComplete != null) widget.onEditingComplete();
      },
    );
  }

  Widget _buildZoneField() {
    return buildDropDownField(
      attribute: 'zone',
      initialValue: 32,
      isDense: false,
      items: [31, 32, 33, 34, 35, 36, 37]
          .map(
            (zone) => DropdownMenuItem(value: zone, child: Text("$zone")),
          )
          .toList(),
      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      validators: [
        FormBuilderValidators.required(errorText: 'Sone må velges'),
      ],
    );
  }

  Widget _buildBandField(String band) {
    // TODO: Limit band to legal range
    return buildDropDownField(
      attribute: 'band',
      initialValue: band,
      isDense: false,
      items: ["V", "W", "X"]
          .map(
            (band) => DropdownMenuItem(value: band, child: Text("$band")),
          )
          .toList(),
      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      validators: [
        FormBuilderValidators.required(errorText: 'Bånd må velges'),
      ],
    );
  }

  bool _update(String easting, String northing) {
    final x = double.tryParse(easting);
    final y = double.tryParse(northing);
    if (x == null || y == null) return false;
    if (widget.onChanged != null) {
      final point = proj.inverse(ProjCoordinate.from2D(x, y));
      widget.onChanged(LatLng(point.y, point.x));
    }
    return true;
  }
}
