import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/place.dart';

class PlacesService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$_baseUrl?format=json&q=$query&limit=5&extratags=1&addressdetails=1');
    final response = await http.get(
      url,
      headers: {
        'Accept-Language': 'ru',
        'User-Agent': 'WrongTurnApp/1.0',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isEmpty) {
        return [];
      }
      return data.map((json) => Place.fromJson(json)).toList();
    }
    
    return [];
  }
} 