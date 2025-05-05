import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/models/route_models.dart';
import 'package:flutter/foundation.dart';

class RouteException implements Exception {
  final String message;
  final String? code;

  RouteException(this.message, {this.code});

  @override
  String toString() => 'RouteException: $message${code != null ? ' (Code: $code)' : ''}';
}

class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';
  Timer? _debounceTimer;
  Map<String, bool> _cancelRequests = {};

  // Средние скорости передвижения (км/ч)
  static const Map<TravelMode, double> _averageSpeeds = {
    TravelMode.walking: 5.0,  
    TravelMode.cycling: 15.0,
    TravelMode.driving: 60.0, 
  };

  String _getProfile(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.driving:
        return 'driving';
      case TravelMode.cycling:
        return 'cycling';
    }
  }

  // Рассчитываем реальное время в зависимости от типа передвижения
  String _formatDuration(double distanceKm, TravelMode mode) {
    final speed = _averageSpeeds[mode]!;
    final hours = distanceKm / speed;
    final minutes = (hours * 60).round();

    if (minutes < 1) {
      return 'менее 1 мин';
    } else if (minutes < 60) {
      return '$minutes мин';
    } else {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) {
        return '$h ч';
      }
      return '$h ч $m мин';
    }
  }

  Future<RouteResponse> getRouteWithDebounce(
    LatLng start,
    LatLng end,
    TravelMode mode, {
    Duration debounceDelay = const Duration(milliseconds: 500),
  }) {
    final completer = Completer<RouteResponse>();
    
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }

    _debounceTimer = Timer(debounceDelay, () async {
      try {
        final route = await getRoute(start, end, mode);
        if (!completer.isCompleted) {
          completer.complete(route);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  Future<RouteResponse> getRoute(LatLng start, LatLng end, TravelMode mode) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _cancelRequests[requestId] = false;

    try {
      final profile = _getProfile(mode);
      final url = Uri.parse(
        '$_baseUrl/$profile/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true&alternatives=3'
      );

      debugPrint('Requesting route with URL: ${url.toString()}');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw RouteException('Превышено время ожидания запроса'),
      );

      if (_cancelRequests[requestId] == true) {
        throw RouteException('Запрос был отменен');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('OSRM Response: ${response.body}');
        
        if (data['code'] != 'Ok') {
          throw RouteException(
            'Ошибка построения маршрута',
            code: data['code'],
          );
        }
        
        if (data['routes'] == null || data['routes'].isEmpty) {
          throw RouteException('Маршрут не найден');
        }

        final List<RouteInfo> routes = [];
        
        // Обрабатываем все маршруты, включая альтернативные
        for (var i = 0; i < data['routes'].length; i++) {
          final route = data['routes'][i];
          
          if (route['geometry'] == null || route['geometry']['coordinates'] == null) {
            continue; // Пропускаем некорректные маршруты
          }

          final coordinates = (route['geometry']['coordinates'] as List)
              .map((point) => LatLng(point[1] as double, point[0] as double))
              .toList();

          final distanceKm = (route['distance'] as num) / 1000;
          final duration = _formatDuration(distanceKm, mode);

          routes.add(RouteInfo(
            points: coordinates,
            distance: '${distanceKm.toStringAsFixed(1)} км',
            duration: duration,
            isAlternative: i > 0, // Первый маршрут основной, остальные альтернативные
            index: i,
          ));
        }

        if (routes.isEmpty) {
          throw RouteException('Не удалось обработать маршруты');
        }

        debugPrint('Found ${routes.length} routes:');
        for (var i = 0; i < routes.length; i++) {
          final route = routes[i];
          debugPrint('Route $i: ${route.distance}, ${route.duration}, ${route.points.length} points');
        }

        return RouteResponse(
          routes: routes,
          selectedRoute: routes.first,
        );
      } else {
        debugPrint('OSRM Error Response: ${response.body}');
        throw RouteException(
          'Ошибка сервера: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
    } on FormatException catch (e) {
      debugPrint('Format Error: $e');
      throw RouteException('Некорректный формат ответа от сервера');
    } catch (e) {
      debugPrint('General Error: $e');
      if (e is RouteException) rethrow;
      throw RouteException('Неизвестная ошибка: ${e.toString()}');
    } finally {
      _cancelRequests.remove(requestId);
    }
  }
} 