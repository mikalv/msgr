import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/services/api/profile_api.dart';

/// Profile API provider for dependency injection
final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi();
});
