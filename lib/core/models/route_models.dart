import 'package:latlong2/latlong.dart';

enum TravelMode {
  driving,
  walking,
  cycling,
}

class RouteInfo {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final bool isAlternative;
  final int? index;
  final TravelMode travelMode;

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    this.isAlternative = false,
    this.index,
    required this.travelMode,
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