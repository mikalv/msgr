import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messngr/services/api/auth_api.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/contact_api.dart';
import 'package:messngr/services/api/profile_api.dart';

/// Auth API provider for dependency injection
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi();
});

/// Chat API provider for dependency injection
final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi();
});

/// Contact API provider for dependency injection
final contactApiProvider = Provider<ContactApi>((ref) {
  return ContactApi();
});

/// Bridge API provider for dependency injection
final bridgeApiProvider = Provider<BridgeApi>((ref) {
  return BridgeApi();
});

/// Profile API provider for dependency injection
final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi();
});
