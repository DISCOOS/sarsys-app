import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:xml/xml.dart' as xml;

class PlaceService {
  static const URL = 'https://ws.geonorge.no/SKWS3Index/ssr/sok?maxAnt=5&eksakteForst=true&epsgKode=4326&json&navn=';
  final Client client;
  PlaceService(this.client);

  Future<List<Placemark>> search(String query) async {
    final response = await client.get('$URL$query*');
    if (response.statusCode == 200) {
      final doc = xml.parse(toUtf8(response.body));
      final result = doc.findAllElements('sokRes').first;
      final state = result.findAllElements('ok')?.first?.text;
      if (state == 'false') {
        throw 'Not found, ${doc.findAllElements('melding')?.first?.text}';
      }
      final now = DateTime.now();
      final locale = Locale.cachedLocale;
      return result
          .findElements('stedsnavn')
          .map((node) => Placemark(
                name: node.findElements('stedsnavn')?.first?.text,
                isoCountryCode: locale.countryCode,
                country: 'Norge',
                thoroughfare: node.findElements('stedsnavn')?.first?.text,
                subThoroughfare: node.findElements('navnetype')?.first?.text,
                administrativeArea: node.findElements('fylkesnavn')?.first?.text,
                subAdministrativeArea: node.findElements('kommunenavn')?.first?.text,
                position: Position(
                  timestamp: now,
                  latitude: double.tryParse(node.findElements('nord')?.first?.text) ?? 0.0,
                  longitude: double.tryParse(node.findElements('aust')?.first?.text) ?? 0.0,
                  accuracy: 0.0,
                  altitude: 0.0,
                  heading: 0.0,
                  speed: 0.0,
                  speedAccuracy: 0.0,
                  mocked: false,
                ),
              ))
          .toList();
    } else
      throw 'Search failed, $response';
  }

  String toUtf8(String text) {
    return utf8.decoder.convert(text.codeUnits);
  }
}
