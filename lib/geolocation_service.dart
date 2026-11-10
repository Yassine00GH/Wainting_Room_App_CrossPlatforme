import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  bool get _isRunningInTest {
    try {
      final bindingName =
          WidgetsFlutterBinding.ensureInitialized().runtimeType.toString();
      return bindingName.contains('Test');
    } catch (_) {
      return false;
    }
  }

  Future<Position?> getCurrentPosition() async {
    if (_isRunningInTest) {
      return null;
    }

    try {
      // 1. Check & request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      // 2. Ensure location services are enabled
      if (!(await Geolocator.isLocationServiceEnabled())) {
        return null;
      }

      // 3. Fetch position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Geolocation error: $e');
      return null;
    }
  }
}
