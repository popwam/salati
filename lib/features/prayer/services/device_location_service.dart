import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationService {
  const DeviceLocationService();

  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  Future<String> getLocationLabelFromPosition(Position position) async {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      return 'موقعي الحالي';
    }

    final place = placemarks.first;

    final parts = [
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.country,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'موقعي الحالي';
    }

    return parts.first;
  }

  double distanceBetweenMeters({
    required double oldLatitude,
    required double oldLongitude,
    required double newLatitude,
    required double newLongitude,
  }) {
    return Geolocator.distanceBetween(
      oldLatitude,
      oldLongitude,
      newLatitude,
      newLongitude,
    );
  }
}
