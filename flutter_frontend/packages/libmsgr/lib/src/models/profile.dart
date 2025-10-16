// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

enum ProfileMode { private, work, family, unknown }

extension ProfileModeX on ProfileMode {
  String get value {
    switch (this) {
      case ProfileMode.private:
        return 'private';
      case ProfileMode.work:
        return 'work';
      case ProfileMode.family:
        return 'family';
      case ProfileMode.unknown:
        return 'unknown';
    }
  }

  String get localizedName {
    switch (this) {
      case ProfileMode.private:
        return 'Privat';
      case ProfileMode.work:
        return 'Jobb';
      case ProfileMode.family:
        return 'Familie';
      case ProfileMode.unknown:
        return 'Ukjent';
    }
  }

  static ProfileMode fromString(String? value) {
    switch (value) {
      case 'private':
        return ProfileMode.private;
      case 'work':
        return ProfileMode.work;
      case 'family':
        return ProfileMode.family;
      case 'unknown':
      case null:
        return ProfileMode.unknown;
      default:
        return ProfileMode.unknown;
    }
  }
}

@immutable
class ProfileThemePreferences {
  const ProfileThemePreferences({
    this.mode = 'system',
    this.variant = 'default',
    this.primary = '#4C6EF5',
    this.accent = '#EDF2FF',
    this.background = '#0B1B3A',
    this.contrast = '#F8F9FA',
  });

  final String mode;
  final String variant;
  final String primary;
  final String accent;
  final String background;
  final String contrast;

  ProfileThemePreferences copyWith({
    String? mode,
    String? variant,
    String? primary,
    String? accent,
    String? background,
    String? contrast,
  }) {
    return ProfileThemePreferences(
      mode: mode ?? this.mode,
      variant: variant ?? this.variant,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      contrast: contrast ?? this.contrast,
    );
  }

  factory ProfileThemePreferences.fromJson(dynamic json) {
    if (json is ProfileThemePreferences) {
      return json;
    }
    final map = _coerceMap(json);
    return ProfileThemePreferences(
      mode: _string(map['mode'], fallback: 'system'),
      variant: _string(map['variant'], fallback: 'default'),
      primary: _string(map['primary'], fallback: '#4C6EF5'),
      accent: _string(map['accent'], fallback: '#EDF2FF'),
      background: _string(map['background'], fallback: '#0B1B3A'),
      contrast: _string(map['contrast'], fallback: '#F8F9FA'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'variant': variant,
      'primary': primary,
      'accent': accent,
      'background': background,
      'contrast': contrast,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileThemePreferences &&
            mode == other.mode &&
            variant == other.variant &&
            primary == other.primary &&
            accent == other.accent &&
            background == other.background &&
            contrast == other.contrast;
  }

  @override
  int get hashCode => Object.hash(
        mode,
        variant,
        primary,
        accent,
        background,
        contrast,
      );
}

@immutable
class ProfileNotificationQuietHours {
  const ProfileNotificationQuietHours({
    this.enabled = false,
    this.start = '22:00',
    this.end = '07:00',
  });

  final bool enabled;
  final String start;
  final String end;

  ProfileNotificationQuietHours copyWith({
    bool? enabled,
    String? start,
    String? end,
  }) {
    return ProfileNotificationQuietHours(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  factory ProfileNotificationQuietHours.fromJson(dynamic json) {
    final map = _coerceMap(json);
    return ProfileNotificationQuietHours(
      enabled: _bool(map['enabled'], fallback: false),
      start: _string(map['start'], fallback: '22:00'),
      end: _string(map['end'], fallback: '07:00'),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'start': start,
        'end': end,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileNotificationQuietHours &&
            enabled == other.enabled &&
            start == other.start &&
            end == other.end;
  }

  @override
  int get hashCode => Object.hash(enabled, start, end);
}

@immutable
class ProfileNotificationPolicy {
  const ProfileNotificationPolicy({
    this.allowPush = true,
    this.allowEmail = false,
    this.allowSms = false,
    this.mutedLabels = const <String>[],
    this.quietHours = const ProfileNotificationQuietHours(),
  });

  final bool allowPush;
  final bool allowEmail;
  final bool allowSms;
  final List<String> mutedLabels;
  final ProfileNotificationQuietHours quietHours;

  ProfileNotificationPolicy copyWith({
    bool? allowPush,
    bool? allowEmail,
    bool? allowSms,
    List<String>? mutedLabels,
    ProfileNotificationQuietHours? quietHours,
  }) {
    return ProfileNotificationPolicy(
      allowPush: allowPush ?? this.allowPush,
      allowEmail: allowEmail ?? this.allowEmail,
      allowSms: allowSms ?? this.allowSms,
      mutedLabels: mutedLabels ?? this.mutedLabels,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  factory ProfileNotificationPolicy.fromJson(dynamic json) {
    if (json is ProfileNotificationPolicy) {
      return json;
    }

    final map = _coerceMap(json);
    final mutedLabels = _coerceList(map['muted_labels'])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    return ProfileNotificationPolicy(
      allowPush: _bool(map['allow_push'], fallback: true),
      allowEmail: _bool(map['allow_email'], fallback: false),
      allowSms: _bool(map['allow_sms'], fallback: false),
      mutedLabels: mutedLabels,
      quietHours: ProfileNotificationQuietHours.fromJson(map['quiet_hours']),
    );
  }

  Map<String, dynamic> toJson() => {
        'allow_push': allowPush,
        'allow_email': allowEmail,
        'allow_sms': allowSms,
        'muted_labels': mutedLabels,
        'quiet_hours': quietHours.toJson(),
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileNotificationPolicy &&
            allowPush == other.allowPush &&
            allowEmail == other.allowEmail &&
            allowSms == other.allowSms &&
            const ListEquality<String>().equals(mutedLabels, other.mutedLabels) &&
            quietHours == other.quietHours;
  }

  @override
  int get hashCode => Object.hash(
        allowPush,
        allowEmail,
        allowSms,
        const ListEquality<String>().hash(mutedLabels),
        quietHours,
      );
}

enum SensitiveNotificationVisibility { show, hideContent, hideAll }

extension SensitiveNotificationVisibilityX on SensitiveNotificationVisibility {
  String get value {
    switch (this) {
      case SensitiveNotificationVisibility.show:
        return 'show';
      case SensitiveNotificationVisibility.hideContent:
        return 'hide_content';
      case SensitiveNotificationVisibility.hideAll:
        return 'hide_all';
    }
  }

  static SensitiveNotificationVisibility fromString(String? value) {
    switch (value) {
      case 'show':
        return SensitiveNotificationVisibility.show;
      case 'hide_content':
        return SensitiveNotificationVisibility.hideContent;
      case 'hide_all':
        return SensitiveNotificationVisibility.hideAll;
      default:
        return SensitiveNotificationVisibility.hideContent;
    }
  }
}

@immutable
class ProfileSecurityPolicy {
  const ProfileSecurityPolicy({
    this.requiresPin = false,
    this.biometricsEnabled = false,
    this.lockAfterMinutes = 5,
    this.sensitiveNotifications = SensitiveNotificationVisibility.hideContent,
  });

  final bool requiresPin;
  final bool biometricsEnabled;
  final int lockAfterMinutes;
  final SensitiveNotificationVisibility sensitiveNotifications;

  ProfileSecurityPolicy copyWith({
    bool? requiresPin,
    bool? biometricsEnabled,
    int? lockAfterMinutes,
    SensitiveNotificationVisibility? sensitiveNotifications,
  }) {
    return ProfileSecurityPolicy(
      requiresPin: requiresPin ?? this.requiresPin,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      lockAfterMinutes: lockAfterMinutes ?? this.lockAfterMinutes,
      sensitiveNotifications:
          sensitiveNotifications ?? this.sensitiveNotifications,
    );
  }

  factory ProfileSecurityPolicy.fromJson(dynamic json) {
    if (json is ProfileSecurityPolicy) {
      return json;
    }

    final map = _coerceMap(json);
    return ProfileSecurityPolicy(
      requiresPin: _bool(map['requires_pin'], fallback: false),
      biometricsEnabled: _bool(map['biometrics_enabled'], fallback: false),
      lockAfterMinutes: _int(map['lock_after_minutes'], fallback: 5),
      sensitiveNotifications:
          SensitiveNotificationVisibilityX.fromString(
        _string(map['sensitive_notifications'], fallback: 'hide_content'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'requires_pin': requiresPin,
        'biometrics_enabled': biometricsEnabled,
        'lock_after_minutes': lockAfterMinutes,
        'sensitive_notifications': sensitiveNotifications.value,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileSecurityPolicy &&
            requiresPin == other.requiresPin &&
            biometricsEnabled == other.biometricsEnabled &&
            lockAfterMinutes == other.lockAfterMinutes &&
            sensitiveNotifications == other.sensitiveNotifications;
  }

  @override
  int get hashCode => Object.hash(
        requiresPin,
        biometricsEnabled,
        lockAfterMinutes,
        sensitiveNotifications,
      );
}

@immutable
class Profile extends BaseModel {
  Profile({
    super.id,
    required this.username,
    this.uid,
    this.name,
    this.slug,
    this.mode = ProfileMode.private,
    ProfileThemePreferences? theme,
    ProfileNotificationPolicy? notificationPolicy,
    ProfileSecurityPolicy? securityPolicy,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
    this.avatarUrl,
    this.settings,
    List<dynamic>? roles,
    this.status,
    this.firstName,
    this.lastName,
  })  : theme = theme ?? const ProfileThemePreferences(),
        notificationPolicy =
            notificationPolicy ?? const ProfileNotificationPolicy(),
        securityPolicy = securityPolicy ?? const ProfileSecurityPolicy(),
        roles = roles ?? const [];

  final String username;
  final String? uid;
  final String? name;
  final String? slug;
  final ProfileMode mode;
  final ProfileThemePreferences theme;
  final ProfileNotificationPolicy notificationPolicy;
  final ProfileSecurityPolicy securityPolicy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? avatarUrl;
  final Map<String, dynamic>? settings;
  final List<dynamic> roles;
  final String? status;
  final String? firstName;
  final String? lastName;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    final parts = [firstName, lastName]
        .where((part) => part != null && part!.trim().isNotEmpty)
        .map((part) => part!.trim())
        .toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return username;
  }

  String get handle => slug ?? username;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'username': username,
      'name': name,
      'slug': slug,
      'mode': mode.value,
      'theme': theme.toJson(),
      'notification_policy': notificationPolicy.toJson(),
      'security_policy': securityPolicy.toJson(),
      'is_active': isActive,
      'first_name': firstName,
      'last_name': lastName,
      'status': status,
      'avatar_url': avatarUrl,
      'settings': settings,
      'roles': roles,
      'inserted_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Profile &&
            id == other.id &&
            username == other.username &&
            uid == other.uid &&
            name == other.name &&
            slug == other.slug &&
            mode == other.mode &&
            theme == other.theme &&
            notificationPolicy == other.notificationPolicy &&
            securityPolicy == other.securityPolicy &&
            isActive == other.isActive &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            avatarUrl == other.avatarUrl &&
            const DeepCollectionEquality().equals(settings, other.settings) &&
            const DeepCollectionEquality().equals(roles, other.roles) &&
            status == other.status &&
            firstName == other.firstName &&
            lastName == other.lastName;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      username.hashCode ^
      uid.hashCode ^
      name.hashCode ^
      slug.hashCode ^
      mode.hashCode ^
      theme.hashCode ^
      notificationPolicy.hashCode ^
      securityPolicy.hashCode ^
      isActive.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      avatarUrl.hashCode ^
      const DeepCollectionEquality().hash(settings) ^
      const DeepCollectionEquality().hash(roles) ^
      status.hashCode ^
      firstName.hashCode ^
      lastName.hashCode;

  @override
  String toString() => '@$handle';

  Profile copyWith({
    String? id,
    String? uid,
    String? username,
    String? name,
    String? slug,
    ProfileMode? mode,
    ProfileThemePreferences? theme,
    ProfileNotificationPolicy? notificationPolicy,
    ProfileSecurityPolicy? securityPolicy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
    Map<String, dynamic>? settings,
    List<dynamic>? roles,
    String? status,
    String? firstName,
    String? lastName,
  }) {
    return Profile(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      mode: mode ?? this.mode,
      theme: theme ?? this.theme,
      notificationPolicy: notificationPolicy ?? this.notificationPolicy,
      securityPolicy: securityPolicy ?? this.securityPolicy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      settings: settings ?? this.settings,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile.fromJson(map);
  }

  factory Profile.fromJson(dynamic json) {
    if (json is Profile) {
      return json;
    }

    if (json is! Map) {
      throw const FormatException('Failed to decode profile.');
    }

    final map = Map<String, dynamic>.from(json as Map);
    final settingsValue = map['settings'];
    final rolesValue = map['roles'];
    final username = _string(
      map['username'],
      fallback: _string(map['slug'], fallback: _string(map['name'], fallback: 'profile')),
    );

    return Profile(
      id: _string(map['id'], fallback: ''),
      uid: _string(map['uid']),
      username: username,
      name: _string(map['name']),
      slug: _string(map['slug']),
      mode: ProfileModeX.fromString(_string(map['mode'], fallback: 'unknown')),
      theme: ProfileThemePreferences.fromJson(map['theme']),
      notificationPolicy: ProfileNotificationPolicy.fromJson(
        map['notification_policy'],
      ),
      securityPolicy: ProfileSecurityPolicy.fromJson(map['security_policy']),
      isActive: _bool(map['is_active'], fallback: false),
      firstName: _string(map['first_name']),
      lastName: _string(map['last_name']),
      status: _string(map['status']),
      avatarUrl: _string(map['avatar_url']),
      settings: _coerceMap(settingsValue),
      roles: _coerceList(rolesValue),
      createdAt: _parseDate(map['inserted_at']) ?? _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

Map<String, dynamic>? _coerceMap(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, dynamic entry) => MapEntry(key.toString(), entry));
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      return _coerceMap(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<dynamic> _coerceList(dynamic value) {
  if (value == null) {
    return const [];
  }
  if (value is List) {
    return List<dynamic>.from(value);
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return List<dynamic>.from(decoded);
      }
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

String? _string(dynamic value, {String? fallback}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

int _int(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
