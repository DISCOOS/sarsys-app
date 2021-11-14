

import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/data/services/geocode_services.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

typedef ErrorCallback = void Function(String message);
typedef MatchCallback = void Function(LatLng? point);

class MapSearchField extends StatefulWidget {
  final double? zoom;
  final String? hintText;
  final ErrorCallback onError;
  final MatchCallback? onMatch;
  final VoidCallback? onCleared;
  final MapWidgetController? mapController;

  final Widget? prefixIcon;

  final bool withRetired;

  final bool withBorder;

  final double offset;

  const MapSearchField({
    Key? key,
    required this.onError,
    required this.mapController,
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

  LatLng? _match;
  MapSearchEngine? engine;
  OverlayEntry? _overlayEntry;
  Future<GeocodeResult?>? request;

  bool get hasFocus => _focusNode?.hasFocus ?? false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () {
        if (request == null) {
          request = _search(_controller.text);
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.mapController?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    engine = MapSearchEngine(
      Provider.of<Client>(context),
      Provider.of<AppController>(context),
      withRetired: widget.withRetired,
    );
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
                  style: TextStyle(height: 1.4),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintMaxLines: 1,
                    hintStyle: TextStyle(height: 1.4),
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
            color: theme.color!.withOpacity(0.4),
          );
  }

  /// Hide overlay with results if shown, clear content and unfocus textfield
  void clear() async {
    _match = null;
    _controller.clear();
    request = null;
    if (widget.onCleared != null) widget.onCleared!();
    FocusScope.of(context).requestFocus(FocusNode());
    setState(() {});
  }

  Future<GeocodeResult?>? _search(String query) {
    try {
      final request = showSearch<GeocodeResult?>(
        context: context,
        query: query,
        delegate: MapSearchDelegate(
          engine: engine,
          controller: widget.mapController,
        ),
      ).then((result) async {
        if (result?.hasLocation == true) {
          _goto(
            result!.title!,
            result.latitude!,
            result.longitude!,
          );
        } else {
          if (result?.hasLocation == false && widget.onError != null) {
            widget.onError('${result!.title} har ingen posisjon');
          }
          clear();
        }
        return result;
      });
      return request;
    } catch (error, stackTrace) {
      SarSysApp.reportCheckedError(error, stackTrace);
    }
    return null;
  }

  void _goto(String query, double lat, double lon) {
    _match = LatLng(lat, lon);
    if (!kReleaseMode) print("Goto: $_match");
    widget.mapController!.animatedMove(_match, widget.zoom ?? widget.mapController!.zoom, this);
    if (widget.onMatch != null) widget.onMatch!(_match);
    _controller.text = query;
    FocusScope.of(context).requestFocus(FocusNode());
  }
}

class MapSearchDelegate extends SearchDelegate<GeocodeResult?> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/map/recent";

  final LatLng? center;
  final MapSearchEngine? engine;
  final int defaultSuggestionCount = 2;
  final MapWidgetController? controller;

  late Debouncer<String> _debouncer;
  Completer<List<GeocodeResult>>? _results;

  final ValueNotifier<Set<String>?> _recent = ValueNotifier(null);

  MapSearchDelegate({
    required this.engine,
    required this.controller,
    this.center,
  }) {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final always = [
      'IPP',
      'Oppmøte',
    ];
    final recent = stored != null ? (Set.from(always)..addAll(json.decode(stored))) : always.toSet();
    _recent.value = recent.map((suggestion) => suggestion as String).toSet();
    _debouncer = Debouncer<String>(
      const Duration(milliseconds: 100),
      initialValue: '',
      onChanged: (query) async {
        if (_results != null && _results!.isCompleted != true) {
          _results!.complete(engine!.search(query));
        }
      },
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return query.isEmpty
        ? ValueListenableBuilder<Set<String>?>(
            valueListenable: _recent,
            builder: (BuildContext context, Set<String>? suggestions, Widget? child) {
              return _buildSuggestionList(
                context,
                suggestions
                        ?.where((suggestion) => suggestion.toLowerCase().startsWith(query.toLowerCase()))
                        ?.toList() ??
                    [],
              );
            },
          )
        : _buildResults(context, store: false);
  }

  ListView _buildSuggestionList(BuildContext context, List<String> suggestions) {
    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      itemBuilder: (context, index) => ListTile(
        leading: Icon(Icons.group),
        title: RichText(
          text: TextSpan(
            text: suggestions[index].substring(0, query.length),
            style: theme.textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(
                text: suggestions[index].substring(query.length),
                style: theme.textTheme.subtitle2,
              ),
            ],
          ),
        ),
        trailing: index >= defaultSuggestionCount
            ? IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _delete(context, suggestions, index),
              )
            : null,
        onTap: () {
          query = suggestions[index];
          showResults(context);
        },
      ),
      itemCount: suggestions.length,
    );
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = (recent.toSet() ?? []) as Set<String>?;
    buildSuggestions(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResults(context, store: true);
  }

  FutureBuilder<List<GeocodeResult>> _buildResults(BuildContext context, {bool store = false}) {
    if (store) {
      final recent = _recent.value!.toSet()..add(query);
      _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
      _recent.value = (recent.toSet() ?? []) as Set<String>?;
    }
    if (_results == null || _results!.isCompleted) {
      _results = Completer();
    }
    _debouncer.value = query;
    return FutureBuilder<List<GeocodeResult>>(
        future: _results!.future,
        initialData: [],
        builder: (context, snapshot) {
          final items = _buildItems(
            context,
            snapshot,
            center: center,
          );
          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            semanticChildCount: items.length,
            itemBuilder: (BuildContext context, int index) => items[index],
          );
        });
  }

  List<Widget> _buildItems(
    BuildContext context,
    AsyncSnapshot<List<GeocodeResult>> snapshot, {
    LatLng? center,
  }) {
    final results = snapshot.hasData ? snapshot.data! : [];
    return results.isNotEmpty
        ? results
            .map((result) => result is AddressLookup
                ? _buildListTileFromLookup(
                    result,
                    center: center,
                  )
                : _buildListTile(
                    context,
                    result,
                    center: center,
                  ))
            .take(10)
            .toList()
        : _buildNoResult(snapshot);
  }

  List<Widget> _buildNoResult(AsyncSnapshot snapshot) => [
        ListTile(
          title: Text(
            snapshot.connectionState == ConnectionState.waiting ? 'Søker' : 'Fant ingen treff',
          ),
          subtitle: Text(
            snapshot.connectionState == ConnectionState.waiting ? 'Vennligst vent...' : 'Endre søket og forsøk igjen',
          ),
        )
      ];

  Widget _buildListTileFromLookup(AddressLookup lookup, {LatLng? center}) {
    return FutureBuilder<GeocodeResult>(
      initialData: lookup,
      future: lookup.search,
      builder: (BuildContext context, AsyncSnapshot<GeocodeResult> snapshot) {
        return _buildListTile(
          context,
          snapshot.hasData ? snapshot.data! : lookup,
          center: center,
        );
      },
    );
  }

  ListTile _buildListTile(BuildContext context, GeocodeResult data, {LatLng? center}) {
    final backgroundColor = Theme.of(context).canvasColor;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(data.icon, size: 36.0),
        backgroundColor: backgroundColor,
      ),
      title: Text(_toTitle(data)),
      subtitle: Text(center == null ? _toLocation(data)! : data.address!),
      contentPadding: _toPadding(data),
      trailing: _toSource(data, context, center: center),
      onTap: () => close(context, data),
    );
  }

  String _toTitle(GeocodeResult data) => "${data.title ?? ''}".trim();

  double? _distance(GeocodeResult data, LatLng origo, {double? defaultValue}) => data.hasLocation && origo != null
      ? ProjMath.eucledianDistance(
          data.latitude!,
          data.longitude!,
          origo.latitude,
          origo.longitude,
        )
      : defaultValue;

  EdgeInsets _toPadding(GeocodeResult data) =>
      data.address == null ? EdgeInsets.only(left: 16.0, right: 16.0) : EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0);

  String? _toLocation(GeocodeResult data) {
    final positionOrDistance = data.distance ?? data.position;
    return data.address == null
        ? positionOrDistance as String?
        : [data.address, positionOrDistance].where((test) => test != null).join(", ");
  }

  Padding _toSource(GeocodeResult data, BuildContext context, {LatLng? center}) {
    final caption = Theme.of(context).textTheme.caption;
    final origo = center ?? controller!.center;
    final distance = formatDistance(data.distance ?? _distance(data, origo));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            data.source!,
            style: caption,
          ),
          Text(
            distance,
            style: caption,
          )
        ],
      ),
    );
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
    AppController controller, {
    bool? withRetired,
  })  : this._placeGeocoderService = PlaceGeocoderService(client),
        this._addressGeocoderService = AddressGeocoderService(client),
        this._objectGeocoderService = ObjectGeocoderService(
          AddressGeocoderService(client),
          controller,
          withRetired,
        ),
        this._localGeocoderService = LocalGeocoderService();

  Future<List<GeocodeResult>> search(String query) async {
    final coords = CoordinateFormat.toLatLng(query);
    if (coords?.isValidLatLng == true) {
      return lookup(Point.fromCoords(
        lat: coords!.x,
        lon: coords.y,
      ));
    }

    final futures = [
      _objectGeocoderService.search(query),
      _placeGeocoderService.search(query),
      _addressGeocoderService.search(query),
      _localGeocoderService.search(query),
    ];

    final results = await Future.wait(futures).catchError((error, stackTrace) {
      print(error);
    });
    return results.fold<List<GeocodeResult>>([], (fold, results) => fold..addAll(results));
  }

  Future<List<GeocodeResult>> lookup(Point point) async {
    final futures = [
      _addressGeocoderService.lookup(point),
      _localGeocoderService.lookup(point),
    ];
    final results = await Future.wait(futures).catchError((error, stackTrace) {
      print(error);
    });
    return results == null ? [] : results.fold<List<GeocodeResult>>([], (fold, results) => fold..addAll(results));
  }
}
