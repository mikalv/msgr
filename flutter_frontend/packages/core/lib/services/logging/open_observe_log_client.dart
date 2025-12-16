import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:messngr/config/logging_environment.dart';

class OpenObserveLogClient {
  OpenObserveLogClient._(this._environment, this._client);

  final LoggingEnvironment _environment;
  final http.Client _client;

  static OpenObserveLogClient? maybeCreate({http.Client? client}) {
    final env = LoggingEnvironment.instance;
    if (!env.enabled) {
      return null;
    }

    return OpenObserveLogClient._(env, client ?? http.Client());
  }

  Future<void> send(LogRecord record) async {
    final body = jsonEncode([
      {
        'level': record.level.name,
        'message': _stringify(record.message),
        'logger': record.loggerName,
        'service': _environment.serviceName,
        'timestamp': record.time.toUtc().toIso8601String(),
        if (record.error != null) 'error': _stringify(record.error!),
        if (record.stackTrace != null)
          'stackTrace': record.stackTrace.toString(),
        'metadata': {
          'sequenceNumber': record.sequenceNumber,
          if (record.zone != null) 'zone': record.zone.toString(),
        },
      }
    ]);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._environment.authorizationHeader,
    };

    try {
      final response = await _client.post(_environment.ingestUri,
          headers: headers, body: body);
      if (response.statusCode >= 400) {
        debugPrint(
            'OpenObserve rejected log ${response.statusCode}: ${response.body}');
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to push log to OpenObserve: $error\n$stackTrace');
    }
  }

  void close() {
    _client.close();
  }

  static String _stringify(Object value) {
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Iterable || value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }
}
