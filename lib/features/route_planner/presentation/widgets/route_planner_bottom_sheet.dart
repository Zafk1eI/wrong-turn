import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import '../../../../core/models/route_models.dart';
import '../../../map/data/services/location_service.dart';

enum PointType {
  start,
  end,
}

class SearchPlace {
  final String displayName;
  final double lat;
  final double lon;

  SearchPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class RoutePlannerBottomSheet extends StatefulWidget {
  final Function(LatLng, LatLng, TravelMode) onRoutePlanned;
  final Function(LatLng)? onMarkerPlaced;
  final Function(PointType)? onMapPointSelect;
  final LatLng? initialStartPoint;
  final LatLng? initialEndPoint;
  final LatLng? currentLocation;
  final bool isLocationEnabled;
  final bool isStartPointGPS;
  
  const RoutePlannerBottomSheet({
    Key? key,
    required this.onRoutePlanned,
    this.onMarkerPlaced,
    this.onMapPointSelect,
    this.initialStartPoint,
    this.initialEndPoint,
    this.currentLocation,
    this.isLocationEnabled = false,
    this.isStartPointGPS = false,
  }) : super(key: key);

  @override
  State<RoutePlannerBottomSheet> createState() => _RoutePlannerBottomSheetState();
}

class _RoutePlannerBottomSheetState extends State<RoutePlannerBottomSheet> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  TravelMode _selectedMode = TravelMode.driving;
  LatLng? _startPoint;
  LatLng? _endPoint;
  bool _isStartPointGPS = false;

  @override
  void initState() {
    super.initState();
    _startPoint = widget.initialStartPoint;
    _endPoint = widget.initialEndPoint;
    _isStartPointGPS = widget.isStartPointGPS;
    
    if (_startPoint != null) {
      if (_isStartPointGPS) {
        _startController.text = 'Моё местоположение';
      } else {
        _updateLocationText(_startPoint!, _startController);
      }
    }
    if (_endPoint != null) {
      _updateLocationText(_endPoint!, _endController);
    }
  }

  Future<void> _updateLocationText(LatLng location, TextEditingController controller) async {
    try {
      final searchResult = await Nominatim.reverseSearch(
        lat: location.latitude,
        lon: location.longitude,
        addressDetails: true,
        nameDetails: true,
      );
      
      if (searchResult != null) {
        controller.text = searchResult.displayName;
      } else {
        controller.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      controller.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    }
  }

  Future<List<SearchPlace>> _getSuggestions(String query) async {
    if (query.length < 3) return [];

    try {
      final searchResult = await Nominatim.searchByName(
        query: query,
        limit: 5,
        addressDetails: true,
        extraTags: true,
        nameDetails: true,
      );

      return searchResult.map((place) => SearchPlace(
        displayName: place.displayName,
        lat: place.lat,
        lon: place.lon,
      )).toList();
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      return [];
    }
  }

  void _handleMapPointSelect(PointType type) {
    widget.onMapPointSelect?.call(type);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Выберите ${type == PointType.start ? "начальную" : "конечную"} точку на карте'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _useCurrentLocation() {
    if (!widget.isLocationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Включите GPS для использования текущего местоположения'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (widget.currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не удалось получить текущее местоположение'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _startPoint = widget.currentLocation;
      _isStartPointGPS = true;
      _startController.text = 'Моё местоположение';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            const SizedBox(height: 16),
            _buildLocationInput(
              controller: _startController,
              hint: 'Откуда',
              icon: Icons.my_location,
              onLocationSelected: (location) {
                setState(() => _startPoint = location);
                widget.onMarkerPlaced?.call(location);
              },
              pointType: PointType.start,
            ),
            const SizedBox(height: 12),
            _buildLocationInput(
              controller: _endController,
              hint: 'Куда',
              icon: Icons.location_on,
              onLocationSelected: (location) {
                setState(() => _endPoint = location);
                widget.onMarkerPlaced?.call(location);
              },
              pointType: PointType.end,
            ),
            const SizedBox(height: 24),
            _buildTravelModeSelector(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canBuildRoute() ? _handleRoutePlanning : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                backgroundColor: Colors.green,
              ),
              child: Text(
                'Проложить маршрут',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Function(LatLng) onLocationSelected,
    required PointType pointType,
  }) {
    return Column(
      children: [
        TypeAheadField<SearchPlace>(
          controller: controller,
          suggestionsCallback: _getSuggestions,
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
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
                  icon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pointType == PointType.start)
                      IconButton(
                        icon: Icon(
                          Icons.my_location,
                          color: widget.isLocationEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _useCurrentLocation,
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: () {
                        if (pointType == PointType.start) {
                          setState(() {
                            _isStartPointGPS = false;
                          });
                        }
                        _handleMapPointSelect(pointType);
                      },
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            );
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              leading: Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                suggestion.displayName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          },
          onSelected: (suggestion) {
            if (pointType == PointType.start) {
              setState(() {
                _isStartPointGPS = false;
              });
            }
            controller.text = suggestion.displayName;
            final location = LatLng(suggestion.lat, suggestion.lon);
            onLocationSelected(location);
          },
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ничего не найдено',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          decorationBuilder: (context, child) {
            return Material(
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              child: child,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTravelModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildModeOption(
          mode: TravelMode.walking,
          icon: Icons.directions_walk,
          label: 'Пешком',
        ),
        _buildModeOption(
          mode: TravelMode.driving,
          icon: Icons.directions_car,
          label: 'На машине',
        ),
        _buildModeOption(
          mode: TravelMode.cycling,
          icon: Icons.directions_bike,
          label: 'На велосипеде',
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required TravelMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? Colors.transparent : colorScheme.outline,
              width: isSelected ? 0 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canBuildRoute() {
    return (_startPoint != null || (_isStartPointGPS && widget.currentLocation != null)) && _endPoint != null;
  }

  void _handleRoutePlanning() {
    if (_canBuildRoute()) {
      final startPoint = _isStartPointGPS ? widget.currentLocation! : _startPoint!;
      widget.onRoutePlanned(startPoint, _endPoint!, _selectedMode);
    }
  }
} 