import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Service for getting the user's current location with permission handling.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  /// Get current position. Requests permission if needed.
  /// Returns null if permission denied or location unavailable.
  Future<LocationResult?> getCurrentLocation() async {
    if (kIsWeb) return null; // Web location not supported yet

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // Check/request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // Get position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Try reverse geocoding for a label
      String? label;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.street != null && p.street!.isNotEmpty) p.street!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ];
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {
        // Geocoding failed — use coordinates
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }
}

class LocationResult {
  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  /// Build content map for sending as a message.
  Map<String, dynamic> toContentMap() => {
    'type': 'location',
    'text': label ?? '$latitude, $longitude',
    'lat': latitude,
    'lng': longitude,
    'label': label ?? '$latitude, $longitude',
  };
}
