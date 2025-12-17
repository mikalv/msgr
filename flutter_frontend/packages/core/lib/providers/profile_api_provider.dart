import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/services/api/profile_api.dart';

/// Profile API provider for dependency injection
final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi();
});
