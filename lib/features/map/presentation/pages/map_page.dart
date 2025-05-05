import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../data/services/places_service.dart';
import '../../data/models/place.dart' as map_place;
import '../../../route_planner/presentation/widgets/route_planner_bottom_sheet.dart' show RoutePlannerBottomSheet, PointType;
import '../../../route_planner/data/services/routing_service.dart';
import '../../../../core/models/route_models.dart' show TravelMode, RouteInfo;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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

  static const String _standardLayer = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _topographicLayer = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  RouteInfo? get selectedRoute => _routes?.isNotEmpty == true ? _routes![_selectedRouteIndex] : null;

  void _handleRoutePlanned(LatLng start, LatLng end, TravelMode mode) async {
    final routeResponse = await _routingService.getRoute(start, end, mode);
    setState(() {
      _routePoints = routeResponse.routes.map((route) => route.points).toList();
      _routes = [routeResponse.selectedRoute, ...routeResponse.routes.where((r) => r.isAlternative)];
      _startPoint = start;
      _endPoint = end;
      _selectedRouteIndex = 0;
      _selectedPlace = null;
      _searchController.clear();
      _updateMarkers();
    });

    // Подстраиваем карту под маршрут
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
      if (_startPoint != null) {
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
          initialStartPoint: _startPoint,
          initialEndPoint: _endPoint,
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
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                TypeAheadField<map_place.Place>(
                  textFieldConfiguration: TextFieldConfiguration(
                  controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск места...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSelection,
                            )
                          : null,
                      ),
                  ),
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) return [];
                    final places = await _placesService.searchPlaces(pattern);
                    if (places.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('По вашему запросу ничего не найдено'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    return places;
                  },
                  itemBuilder: (context, map_place.Place suggestion) {
                    return ListTile(
                      leading: Icon(suggestion.typeIcon),
                      title: Text(suggestion.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Тип: ${suggestion.localizedType}'),
                          Text('Координаты: ${suggestion.displayCoordinates}'),
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
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      );
                    });
                    
                    _mapController.move(suggestion.location, 15);
                    _searchController.text = suggestion.name;
                  },
                  noItemsFoundBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Ничего не найдено'),
                  ),
                ),
                if (_selectedPlace != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _hideInfo,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Тип: ${_selectedPlace!.localizedType}'),
                        Text('Координаты: ${_selectedPlace!.displayCoordinates}'),
                        const SizedBox(height: 4),
                        Text(_selectedPlace!.poiInfo),
                      ],
                    ),
                  ),
                if (selectedRoute != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                            const Text(
                              'Информация о маршруте',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSelection,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Расстояние'),
                                Text(
                                  selectedRoute!.distance,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Время'),
                                Text(
                                  selectedRoute!.duration,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
            bottom: 80,
            child: FloatingActionButton(
              onPressed: _toggleMapLayer,
              tooltip: _isTopographicLayer ? 'Стандартная карта' : 'Топографическая карта',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              child: Icon(_isTopographicLayer ? Icons.map : Icons.terrain),
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
              icon: const Icon(Icons.directions),
              label: const Text('Маршрут'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
          if (_routes != null && _routes!.length > 1)
            Positioned(
              left: 16,
              bottom: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 20,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Маршрут ${_selectedRouteIndex + 1}/${_routes?.length ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedRoute?.distance ?? ""} • ${selectedRoute?.duration ?? ""}',
                            style: const TextStyle(fontSize: 12),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 