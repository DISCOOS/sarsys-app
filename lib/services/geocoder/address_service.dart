import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';

class AddressService {
  static const URL =
      'https://api.entur.io/geocoder/v1/autocomplete?lang=no&size=5&layers=address&text=';
  final Client client;
  AddressService(this.client);

  Future<List<Placemark>> search(String query) async {
    if (kDebugMode) print('$URL$query');
    final response = await client.get('$URL$query');
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      final now = DateTime.now();
      final locale = Locale.cachedLocale;
      final addresses = body.containsKey('features')
          ? (body['features'] as List<dynamic>)
              .where((feature) => feature['geometry'] is Map<String, dynamic>)
              .where((feature) => feature['properties'] is Map<String, dynamic>)
              .map((feature) => Placemark(
                    name: feature['properties']['name'] as String,
                    isoCountryCode: locale.countryCode,
                    country: 'Norge',
                    thoroughfare: feature['properties']['name'] as String,
                    subThoroughfare: feature['properties']['layer'] as String,
                    administrativeArea:
                        feature['properties']['county'] as String,
                    subAdministrativeArea:
                        feature['properties']['locality'] as String,
                    position: _toPosition(now, feature),
                  ))
              .toList()
          : [];
      return addresses;
    } else
      throw 'Search failed, $response';
  }

  Position _toPosition(DateTime now, feature) {
    final coords = feature['geometry']['coordinates'];
    return Position(
      timestamp: now,
      latitude: coords[1] ?? 0.0,
      longitude: coords[0] ?? 0.0,
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      mocked: false,
    );
  }

  String toUtf8(String text) {
    return utf8.decoder.convert(text.codeUnits);
  }
}
