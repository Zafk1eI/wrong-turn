import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'place_type_localization.dart';

class Place {
  final String name;
  final String address;
  final LatLng location;
  final String type;
  final Map<String, dynamic> extraTags;
  final String displayCoordinates;

  Place({
    required this.name,
    required this.address,
    required this.location,
    required this.type,
    required this.extraTags,
  }) : displayCoordinates = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

  factory Place.fromJson(Map<String, dynamic> json) {
    // Определяем тип места
    String displayType = '';
    
    // Проверяем различные поля для определения типа
    final type = json['type'] ?? '';
    final category = json['category'] ?? '';
    final class_ = json['class'] ?? '';
    final place = json['place'] ?? '';
    final adminLevel = json['admin_level'] ?? '';
    
    // Определяем наиболее подходящий тип для отображения
    if (type == 'administrative' || type.contains('boundary')) {
      if (adminLevel.isNotEmpty) {
        displayType = 'admin_level=$adminLevel';
      } else {
        displayType = 'administrative';
      }
    } else if (place.isNotEmpty) {
      displayType = 'place=$place';
    } else if (type.isNotEmpty && type != 'yes') {
      displayType = type;
    } else if (category.isNotEmpty) {
      displayType = category;
    } else if (class_.isNotEmpty) {
      displayType = class_;
    }

    return Place(
      name: json['display_name'] ?? '',
      address: json['display_name'] ?? '',
      location: LatLng(
        double.parse(json['lat'] ?? '0'),
        double.parse(json['lon'] ?? '0'),
      ),
      type: displayType.isEmpty ? 'unknown' : displayType,
      extraTags: Map<String, dynamic>.from(json['extratags'] ?? {}),
    );
  }

  String get localizedType {
    return PlaceTypeLocalization.getLocalizedType(type);
  }

  String get poiInfo {
    final List<String> info = [];
    
    if (extraTags.containsKey('opening_hours')) {
      info.add('Режим работы: ${extraTags['opening_hours']}');
    }
    if (extraTags.containsKey('phone')) {
      info.add('Телефон: ${extraTags['phone']}');
    }
    if (extraTags.containsKey('website')) {
      info.add('Сайт: ${extraTags['website']}');
    }
    
    return info.isEmpty ? 'Дополнительная информация отсутствует' : info.join('\n');
  }

  IconData get typeIcon {
    final lowerType = type.toLowerCase();
    
    if (lowerType.contains('admin') || lowerType.contains('boundary')) {
      return Icons.account_balance;
    }
    
    switch (type) {
      case 'city':
      case 'town':
        return Icons.location_city;
      case 'village':
      case 'hamlet':
        return Icons.home_work;
      case 'river':
      case 'water':
      case 'lake':
      case 'sea':
      case 'ocean':
        return Icons.water;
      case 'peak':
      case 'mountain':
        return Icons.landscape;
      case 'forest':
      case 'wood':
        return Icons.forest;
      case 'island':
        return Icons.terrain;
      case 'motorway':
      case 'trunk':
      case 'primary':
      case 'secondary':
      case 'tertiary':
      case 'residential':
        return Icons.add_road;
      case 'railway':
        return Icons.train;
      case 'aeroway':
        return Icons.flight;
      case 'building':
        return Icons.business;
      case 'amenity':
        return Icons.local_activity;
      case 'shop':
        return Icons.shopping_cart;
      case 'tourism':
        return Icons.tour;
      case 'leisure':
        return Icons.park;
      case 'historic':
        return Icons.account_balance;
      case 'military':
        return Icons.security;
      case 'office':
        return Icons.business_center;
      default:
        return Icons.place;
    }
  }
} 