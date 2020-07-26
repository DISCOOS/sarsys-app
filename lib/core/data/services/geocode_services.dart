import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/core/controllers/app_controller.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:xml/xml.dart' as xml;

import 'package:geocoder/geocoder.dart';

abstract class GeocodeService {
  final Client client;
  final String url;
  final String name;

  GeocodeService(
    this.client, {
    @required this.url,
    @required this.name,
  });
}

mixin GeocodeSearchQuery implements GeocodeService {
  Future<List<GeocodeResult>> search(String query);
}

mixin GeocodeSearchPoint implements GeocodeService {
  Future<List<GeocodeResult>> lookup(
    Point point, {
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  });
}

/// Search for [GeocodeType.Address] matches
class PlaceGeocoderService with GeocodeSearchQuery implements GeocodeService {
  final _SSRService _geocoder;

  @override
  Client get client => _geocoder.client;

  @override
  String get name => _geocoder.name;

  @override
  String get url => _geocoder.url;

  PlaceGeocoderService(Client client, {int maxCount = 5})
      : _geocoder = _SSRService(
          client,
          maxCount: maxCount,
          name: "Steder i Norge",
        );

  Future<List<GeocodeResult>> search(String query) async {
    return _geocoder.search(query);
  }
}

/// Implements [GeocodeType.Place] searches on 'Sentralt stedsregister' (SSR),
/// See https://kartverket.no/data/brukerveiledning-for-stedsnavnsok
class _SSRService extends GeocodeService with GeocodeSearchQuery {
  static const URL = 'https://ws.geonorge.no/SKWS3Index/ssr/sok';

  final int maxCount;
  final bool exactFirst;

  _SSRService(
    Client client, {
    String name,
    this.maxCount = 5,
    this.exactFirst = true,
  }) : super(
          client,
          url: URL,
          name: name,
        );

  Future<List<GeocodeResult>> search(String query) async {
    final request = '$url?antPerSide=$maxCount&eksakteForst=$exactFirst&epsgKode=4326&json&navn=${query.trim()}*';
    final response = await client.get(Uri.encodeFull(request));
    if (response.statusCode == 200) {
      final doc = xml.parse(toUtf8(response.body));
      final result = doc.findAllElements('sokRes').first;
      final state = result.findAllElements('ok')?.first?.text;
      if (state == 'false') {
        throw 'Not found, ${doc.findAllElements('melding')?.first?.text}';
      }
      return result.findElements('stedsnavn').map((node) => _toResult(query, node)).toList();
    } else
      throw 'GET $request failed with ${response.statusCode} ${response.reasonPhrase}';
  }

  GeocodeResult _toResult(String query, xml.XmlElement node) {
    final point = Point.fromCoords(
      lat: double.tryParse(node.findElements('nord')?.first?.text) ?? 0.0,
      lon: double.tryParse(node.findElements('aust')?.first?.text) ?? 0.0,
    );
    return GeocodeResult(
      query: query,
      icon: Icons.place,
      title: [
        node.findElements('stedsnavn')?.first?.text,
        _prepareNamedType(node),
      ].join(', '),
      address: [
        node.findElements('kommunenavn')?.first?.text,
        node.findElements('fylkesnavn')?.first?.text,
      ].join(', '),
      position: toUTM(point),
      latitude: point.lat,
      longitude: point.lon,
      type: GeocodeType.Place,
      source: name,
    );
  }

  String _prepareNamedType(xml.XmlElement node) =>
      node.findElements('navnetype')?.first?.text?.replaceFirst("Adressenavn (veg/gate)", "vei/gate");

  String toUtf8(String text) {
    return utf8.decoder.convert(text.codeUnits);
  }
}

/// Search for [GeocodeType.Address] matches
class AddressGeocoderService with GeocodeSearchQuery, GeocodeSearchPoint implements GeocodeService {
  final _EnturGeocoderService _geocoder;

  @override
  Client get client => _geocoder.client;

  @override
  String get name => _geocoder.name;

  @override
  String get url => _geocoder.url;

  AddressGeocoderService(Client client, {int maxCount = 5})
      : _geocoder = _EnturGeocoderService(
          client,
          maxCount: maxCount,
          name: "Addresser i Norge",
        );

  Future<List<GeocodeResult>> search(String query) async {
    return await _geocoder.search(query);
  }

  @override
  Future<List<GeocodeResult>> lookup(Point point, {String title, IconData icon, GeocodeType type, int radius = 20}) {
    return _geocoder.lookup(point, title: title, icon: icon, type: type, radius: radius);
  }
}

/// Implements Entur Geocoder API, see https://developer.entur.org/pages-geocoder-intro
class _EnturGeocoderService extends GeocodeService with GeocodeSearchQuery, GeocodeSearchPoint {
  static const URL = 'https://api.entur.io/geocoder/v1';

  final int maxCount;
  final List<String> layers;

  _EnturGeocoderService(
    Client client, {
    String name,
    this.layers = const [],
    this.maxCount = 5,
  }) : super(
          client,
          url: URL,
          name: name,
        );

  Future<List<GeocodeResult>> search(String query) async => await _fetch(
        '$url/autocomplete?'
        'lang=no&size=$maxCount${layers.isNotEmpty ? "&${layers.join(',')}" : ''}&text=${query.trim()}',
      );

  @override
  Future<List<GeocodeResult>> lookup(
    Point point, {
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) async =>
      await _fetch(
        toUrl(point, radius),
        title: title,
        icon: icon,
        type: type,
      );

  String toUrl(Point point, int radius) {
    final uri = '$url/reverse?lang=no&$maxCount${layers.isNotEmpty ? "&${layers.join(',')}" : ''}';
    return '$uri&boundary.circle.radius=$radius&point.lat=${point.lat}&point.lon=${point.lon}';
  }

  Future<List> _fetch(
    String request, {
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) async {
    if (kDebugMode) print(request);
    final response = await client.get(
      Uri.encodeFull(request),
      headers: {
        // Comply with Entur strict rate-limiting policy
        'ET-Client-Name': 'discoos.org - sarsys',
      },
    );
    if (response.statusCode == 200) {
      return _toResults(
        response,
        query: request,
        title: title,
        icon: icon,
        type: type,
      );
    } else
      throw 'GET $request failed with ${response.statusCode} ${response.reasonPhrase}';
  }

  List _toResults(
    Response response, {
    String query,
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) {
    final Map<String, dynamic> body = json.decode(response.body);
    final addresses = body.containsKey('features')
        ? (body['features'] as List<dynamic>)
            .where((feature) => feature['geometry'] is Map<String, dynamic>)
            .where((feature) => feature['properties'] is Map<String, dynamic>)
            .map((feature) => _toResult(
                  feature,
                  query: query,
                  title: title,
                  icon: icon,
                  type: type,
                ))
            .toList()
        : [];
    return addresses;
  }

  GeocodeResult _toResult(
    feature, {
    String query,
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) {
    final coords = feature['geometry']['coordinates'];
    final point = Point.fromCoords(
      lat: coords[1] ?? 0.0,
      lon: coords[0] ?? 0.0,
    );
    return GeocodeResult(
      query: query,
      icon: icon ?? Icons.home,
      title: title ?? feature['properties']['name'] as String,
      address: [
        feature['properties']['postalcode'] as String,
        feature['properties']['locality'] as String,
      ].join(' '),
      position: toUTM(point),
      latitude: point.lat,
      longitude: point.lon,
      type: type ?? GeocodeType.Place,
      // In meters
      distance: (feature['properties']['distance'] ?? 0.0) * 1000,
      source: name,
    );
  }
}

/// Search for [GeocodeType.Object] instances in local data providers
class ObjectGeocoderService with GeocodeSearchQuery implements GeocodeService {
  final bool withRetired;
  final AddressGeocoderService service;
  final AppController controller;

  @override
  Client get client => service.client;

  @override
  String get url => "local";

  @override
  String get name => "Objekter";

  ObjectGeocoderService(
    this.service,
    this.controller,
    this.withRetired,
  );

  @override
  Future<List<GeocodeResult>> search(String query) {
    final results = <GeocodeResult>[];
    final match = RegExp("${_prepare(query)}");
    results
      ..addAll(_findPOI(match, query))
      ..addAll(_findUnits(match, query))
      ..addAll(_findPersonnel(match, query))
      ..addAll(_findDevices(match, query));
    return Future.value(results);
  }

  Iterable<AddressLookup> _findPOI(RegExp match, String query) {
    final results = <AddressLookup>[];
    final incident = controller.bloc<OperationBloc>().selected;
    if (incident != null) {
      // Search for matches in incident
      if (_prepare(incident.searchable).contains(match)) {
        var matches = [
          AddressLookup(
            query: query,
            point: incident.ipp?.point,
            title: "${incident.name} > IPP",
            icon: Icons.location_on,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ),
          AddressLookup(
            query: query,
            point: incident.meetup?.point,
            title: "${incident.name} > Oppmøte",
            icon: Icons.location_on,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ),
        ];
        var positions = matches.where((test) => _prepare(test).contains(match));
        if ((positions).isNotEmpty) {
          results.addAll(positions);
        } else {
          results.addAll(matches);
        }
      }
    }
    return results;
  }

  Iterable<AddressLookup> _findUnits(RegExp match, String query) => controller
      .bloc<UnitBloc>()
      .units
      .values
      .where((unit) => withRetired || unit.status != UnitStatus.retired)
      .where((unit) =>
          // Search in unit
          _prepare(unit.searchable).contains(match) ||
          // Search in devices tracked with this unit
          controller
              .bloc<TrackingBloc>()
              .devices(unit.tracking.uuid)
              .any((id) => _prepare(controller.bloc<DeviceBloc>().devices[id]).contains(match)))
      .map((unit) => AddressLookup(
            query: query,
            point: controller.bloc<TrackingBloc>().trackings[unit.tracking.uuid].position?.geometry,
            icon: Icons.group,
            title: unit.name,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  Iterable<AddressLookup> _findPersonnel(RegExp match, String query) => controller
      .bloc<PersonnelBloc>()
      .repo
      .map
      .values
      .where((p) => withRetired || p.status != PersonnelStatus.retired)
      .where((p) =>
          // Search in personnel
          _prepare(p.searchable).contains(match) ||
          // Search in devices tracked with this personnel
          controller
              .bloc<TrackingBloc>()
              .devices(p.tracking.uuid)
              .any((id) => _prepare(controller.bloc<DeviceBloc>().devices[id]).contains(match)))
      .map((p) => AddressLookup(
            query: query,
            point: controller.bloc<TrackingBloc>().find(p).firstOrNull?.position?.geometry,
            title: p.name,
            icon: Icons.person,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  Iterable<AddressLookup> _findDevices(RegExp match, String query) =>
      controller.bloc<DeviceBloc>().devices.values.where((p) => _prepare(p).contains(match)).map((p) => AddressLookup(
            query: query,
            point: p.position?.geometry,
            title: p.name,
            icon: Icons.person,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  String _prepare(Object object) => "$object".replaceAll(RegExp(r'\s*'), '').toLowerCase();
}

class LocalGeocoderService with GeocodeSearchQuery implements GeocodeService, GeocodeSearchPoint {
  @override
  Client get client => null;

  @override
  String get name => "${Platform.isAndroid ? 'Android' : 'iOS'} søk";

  @override
  String get url => 'local';

  @override
  Future<List<GeocodeResult>> search(String query) async {
    try {
      var results = await Geocoder.local.findAddressesFromQuery(query);
      return _toSearchResults(results, query: query);
    } on Exception {
      return [];
    }
  }

  @override
  Future<List<GeocodeResult>> lookup(
    Point point, {
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) async {
    try {
      if (point == null) {
        return [
          GeocodeResult(
            query: '$point',
            icon: icon,
            source: name,
            title: title,
            latitude: null,
            longitude: null,
            address: "Ingen",
            position: "Ingen",
            type: type ?? GeocodeType.Object,
          )
        ];
      }

      var results = await Geocoder.local.findAddressesFromCoordinates(Coordinates(
        point.lat,
        point.lon,
      ));
      return _toSearchResults(
        results,
        query: '$point',
        title: title,
        icon: icon,
        type: type,
        radius: radius,
      );
    } on Exception {
      return [];
    }
  }

  List<GeocodeResult> _toSearchResults(
    List<Address> addresses, {
    @required String query,
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) =>
      addresses
          .map(
            (address) => GeocodeResult(
              query: query,
              icon: icon,
              title: title ?? "${address.thoroughfare ?? address.featureName} ${address.subThoroughfare ?? ''}",
              address: address.addressLine,
              position: toUTM(Point.fromCoords(
                lat: address.coordinates.latitude,
                lon: address.coordinates.longitude,
              )),
              latitude: address.coordinates.latitude,
              longitude: address.coordinates.longitude,
              type: type ?? GeocodeType.Object,
              source: name,
            ),
          )
          .toList();
}

enum GeocodeType { Place, Address, Object, Coordinates }

class GeocodeResult extends Equatable {
  final String title;
  final IconData icon;
  final String address;
  final String position;
  final double distance;
  final double longitude;
  final double latitude;
  final GeocodeType type;
  final String source;
  final String query;

  GeocodeResult({
    @required this.title,
    @required this.icon,
    @required this.longitude,
    @required this.latitude,
    @required this.position,
    @required this.type,
    @required this.query,
    this.source,
    this.address,
    this.distance,
  }) : super([
          title,
          icon,
          address,
          position,
          longitude,
          latitude,
          type,
          source,
          distance,
        ]);

  bool get hasLocation => latitude != null && longitude != null;

  @override
  String toString() {
    return '_SearchResult{title: $title, address: $address, position: $position, '
        'longitude: $longitude, latitude: $latitude}';
  }
}

/// Used for deferred address lookup from [Point]
class AddressLookup extends GeocodeResult {
  final Point point;
  final GeocodeSearchPoint service;

  AddressLookup({
    @required this.point,
    @required String title,
    @required IconData icon,
    @required GeocodeType type,
    @required this.service,
    @required String query,
    String source,
  }) : super(
          icon: icon,
          query: query,
          title: title,
          position: toUTM(point),
          latitude: point?.lat,
          longitude: point?.lon,
          type: type,
          source: source,
        );

  Future<GeocodeResult> get search async => _lookup();

  Future<GeocodeResult> _lookup() async {
    if (point == null) {
      return GeocodeResult(
        query: query,
        icon: icon,
        title: title,
        address: 'Ingen addresse',
        position: toUTM(point, empty: 'Ingen posisjon'),
        latitude: null,
        longitude: null,
        type: type,
        source: source,
      );
    }

    GeocodeResult closest;
    double last = double.maxFinite;

    for (GeocodeResult result in await service.lookup(
      point,
      title: title,
      icon: icon,
      type: type,
    )) {
      if (closest == null) {
        closest = result;

        last = ProjMath.eucledianDistance(
          closest.latitude,
          closest.longitude,
          point.lat,
          point.lon,
        );
      } else {
        var next = ProjMath.eucledianDistance(
          closest.latitude,
          closest.longitude,
          result.latitude,
          result.longitude,
        );
        if (next < last) {
          closest = result;
          last = next;
        }
      }
    }

    return closest == null
        ? GeocodeResult(
            query: query,
            icon: icon,
            title: title,
            address: null,
            position: toUTM(point),
            latitude: point.lat,
            longitude: point.lon,
            type: type,
            source: source,
          )
        : GeocodeResult(
            query: query,
            icon: icon,
            title: "$title",
            address: closest.address,
            position: toUTM(point),
            latitude: point.lat,
            longitude: point.lon,
            distance: last,
            type: type,
            source: source,
          );
  }
}
