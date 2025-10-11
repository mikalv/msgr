import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:libmsgr/libmsgr.dart';
import 'package:logging/logging.dart';

class MemorySecureStorage implements ASecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey(key) async {
    return _values.containsKey(key as String);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<void> deleteKey(key) async {
    _values.remove(key as String);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<String?> readValue(key) async {
    return _values[key as String];
  }

  @override
  Future<String> writeValue(key, value) async {
    _values[key as String] = value as String;
    return value as String;
  }
}

class MemorySharedPreferences implements ASharedPreferences {
  final Map<String, Object?> _store = {};

  @override
  Future<void> clear({Set<String>? allowList}) async {
    if (allowList == null) {
      _store.clear();
    } else {
      _store.removeWhere((key, value) => !allowList.contains(key));
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    return _store.containsKey(key);
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    if (allowList == null) {
      return Map<String, Object?>.from(_store);
    }
    final result = <String, Object?>{};
    for (final key in allowList) {
      if (_store.containsKey(key)) {
        result[key] = _store[key];
      }
    }
    return result;
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = _store[key];
    if (value is bool) {
      return value;
    }
    return null;
  }

  @override
  Future<double?> getDouble(String key) async {
    final value = _store[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  @override
  Future<int?> getInt(String key) async {
    final value = _store[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    if (allowList == null) {
      return _store.keys.toSet();
    }
    return _store.keys.where((key) => allowList.contains(key)).toSet();
  }

  @override
  Future<String?> getString(String key) async {
    final value = _store[key];
    if (value is String) {
      return value;
    }
    return null;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = _store[key];
    if (value is List<String>) {
      return List<String>.from(value);
    }
    return null;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _store[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _store[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _store[key] = List<String>.from(value);
  }
}

class FakeDeviceInfo implements ADeviceInfo {
  FakeDeviceInfo(this.deviceId);

  final String deviceId;

  Map<String, dynamic> get info => {
        'platform': 'integration-test',
        'platformVersion': Platform.version,
        'model': 'cli-driver',
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'deviceId': deviceId,
      };

  Future<Map<String, dynamic>> appInfo() async {
    return {
      'appName': 'integration-cli',
      'appVersion': '0.0.1',
      'buildNumber': 'test',
    };
  }

  @override
  Future<Map<dynamic, dynamic>> extractInformation() async {
    return Map<dynamic, dynamic>.from(info);
  }
}

Future<void> main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    stderr.writeln('[${event.level.name}] ${event.loggerName}: ${event.message}');
  });

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'integration+$timestamp@example.com';
  final teamName = 'integration$timestamp';
  final username = 'integration_${timestamp.toRadixString(36)}';

  final memorySecureStorage = MemorySecureStorage();
  final memorySharedPreferences = MemorySharedPreferences();
  final fakeDeviceInfo = FakeDeviceInfo('device-$timestamp');

  final lib = LibMsgr();
  lib.secureStorage = memorySecureStorage;
  lib.sharedPreferences = memorySharedPreferences;
  lib.deviceInfoInstance = fakeDeviceInfo;

  try {
    await lib.bootstrapLibrary();

    final registration = RegistrationService();
    final appInfo = await fakeDeviceInfo.appInfo();
    registration.updateCachedContext(
      deviceInfo: fakeDeviceInfo.info,
      appInfo: appInfo,
    );
    await registration.maybeRegisterDevice(
      deviceInfo: fakeDeviceInfo.info,
      appInfo: appInfo,
    );

    final challenge =
        await registration.requestForSignInCodeEmail(email);
    if (challenge == null || challenge.debugCode == null) {
      throw StateError('Failed to obtain OTP challenge for $email');
    }

    final user = await registration.submitEmailCodeForToken(
      challengeId: challenge.id,
      code: challenge.debugCode!,
      displayName: 'Integration $timestamp',
    );

    if (user == null) {
      throw StateError('Failed to exchange OTP for user session');
    }

    final authRepo = lib.authRepository as AuthRepository;

    final team = await authRepo.createNewTeam(
      teamName,
      'Integration test team created at $timestamp',
      user.accessToken,
    );

    if (team == null) {
      throw StateError('Failed to create team $teamName');
    }

    final selection = await authRepo.selectTeam(team.name, user.accessToken);
    if (selection == null) {
      throw StateError('Failed to select team ${team.name}');
    }

    final teamAccessToken = selection['teamAccessToken'] as String?;
    if (teamAccessToken == null || teamAccessToken.isEmpty) {
      throw StateError('Team access token missing in selection response');
    }

    String? profileId = (selection['profile'] as Map<String, dynamic>?)?['id']
        as String?;

    if (profileId == null) {
      final profile = await authRepo.createProfile(
        team.name,
        teamAccessToken,
        username,
        'Integration',
        'Tester',
      );
      if (profile == null || profile.id == null) {
        throw StateError('Failed to create profile for team ${team.name}');
      }
      profileId = profile.id;
    }

    final teams = await authRepo.listMyTeams(user.accessToken);

    final output = {
      'email': email,
      'userId': user.uid,
      'teamId': team.id,
      'teamName': team.name,
      'profileId': profileId,
      'teamAccessToken': teamAccessToken,
      'teamsCount': teams.length,
      'teamHost': '${team.name}.teams.7f000001.nip.io:4080',
    };

    stdout.writeln(jsonEncode(output));
  } catch (error, stackTrace) {
    stderr.writeln('Integration flow failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
