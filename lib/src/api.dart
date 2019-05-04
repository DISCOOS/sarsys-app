import 'package:http/http.dart' as http;
import 'dart:convert';

class Api {

  Future<Stream<Incident>> fetchIncidents() async {
    final String _url = 'https://sporing.rodekors.no/api/indcidents';

    // GET incident

    // Transform and map
  }
}


class Incident {
  final int id;

  Incident.fromJSON(Map<String, dynamic> jsonMap) :
        id = jsonMap['id'];


}