import 'dart:io';

/// Provides runtime configuration for the Snapchat Camera Kit integration.
class CameraKitEnvironment {
  CameraKitEnvironment._()
      : _default = _CameraKitValues(
          enabled:
              const bool.fromEnvironment('MSGR_CAMERA_KIT_ENABLED', defaultValue: false),
          applicationId: const String.fromEnvironment(
            'MSGR_CAMERA_KIT_APPLICATION_ID',
            defaultValue: '',
          ),
          apiToken: const String.fromEnvironment(
            'MSGR_CAMERA_KIT_API_TOKEN',
            defaultValue: '',
          ),
          lensGroupIds: _parseLensGroups(
            const String.fromEnvironment(
              'MSGR_CAMERA_KIT_LENS_GROUP_IDS',
              defaultValue: '',
            ),
          ),
        );

  /// Singleton instance that should be used across the app.
  static final CameraKitEnvironment instance = CameraKitEnvironment._();

  final _CameraKitValues _default;
  _CameraKitValues? _override;

  /// Whether the integration is explicitly enabled.
  bool get enabled => (_override ?? _default).enabled;

  /// Application identifier provided by Snapchat for Camera Kit (iOS only).
  String get applicationId => (_override ?? _default).applicationId;

  /// API token provided by Snapchat for Camera Kit.
  String get apiToken => (_override ?? _default).apiToken;

  /// Lens group identifiers that should be made available in the picker.
  List<String> get lensGroupIds => (_override ?? _default).lensGroupIds;

  /// True when the integration has enough configuration to be invoked.
  bool get isConfigured {
    if (!enabled) return false;
    if (apiToken.isEmpty) return false;
    if (lensGroupIds.isEmpty) return false;
    if (_isIOS && applicationId.isEmpty) return false;
    return true;
  }

  /// Allows changing configuration at runtime – primarily for tests or debug tools.
  void override({
    bool? enabled,
    String? applicationId,
    String? apiToken,
    List<String>? lensGroupIds,
  }) {
    final source = _override ?? _default;
    _override = source.copyWith(
      enabled: enabled,
      applicationId: applicationId,
      apiToken: apiToken,
      lensGroupIds: lensGroupIds,
    );
  }

  /// Removes any runtime overrides so subsequent reads use compile-time values.
  void clearOverride() {
    _override = null;
  }

  static List<String> _parseLensGroups(String value) {
    return value
        .split(',')
        .map((raw) => raw.trim())
        .where((element) => element.isNotEmpty)
        .toList(growable: false);
  }

  static bool get _isIOS => Platform.isIOS;
}

class _CameraKitValues {
  const _CameraKitValues({
    required this.enabled,
    required this.applicationId,
    required this.apiToken,
    required this.lensGroupIds,
  });

  final bool enabled;
  final String applicationId;
  final String apiToken;
  final List<String> lensGroupIds;

  _CameraKitValues copyWith({
    bool? enabled,
    String? applicationId,
    String? apiToken,
    List<String>? lensGroupIds,
  }) {
    return _CameraKitValues(
      enabled: enabled ?? this.enabled,
      applicationId: applicationId ?? this.applicationId,
      apiToken: apiToken ?? this.apiToken,
      lensGroupIds: lensGroupIds ?? this.lensGroupIds,
    );
  }
}
