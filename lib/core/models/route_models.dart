import 'package:latlong2/latlong.dart';

enum TravelMode {
  walking,
  driving,
  cycling,
}

class RouteInfo {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final bool isAlternative;
  final int? index;

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    this.isAlternative = false,
    this.index,
  });
}

class RouteResponse {
  final List<RouteInfo> routes;
  final RouteInfo selectedRoute;

  RouteResponse({
    required this.routes,
    required this.selectedRoute,
  });
} 