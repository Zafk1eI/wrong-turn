import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../data/services/places_service.dart';
import '../../data/services/location_service.dart';
import '../../data/models/place.dart' as map_place;
import '../../../route_planner/presentation/widgets/route_planner_bottom_sheet.dart' show RoutePlannerBottomSheet, PointType;
import '../../../route_planner/data/services/routing_service.dart';
import '../../../../core/models/route_models.dart' show TravelMode, RouteInfo;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  final RoutingService _routingService = RoutingService();
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final TextEditingController _searchController = TextEditingController();
  map_place.Place? _selectedPlace;
  bool _isTopographicLayer = false;
  List<List<LatLng>>? _routePoints;
  List<RouteInfo>? _routes;
  int _selectedRouteIndex = 0;
  bool _isSelectingStartPoint = false;
  bool _isSelectingEndPoint = false;
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation;
  bool _isFollowingUser = false;
  StreamSubscription<LatLng>? _locationSubscription;
  bool _isLocationPermissionGranted = false;
  bool _isStartPointGPS = false;

  static const String _standardLayer = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _topographicLayer = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  RouteInfo? get selectedRoute => _routes?.isNotEmpty == true ? _routes![_selectedRouteIndex] : null;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleLocationPermission() async {
    final hasPermission = await LocationService.checkPermission();
    setState(() => _isLocationPermissionGranted = hasPermission);
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Для работы приложения необходим доступ к геолокации'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (!_isFollowingUser) {
      if (!_isLocationPermissionGranted) {
        await _handleLocationPermission();
        if (!_isLocationPermissionGranted) return;
      }

      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Не удалось получить текущее местоположение'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      setState(() {
        _currentLocation = location;
        _isFollowingUser = true;
      });

      _locationSubscription = LocationService.getLocationStream().listen(
        (location) {
          setState(() => _currentLocation = location);
          if (_startPoint != null && _endPoint != null && _isStartPointGPS) {
            _updateRouteWithCurrentLocation();
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Ошибка при отслеживании местоположения'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
      );
    } else {
      _locationSubscription?.cancel();
      setState(() {
        _isFollowingUser = false;
        _currentLocation = null;
      });
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Включите GPS для определения местоположения'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _updateRouteWithCurrentLocation() async {
    if (_currentLocation != null && _endPoint != null) {
      final routeResponse = await _routingService.getRoute(
        _currentLocation!,
        _endPoint!,
        _routes?.first.travelMode ?? TravelMode.driving,
      );
      setState(() {
        _routePoints = routeResponse.routes.map((route) => route.points).toList();
        _routes = [routeResponse.selectedRoute, ...routeResponse.routes.where((r) => r.isAlternative)];
        _startPoint = _currentLocation;
        _selectedRouteIndex = 0;
      });
    }
  }

  Future<void> _useCurrentLocationAsStart() async {
    if (!_isLocationPermissionGranted) {
      await _handleLocationPermission();
      if (!_isLocationPermissionGranted) return;
    }

    final location = await LocationService.getCurrentLocation();
    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось получить текущее местоположение'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    setState(() {
      _startPoint = location;
      _currentLocation = location;
      _isFollowingUser = true;
      _updateMarkers();
    });

    _locationSubscription?.cancel();
    _locationSubscription = LocationService.getLocationStream().listen(
      (location) {
        setState(() => _currentLocation = location);
        if (_endPoint != null) {
          _updateRouteWithCurrentLocation();
        }
      },
    );
  }

  void _handleRoutePlanned(LatLng start, LatLng end, TravelMode mode) async {
    setState(() {
      if (start == _currentLocation) {
        _isStartPointGPS = true;
      } else {
        _isStartPointGPS = false;
        _startPoint = start;
      }
      _endPoint = end;
    });

    final routeResponse = await _routingService.getRoute(start, end, mode);
    if (!mounted) return;

    setState(() {
      _routePoints = routeResponse.routes.map((route) => route.points).toList();
      _routes = [routeResponse.selectedRoute, ...routeResponse.routes.where((r) => r.isAlternative)];
      _selectedRouteIndex = 0;
      _selectedPlace = null;
      _searchController.clear();
      _updateMarkers();
    });

    if (_routePoints != null && _routePoints!.isNotEmpty) {
      final allPoints = _routePoints!.expand((points) => points).toList();
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
      );
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedPlace = null;
      _markers.clear();
      _searchController.clear();
      _routePoints = null;
      _routes = null;
      _selectedRouteIndex = 0;
      _startPoint = null;
      _endPoint = null;
    });
  }

  void _hideInfo() {
    setState(() {
      _selectedPlace = null;
      _markers.clear();
      _searchController.clear();
    });
  }

  void _toggleMapLayer() {
    setState(() {
      _isTopographicLayer = !_isTopographicLayer;
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_isSelectingStartPoint) {
      setState(() {
        _startPoint = point;
        _isStartPointGPS = false;
        _updateMarkers();
      });
      _isSelectingStartPoint = false;
      _showRoutePlannerBottomSheet();
    } else if (_isSelectingEndPoint) {
      setState(() {
        _endPoint = point;
        _updateMarkers();
      });
      _isSelectingEndPoint = false;
      _showRoutePlannerBottomSheet();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      if (_startPoint != null && !_isStartPointGPS) {
        _markers.add(
          Marker(
            point: _startPoint!,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              color: Colors.green,
              size: 40,
            ),
          ),
        );
      }
      if (_endPoint != null) {
        _markers.add(
          Marker(
            point: _endPoint!,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        );
      }
    });
  }

  void _handleMapPointSelect(PointType type) {
    setState(() {
      _isSelectingStartPoint = type == PointType.start;
      _isSelectingEndPoint = type == PointType.end;
    });
  }

  void _showRoutePlannerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RoutePlannerBottomSheet(
          onRoutePlanned: _handleRoutePlanned,
          onMarkerPlaced: (location) {
            if (_isSelectingStartPoint) {
              setState(() {
                _startPoint = location;
                _isStartPointGPS = false;
                _updateMarkers();
              });
              _isSelectingStartPoint = false;
            } else if (_isSelectingEndPoint) {
              setState(() {
                _endPoint = location;
                _updateMarkers();
              });
              _isSelectingEndPoint = false;
            }
          },
          onMapPointSelect: _handleMapPointSelect,
          initialStartPoint: _isStartPointGPS ? _currentLocation : _startPoint,
          initialEndPoint: _endPoint,
          currentLocation: _currentLocation,
          isLocationEnabled: _isFollowingUser,
          isStartPointGPS: _isStartPointGPS,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(55.7558, 37.6173), // Москва
              initialZoom: 10,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: _isTopographicLayer ? _topographicLayer : _standardLayer,
                userAgentPackageName: 'com.example.wrong_turn',
              ),
              if (_routePoints != null)
                PolylineLayer(
                  polylines: [
                    // Основной маршрут (выбранный)
                    Polyline(
                      points: _routePoints![_selectedRouteIndex],
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                    // Альтернативные маршруты
                    ..._routePoints!.asMap().entries
                        .where((entry) => entry.key != _selectedRouteIndex)
                        .map((entry) => Polyline(
                          points: entry.value,
                          color: Colors.blue.withOpacity(0.5),
                          strokeWidth: 3,
                          isDotted: true,
                        )),
                  ],
                ),
              MarkerLayer(markers: [
                ..._markers,
                if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              onPressed: _toggleLocationTracking,
              tooltip: _isFollowingUser ? 'Отключить GPS' : 'Включить GPS',
              elevation: 3,
              backgroundColor: _isFollowingUser ? Colors.blue : Colors.black87,
              foregroundColor: Colors.white,
              child: Icon(
                _isFollowingUser ? Icons.location_on : Icons.location_off,
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              onPressed: _centerOnCurrentLocation,
              tooltip: 'Показать моё местоположение',
              elevation: 3,
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton(
              onPressed: _toggleMapLayer,
              tooltip: _isTopographicLayer ? 'Стандартная карта' : 'Топографическая карта',
              elevation: 3,
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              child: Icon(
                _isTopographicLayer ? Icons.map : Icons.terrain,
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TypeAheadField<map_place.Place>(
                    textFieldConfiguration: TextFieldConfiguration(
                  controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск места...',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSelection,
                                style: IconButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            )
                          : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    suggestionsBoxDecoration: SuggestionsBoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      elevation: 4,
                      color: Theme.of(context).colorScheme.surface,
                      constraints: const BoxConstraints(maxHeight: 300),
                    ),
                  suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) return [];
                    final places = await _placesService.searchPlaces(pattern);
                      if (places.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('По вашему запросу ничего не найдено'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                    return places;
                  },
                    itemBuilder: (context, map_place.Place suggestion) {
                    return ListTile(
                        leading: Icon(
                          suggestion.typeIcon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          suggestion.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              'Тип: ${suggestion.localizedType}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Координаты: ${suggestion.displayCoordinates}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                    onSuggestionSelected: (map_place.Place suggestion) {
                    setState(() {
                      _selectedPlace = suggestion;
                      _markers.clear();
                      _markers.add(
                        Marker(
                          point: suggestion.location,
                          width: 40,
                          height: 40,
                          child: Icon(
                            suggestion.typeIcon,
                              color: Theme.of(context).colorScheme.primary,
                            size: 40,
                          ),
                        ),
                      );
                    });
                    
                    _mapController.move(suggestion.location, 15);
                    _searchController.text = suggestion.name;
                  },
                    noItemsFoundBuilder: (context) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Ничего не найдено',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_selectedPlace != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPlace!.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _hideInfo,
                              style: IconButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Тип: ${_selectedPlace!.localizedType}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          'Координаты: ${_selectedPlace!.displayCoordinates}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedPlace!.poiInfo,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                if (selectedRoute != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Информация о маршруте',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSelection,
                              style: IconButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Расстояние',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  selectedRoute?.distance ?? "",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Время',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  selectedRoute?.duration ?? "",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () {
                _isSelectingStartPoint = false;
                _isSelectingEndPoint = false;
                _showRoutePlannerBottomSheet();
              },
              icon: const Icon(
                Icons.directions,
                color: Colors.white,
              ),
              label: const Text(
                'Маршрут',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.green,
              elevation: 3,
            ),
          ),
          if (_routes != null && _routes!.length > 1)
            Positioned(
              left: 16,
              bottom: 80,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          if (_routePoints == null || _routePoints!.isEmpty || _routes?.isEmpty == true) return;
                          setState(() {
                            _selectedRouteIndex = (_selectedRouteIndex - 1 + _routes!.length) % _routes!.length;
                          });
                        },
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 120),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Маршрут ${_selectedRouteIndex + 1}/${_routes?.length ?? 0}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${selectedRoute?.distance ?? ""} • ${selectedRoute?.duration ?? ""}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () {
                          if (_routePoints == null || _routePoints!.isEmpty || _routes?.isEmpty == true) return;
                          setState(() {
                            _selectedRouteIndex = (_selectedRouteIndex + 1) % _routes!.length;
                          });
                        },
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }
} 