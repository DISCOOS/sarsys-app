import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/services/geocode_services.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:latlong/latlong.dart';
import 'package:provider/provider.dart';

typedef ErrorCallback = void Function(String message);
typedef MatchCallback = void Function(LatLng point);

class MapSearchField extends StatefulWidget {
  final double zoom;
  final String hintText;
  final ErrorCallback onError;
  final MatchCallback onMatch;
  final VoidCallback onCleared;
  final IncidentMapController mapController;

  final Widget prefixIcon;

  final bool withRetired;

  final bool withBorder;

  final double offset;

  const MapSearchField({
    Key key,
    @required this.onError,
    @required this.mapController,
    this.onMatch,
    this.onCleared,
    this.prefixIcon,
    this.zoom,
    this.hintText,
    this.offset = 16.0,
    this.withBorder = true,
    this.withRetired = false,
  }) : super(key: key);

  @override
  MapSearchFieldState createState() => MapSearchFieldState();
}

class MapSearchFieldState extends State<MapSearchField> with TickerProviderStateMixin {
  final _searchKey = GlobalKey();
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  LatLng _match;
  OverlayEntry _overlayEntry;

  bool get hasFocus => _focusNode?.hasFocus ?? false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => {
        setState(() {}),
      },
    );
  }

  @override
  void dispose() {
    _hideResults();
    _focusNode.dispose();
    widget.mapController?.cancel();
    super.dispose();
  }

  void setQuery(String query) => setState(() {
        _controller.text = query;
        _focusNode.requestFocus();
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).iconTheme;
    return Container(
      padding: EdgeInsets.zero,
      decoration: widget.withBorder
          ? BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.prefixIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: widget.prefixIcon ?? Container(),
            ),
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                suffixIcon: _buildClearButton(theme),
                border: widget.withBorder ? InputBorder.none : UnderlineInputBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: TextField(
                  key: _searchKey,
                  focusNode: _focusNode,
                  autofocus: false,
                  controller: _controller,
                  onSubmitted: (value) => _search(value),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintMaxLines: 1,
                    hintText: widget.hintText ?? "Søk her",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(IconThemeData theme) {
    return _focusNode.hasFocus || _match != null || _overlayEntry != null
        ? IconButton(
            icon: Icon(Icons.close, color: theme.color),
            onPressed: () => clear(),
          )
        : Icon(
            Icons.search,
            color: theme.color.withOpacity(0.4),
          );
  }

  /// Hide overlay with results if shown, clear content and unfocus textfield
  void clear() async {
    setState(() {
      _match = null;
      _hideResults();
      _controller.clear();
      if (widget.onCleared != null) widget.onCleared();
      FocusScope.of(context).unfocus();
    });
  }

  void _hideResults() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showResults(List<GeocodeResult> results) async {
    final RenderBox renderBox = _searchKey.currentContext.findRenderObject();
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _hideResults();
    _focusNode.requestFocus();

    final choices = results
        .map((result) => result is AddressLookup ? _buildListTileFromLookup(result) : _buildListTile(context, result))
        .take(10)
        .toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 8.0,
        top: offset.dy + size.height + widget.offset,
        width: MediaQuery.of(context).size.width - 16.0,
        height: MediaQuery.of(context).size.height - (offset.dy + size.height + 16.0),
        child: Material(
          elevation: 0.0,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: choices.length,
              semanticChildCount: choices.length,
              itemBuilder: (BuildContext context, int index) => choices[index],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(this._overlayEntry);
  }

  Widget _buildListTileFromLookup(AddressLookup lookup) {
    return FutureBuilder<GeocodeResult>(
      initialData: lookup,
      future: lookup.search,
      builder: (BuildContext context, AsyncSnapshot<GeocodeResult> snapshot) {
        return _buildListTile(context, snapshot.hasData ? snapshot.data : lookup);
      },
    );
  }

  ListTile _buildListTile(BuildContext context, GeocodeResult data) {
    final backgroundColor = Theme.of(context).canvasColor;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(data.icon, size: 36.0),
        backgroundColor: backgroundColor,
      ),
      title: Text(_toTitle(data)),
      subtitle: Text(toLocation(data)),
      contentPadding: _toPadding(data),
      trailing: _toSource(data, context),
      onTap: () {
        _goto(data.latitude, data.longitude);
      },
    );
  }

  String _toTitle(GeocodeResult data) => "${data.title ?? ''}".trim();

  String _distanceFromMe(GeocodeResult data) => widget.mapController.center != null
      ? formatDistance(ProjMath.eucledianDistance(
          data.latitude,
          data.longitude,
          widget.mapController.center.latitude,
          widget.mapController.center.longitude,
        ))
      : null;

  EdgeInsets _toPadding(GeocodeResult data) =>
      data.address == null ? EdgeInsets.only(left: 16.0, right: 16.0) : EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0);

  String toLocation(GeocodeResult data) =>
      data.address == null ? data.position : [data.address, data.position].where((test) => test != null).join("\n");

  Padding _toSource(GeocodeResult data, BuildContext context) {
    final caption = Theme.of(context).textTheme.caption;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            data.source,
            style: caption,
          ),
          Text(
            _distanceFromMe(data) ?? '',
            style: caption,
          )
        ],
      ),
    );
  }

  void _search(String value) async {
    if (_searchCoords(value) == false) {
      if (await _searchGeocode(value) == false) {
        _hideResults();
        if (widget.onError != null) widget.onError('"$value" ikke funnet');
      }
    }
  }

  bool _searchCoords(String value) {
    final coords = CoordinateFormat.toLatLng(value);
    final found = coords != null;
    if (found) {
      _goto(coords.x, coords.y);
    }
    return found;
  }

  Future<bool> _searchGeocode(String value) async {
    final manager = MapSearchEngine(
      Provider.of<Client>(context),
      Provider.of<BlocProviderController>(context),
      withRetired: widget.withRetired,
    );
    try {
      final results = await manager.search(value);
      if (results.length > 0) {
        _showResults(results);
      }
      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _goto(lat, lon) {
    _match = LatLng(lat, lon);
    if (!kReleaseMode) print("Goto: $_match");
    widget.mapController.animatedMove(_match, widget.zoom ?? widget.mapController.zoom, this);
    if (widget.onMatch != null) widget.onMatch(_match);
    FocusScope.of(context).unfocus();
    _hideResults();
  }
}

class MapSearchEngine {
  final Client client;
  final PlaceGeocoderService _placeGeocoderService;
  final LocalGeocoderService _localGeocoderService;
  final AddressGeocoderService _addressGeocoderService;
  final ObjectGeocoderService _objectGeocoderService;

  MapSearchEngine(
    this.client,
    BlocProviderController controller, {
    bool withRetired,
  })  : this._placeGeocoderService = PlaceGeocoderService(client),
        this._addressGeocoderService = AddressGeocoderService(client),
        this._objectGeocoderService = ObjectGeocoderService(
          AddressGeocoderService(client),
          controller,
          withRetired,
        ),
        this._localGeocoderService = LocalGeocoderService();

  Future<List<GeocodeResult>> search(String query) async {
    final futures = [
      _objectGeocoderService.search(query),
      _placeGeocoderService.search(query),
      _addressGeocoderService.search(query),
      _localGeocoderService.search(query),
    ];
    final results = await Future.wait(futures).catchError(
      (error, stackTrace) => print(error),
    );
    return results.fold<List<GeocodeResult>>([], (fold, results) => fold..addAll(results));
  }
}
