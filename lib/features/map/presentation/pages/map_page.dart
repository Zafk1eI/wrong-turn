import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../data/services/places_service.dart';
import '../../data/models/place.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final PlacesService _placesService = PlacesService();
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final TextEditingController _searchController = TextEditingController();
  Place? _selectedPlace;
  bool _isTopographicLayer = false;

  static const String _standardLayer = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _topographicLayer = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  void _clearSelection() {
    setState(() {
      _selectedPlace = null;
      _markers.clear();
      _searchController.clear();
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
            ),
            children: [
              TileLayer(
                urlTemplate: _isTopographicLayer ? _topographicLayer : _standardLayer,
                userAgentPackageName: 'com.example.wrong_turn',
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
                TypeAheadField<Place>(
                  controller: _searchController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Поиск места...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSelection,
                            )
                          : null,
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    final places = await _placesService.searchPlaces(pattern);
                    if (places.isEmpty && pattern.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('По вашему запросу ничего не найдено'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    return places;
                  },
                  itemBuilder: (context, Place suggestion) {
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
                  onSelected: (Place suggestion) {
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
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _toggleMapLayer,
              tooltip: _isTopographicLayer ? 'Стандартная карта' : 'Топографическая карта',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              child: Icon(_isTopographicLayer ? Icons.map : Icons.terrain),
            ),
          ),
        ],
      ),
    );
  }
} 