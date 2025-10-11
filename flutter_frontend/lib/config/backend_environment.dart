/// Provides runtime and compile-time configuration for the backend connection.
///
/// The configuration reads sane defaults from compile-time `--dart-define`
/// flags so the backend can be changed without touching the source. It also
/// offers an imperative override for development tooling where switching
/// between environments during a session is useful.
class BackendEnvironment {
  BackendEnvironment._()
      : _default = _BackendValues(
          scheme:
              const String.fromEnvironment('MSGR_BACKEND_SCHEME', defaultValue: 'http'),
          host: const String.fromEnvironment('MSGR_BACKEND_HOST', defaultValue: 'localhost'),
          port: _parsePort(
            const String.fromEnvironment('MSGR_BACKEND_PORT', defaultValue: '4000'),
          ),
          apiPath:
              const String.fromEnvironment('MSGR_BACKEND_API_PATH', defaultValue: 'api'),
        );

  static final BackendEnvironment instance = BackendEnvironment._();

  final _BackendValues _default;
  _BackendValues? _override;

  /// Returns the active API base [Uri], including scheme, host, optional port
  /// and API prefix.
  Uri get apiBaseUri => (_override ?? _default).baseUri;

  /// Returns the base URL string representation. This is equivalent to
  /// [apiBaseUri].toString() but cached to avoid allocating new instances in
  /// hot paths.
  String get apiBaseUrl => (_override ?? _default).baseUrl;

  /// Builds a [Uri] by combining the base API path with an additional
  /// [relativePath]. Leading or trailing slashes are handled automatically.
  Uri apiUri(String relativePath, {Map<String, dynamic>? queryParameters}) {
    return (_override ?? _default)
        .resolve(relativePath, queryParameters: queryParameters);
  }

  /// Imperatively overrides individual parts of the backend configuration at
  /// runtime. This is primarily useful during development when you need to
  /// toggle between environments without rebuilding the application.
  void override({
    String? scheme,
    String? host,
    int? port,
    String? apiPath,
  }) {
    final source = _override ?? _default;
    _override = source.copyWith(
      scheme: scheme,
      host: host,
      port: port,
      apiPath: apiPath,
    );
  }

  /// Removes any runtime overrides, falling back to the compile-time defaults.
  void clearOverride() {
    _override = null;
  }

  static int? _parsePort(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(trimmed);
    return parsed == null || parsed <= 0 ? null : parsed;
  }
}

class _BackendValues {
  const _BackendValues({
    required this.scheme,
    required this.host,
    required this.port,
    required this.apiPath,
  });

  final String scheme;
  final String host;
  final int? port;
  final String apiPath;

  Uri get baseUri => Uri(
        scheme: scheme,
        host: host,
        port: port,
        pathSegments: _pathSegments(apiPath),
      );

  String get baseUrl => baseUri.toString();

  _BackendValues copyWith({
    String? scheme,
    String? host,
    int? port,
    String? apiPath,
  }) {
    return _BackendValues(
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      port: port ?? this.port,
      apiPath: apiPath ?? this.apiPath,
    );
  }

  Uri resolve(String relativePath,
      {Map<String, dynamic>? queryParameters}) {
    final segments = <String>[
      ...baseUri.pathSegments,
      ..._pathSegments(relativePath),
    ];

    return baseUri.replace(
      pathSegments: segments,
      queryParameters: _normalizeQuery(queryParameters),
    );
  }

  static List<String> _pathSegments(String rawPath) {
    if (rawPath.isEmpty) {
      return const [];
    }

    return rawPath
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, String>? _normalizeQuery(
      Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return null;
    }

    final normalized = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalized[key] = value.toString();
    });

    return normalized.isEmpty ? null : normalized;
  }
}
