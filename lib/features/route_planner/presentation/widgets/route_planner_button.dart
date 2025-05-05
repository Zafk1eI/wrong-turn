import 'package:flutter/material.dart';
import 'route_planner_bottom_sheet.dart';

class RoutePlannerButton extends StatelessWidget {
  final Function(LatLng, LatLng, TravelMode) onRoutePlanned;
  final Function(LatLng)? onMarkerPlaced;

  const RoutePlannerButton({
    Key? key,
    required this.onRoutePlanned,
    this.onMarkerPlaced,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showBottomSheet(context),
      icon: const Icon(Icons.directions),
      label: const Text('Маршрут'),
      backgroundColor: Theme.of(context).primaryColor,
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RoutePlannerBottomSheet(
          onRoutePlanned: onRoutePlanned,
          onMarkerPlaced: onMarkerPlaced,
        ),
      ),
    );
  }
} 