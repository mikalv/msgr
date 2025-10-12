import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Represents a bridge connector that can be displayed in the client catalog.
@immutable
class BridgeCatalogEntry {
  const BridgeCatalogEntry({
    required this.id,
    required this.service,
    required this.displayName,
    required this.description,
    required this.status,
    required this.auth,
    required this.capabilities,
    required this.categories,
    required this.prerequisites,
    required this.tags,
    required this.authPaths,
  });

  factory BridgeCatalogEntry.fromJson(Map<String, dynamic> json) {
    return BridgeCatalogEntry(
      id: json['id'] as String? ?? '',
      service: json['service'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      auth: _normalizeMap(json['auth']),
      capabilities: _normalizeMap(json['capabilities']),
      categories:
          _normalizeStringList(json['categories'] as List<dynamic>? ?? const []),
      prerequisites: _normalizeStringList(
          json['prerequisites'] as List<dynamic>? ?? const []),
      tags: _normalizeStringList(json['tags'] as List<dynamic>? ?? const []),
      authPaths: _normalizeMap(json['auth_paths']),
    );
  }

  final String id;
  final String service;
  final String displayName;
  final String description;
  final String status;
  final Map<String, dynamic> auth;
  final Map<String, dynamic> capabilities;
  final List<String> categories;
  final List<String> prerequisites;
  final List<String> tags;
  final Map<String, dynamic> authPaths;

  bool get isAvailable => status == 'available';
  bool get isComingSoon => status == 'coming_soon';

  String get loginMethod => auth['method']?.toString() ?? '';
  String get authSurface => auth['auth_surface']?.toString() ?? '';

  Map<String, dynamic>? get formSchema {
    final value = auth['form'];
    return value is Map<String, dynamic> ? value : null;
  }

  Map<String, dynamic>? get oauthMetadata {
    final value = auth['oauth'];
    return value is Map<String, dynamic> ? value : null;
  }

  String? get startAuthorizationPath {
    final value = authPaths['start'];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BridgeCatalogEntry &&
        other.id == id &&
        other.service == service &&
        other.displayName == displayName &&
        other.description == description &&
        other.status == status &&
        const DeepCollectionEquality().equals(other.auth, auth) &&
        const DeepCollectionEquality()
            .equals(other.capabilities, capabilities) &&
        const ListEquality<String>().equals(other.categories, categories) &&
        const ListEquality<String>()
            .equals(other.prerequisites, prerequisites) &&
        const ListEquality<String>().equals(other.tags, tags) &&
        const DeepCollectionEquality().equals(other.authPaths, authPaths);
  }

  @override
  int get hashCode => Object.hash(
        id,
        service,
        displayName,
        description,
        status,
        const DeepCollectionEquality().hash(auth),
        const DeepCollectionEquality().hash(capabilities),
        Object.hashAll(categories),
        Object.hashAll(prerequisites),
        Object.hashAll(tags),
        const DeepCollectionEquality().hash(authPaths),
      );

  static Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  static List<String> _normalizeStringList(List<dynamic> raw) {
    return raw
        .map((item) => item.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
