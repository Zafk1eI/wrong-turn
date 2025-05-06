import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Проверяет и запрашивает разрешения на использование геолокации
  static Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем, включены ли сервисы геолокации
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Если сервисы геолокации выключены, запрашиваем их включение
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return false;
      }
    }

    // Проверяем разрешения
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Если разрешения отклонены, запрашиваем их
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Если разрешения отклонены навсегда, предлагаем перейти в настройки
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /// Получает текущее местоположение пользователя
  static Future<LatLng?> getCurrentLocation() async {
    try {
      if (!await checkPermission()) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  /// Возвращает поток обновлений местоположения
  static Stream<LatLng> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Минимальное расстояние (в метрах) для обновления
      ),
    ).map((Position position) => LatLng(position.latitude, position.longitude));
  }
} 