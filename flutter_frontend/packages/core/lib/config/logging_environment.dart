import 'dart:convert';

class LoggingEnvironment {
  LoggingEnvironment._()
      : _default = _LoggingValues(
          enabled: const bool.fromEnvironment('MSGR_LOG_ENABLED',
              defaultValue: false),
          endpoint: const String.fromEnvironment('MSGR_LOG_ENDPOINT',
              defaultValue: 'http://localhost:5080'),
          org: const String.fromEnvironment('MSGR_LOG_ORG',
              defaultValue: 'default'),
          stream: const String.fromEnvironment('MSGR_LOG_STREAM',
              defaultValue: 'flutter'),
          dataset: const String.fromEnvironment('MSGR_LOG_DATASET',
              defaultValue: '_json'),
          username: const String.fromEnvironment('MSGR_LOG_USERNAME',
              defaultValue: 'root@example.com'),
          password: const String.fromEnvironment('MSGR_LOG_PASSWORD',
              defaultValue: 'Complexpass#123'),
          service: const String.fromEnvironment('MSGR_LOG_SERVICE',
              defaultValue: 'msgr_flutter'),
        );

  static final LoggingEnvironment instance = LoggingEnvironment._();

  final _LoggingValues _default;
  _LoggingValues? _override;

  bool get enabled => (_override ?? _default).enabled;

  Uri get ingestUri => (_override ?? _default).ingestUri;

  Map<String, String> get authorizationHeader =>
      (_override ?? _default).authorizationHeader;

  String get serviceName => (_override ?? _default).service;

  void override({
    bool? enabled,
    String? endpoint,
    String? org,
    String? stream,
    String? dataset,
    String? username,
    String? password,
    String? service,
  }) {
    final source = _override ?? _default;
    _override = source.copyWith(
      enabled: enabled,
      endpoint: endpoint,
      org: org,
      stream: stream,
      dataset: dataset,
      username: username,
      password: password,
      service: service,
    );
  }

  void clearOverride() {
    _override = null;
  }
}

class _LoggingValues {
  const _LoggingValues({
    required this.enabled,
    required this.endpoint,
    required this.org,
    required this.stream,
    required this.dataset,
    required this.username,
    required this.password,
    required this.service,
  });

  final bool enabled;
  final String endpoint;
  final String org;
  final String stream;
  final String dataset;
  final String username;
  final String password;
  final String service;

  Uri get ingestUri {
    final base = Uri.parse(endpoint);
    final cleanedOrg = _clean(org);
    final cleanedStream = _clean(stream);
    final cleanedDataset = _clean(dataset);

    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'api',
      cleanedOrg,
      'logs',
      cleanedStream,
      cleanedDataset,
    ];

    return base.replace(pathSegments: segments);
  }

  Map<String, String> get authorizationHeader {
    if (username.isEmpty || password.isEmpty) {
      return const <String, String>{};
    }

    final encoded = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $encoded'};
  }

  _LoggingValues copyWith({
    bool? enabled,
    String? endpoint,
    String? org,
    String? stream,
    String? dataset,
    String? username,
    String? password,
    String? service,
  }) {
    return _LoggingValues(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      org: org ?? this.org,
      stream: stream ?? this.stream,
      dataset: dataset ?? this.dataset,
      username: username ?? this.username,
      password: password ?? this.password,
      service: service ?? this.service,
    );
  }

  static String _clean(String value) =>
      value.split('/').where((segment) => segment.isNotEmpty).join('/');
}
