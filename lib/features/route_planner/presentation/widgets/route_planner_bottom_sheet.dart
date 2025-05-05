import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import '../../../../core/models/route_models.dart';

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
  
  const RoutePlannerBottomSheet({
    Key? key,
    required this.onRoutePlanned,
    this.onMarkerPlaced,
    this.onMapPointSelect,
    this.initialStartPoint,
    this.initialEndPoint,
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

  @override
  void initState() {
    super.initState();
    _startPoint = widget.initialStartPoint;
    _endPoint = widget.initialEndPoint;
    
    // Если есть начальные точки, обновляем текстовые поля
    if (_startPoint != null) {
      _updateLocationText(_startPoint!, _startController);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            ElevatedButton(
              onPressed: _canBuildRoute() ? _handleRoutePlanning : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Проложить маршрут',
                style: TextStyle(fontSize: 16),
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
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
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
          textFieldConfiguration: TextFieldConfiguration(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              suffixIcon: IconButton(
                icon: const Icon(Icons.map),
                onPressed: () => _handleMapPointSelect(pointType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          suggestionsCallback: _getSuggestions,
          itemBuilder: (context, suggestion) {
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(suggestion.displayName),
            );
          },
          onSuggestionSelected: (suggestion) {
            controller.text = suggestion.displayName;
            final location = LatLng(suggestion.lat, suggestion.lon);
            onLocationSelected(location);
          },
          noItemsFoundBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Ничего не найдено'),
          ),
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
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canBuildRoute() {
    return _startPoint != null && _endPoint != null;
  }

  void _handleRoutePlanning() {
    if (_canBuildRoute()) {
      widget.onRoutePlanned(_startPoint!, _endPoint!, _selectedMode);
    }
  }
} 