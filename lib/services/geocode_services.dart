import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
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
      return result.findElements('stedsnavn').map((node) => _toResult(node)).toList();
    } else
      throw 'GET $request failed with ${response.statusCode} ${response.reasonPhrase}';
  }

  GeocodeResult _toResult(xml.XmlElement node) {
    final point = Point.now(
      double.tryParse(node.findElements('nord')?.first?.text) ?? 0.0,
      double.tryParse(node.findElements('aust')?.first?.text) ?? 0.0,
    );
    return GeocodeResult(
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
        title: title,
        icon: icon,
        type: type,
      );
    } else
      throw 'GET $request failed with ${response.statusCode} ${response.reasonPhrase}';
  }

  List _toResults(
    Response response, {
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
            .map((feature) => _toResult(feature, title: title, icon: icon, type: type))
            .toList()
        : [];
    return addresses;
  }

  GeocodeResult _toResult(
    feature, {
    String title,
    IconData icon,
    GeocodeType type,
    int radius = 20,
  }) {
    final coords = feature['geometry']['coordinates'];
    final point = Point.now(
      coords[1] ?? 0.0,
      coords[0] ?? 0.0,
    );
    return GeocodeResult(
      icon: icon ?? Icons.home,
      title: title ?? feature['properties']['name'] as String,
      address: [
        feature['properties']['locality'] as String,
        feature['properties']['county'] as String,
      ].join(', '),
      position: toUTM(point),
      latitude: point.lat,
      longitude: point.lon,
      type: type ?? GeocodeType.Place,
      source: name,
    );
  }
}

/// Search for [GeocodeType.Object] instances in local data providers
class ObjectGeocoderService with GeocodeSearchQuery implements GeocodeService {
  final bool withRetired;
  final AddressGeocoderService service;
  final BlocProviderController controller;

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
      ..addAll(_findPOI(match))
      ..addAll(_findUnits(match))
      ..addAll(_findPersonnel(match))
      ..addAll(_findDevices(match));
    return Future.value(results);
  }

  Iterable<AddressLookup> _findPOI(RegExp match) {
    final results = <AddressLookup>[];
    final incident = controller.bloc<IncidentBloc>().selected;
    if (incident != null) {
      // Search for matches in incident
      if (_prepare(incident.searchable).contains(match)) {
        var matches = [
          AddressLookup(
            point: incident.ipp?.point,
            title: "${incident.name} > IPP",
            icon: Icons.location_on,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ),
          AddressLookup(
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

  Iterable<AddressLookup> _findUnits(RegExp match) => controller
      .bloc<UnitBloc>()
      .units
      .values
      .where((unit) => withRetired || unit.status != UnitStatus.Retired)
      .where((unit) =>
          // Search in unit
          _prepare(unit.searchable).contains(match) ||
          // Search in devices tracked with this unit
          controller
              .bloc<TrackingBloc>()
              .tracking[unit.tracking]
              .devices
              .any((id) => _prepare(controller.bloc<DeviceBloc>().devices[id]).contains(match)))
      .where((unit) => controller.bloc<TrackingBloc>().tracking[unit.tracking].point != null)
      .map((unit) => AddressLookup(
            point: controller.bloc<TrackingBloc>().tracking[unit.tracking].point,
            icon: Icons.group,
            title: unit.name,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  Iterable<AddressLookup> _findPersonnel(RegExp match) => controller
      .bloc<PersonnelBloc>()
      .personnel
      .values
      .where((p) => withRetired || p.status != PersonnelStatus.Retired)
      .where((p) =>
          // Search in personnel
          _prepare(p.searchable).contains(match) ||
          // Search in devices tracked with this personnel
          controller
              .bloc<TrackingBloc>()
              .tracking[p.tracking]
              .devices
              .any((id) => _prepare(controller.bloc<DeviceBloc>().devices[id]).contains(match)))
      .where((p) => controller.bloc<TrackingBloc>().tracking[p.tracking].point != null)
      .map((p) => AddressLookup(
            point: controller.bloc<TrackingBloc>().tracking[p.tracking].point,
            title: p.name,
            icon: Icons.person,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  Iterable<AddressLookup> _findDevices(RegExp match) => controller
      .bloc<DeviceBloc>()
      .devices
      .values
      .where((p) => _prepare(p).contains(match))
      .where((p) => p.position != null)
      .map((p) => AddressLookup(
            point: p.position,
            title: p.name,
            icon: Icons.person,
            type: GeocodeType.Object,
            service: service,
            source: name,
          ));

  String _prepare(Object object) => "$object".replaceAll(RegExp(r'\s*'), '').toLowerCase();
}

class LocalGeocoderService with GeocodeSearchQuery implements GeocodeService {
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
      return _toSearchResults(results);
    } on Exception {
      return [];
    }
  }

  List<GeocodeResult> _toSearchResults(List<Address> addresses) => addresses
      .map(
        (address) => GeocodeResult(
          icon: Icons.home,
          title: "${address.thoroughfare ?? address.featureName} ${address.subThoroughfare ?? ''}",
          address: _toAddress(address),
          position: toUTM(Point.now(
            address.coordinates.latitude,
            address.coordinates.longitude,
          )),
          latitude: address.coordinates.latitude,
          longitude: address.coordinates.longitude,
          type: GeocodeType.Object,
          source: name,
        ),
      )
      .toList();

  static String _toAddress(Address address) => [
        [
          address.postalCode,
          address.locality,
        ].where((test) => test?.isNotEmpty == true).join(' '),
        address.adminArea,
        address.countryName,
      ].where((test) => test?.isNotEmpty == true).join(", ").trim();
}

enum GeocodeType { Place, Address, Object }

class GeocodeResult extends Equatable {
  final String title;
  final IconData icon;
  final String address;
  final String position;
  final double longitude;
  final double latitude;
  final GeocodeType type;
  final String source;

  GeocodeResult({
    @required this.title,
    @required this.icon,
    @required this.longitude,
    @required this.latitude,
    @required this.position,
    @required this.type,
    this.address,
    this.source,
  }) : super([
          title,
          icon,
          address,
          position,
          longitude,
          latitude,
          type,
          source,
        ]);

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
    String source,
  }) : super(
          icon: icon,
          title: title,
          position: toUTM(point),
          latitude: point.lat,
          longitude: point.lon,
          type: type,
          source: source,
        );

  Future<GeocodeResult> get search async => _lookup();

  Future<GeocodeResult> _lookup() async {
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
            icon: icon,
            title: "$title",
            address: closest.address,
            position: toUTM(point),
            latitude: point.lat,
            longitude: point.lon,
            type: type,
            source: source,
          );
  }
}
