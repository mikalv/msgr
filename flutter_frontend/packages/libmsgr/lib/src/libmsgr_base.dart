library libmsg;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/connection.dart';
import 'package:libmsgr/src/key_manager.dart';
import 'package:libmsgr/src/server_resolver.dart';
import 'package:libmsgr/src/typedefs.dart';
import 'package:logging/logging.dart';

/// Connection status check result.
enum ConnectivityStatus {
  /// WiFi: Device connected via Wi-Fi
  wifi,

  /// Ethernet: Device connected to ethernet network
  ethernet,

  /// Mobile: Device connected to cellular network
  mobile,

  /// None: Device not connected to any network
  none,
}

/// Checks if you are awesome. Spoiler: you are.
class LibMsgr {
  bool get isAwesome => true;

  final Logger _log = Logger('LibMsgr');

  static final LibMsgr _instance = LibMsgr._internal();

  late KeyManager _keyManager;
  late AuthRepository _authRepository;
  final RepositoryFactory _repositoryFactory = RepositoryFactory();
  final List<MsgrConnection> _wsConnections = [];
  ASharedPreferences? _sharedPreferences;
  ASecureStorage? _secureStorageInstance;
  ADeviceInfo? _deviceInfo;
  String? _currentUserID;
  String? _currentTeamID;
  bool hasBootstrapped = false;

  get repositoryFactory => _repositoryFactory;
  get authRepository => _authRepository;
  get secureStorage => _secureStorageInstance!;
  get deviceInfo => _deviceInfo!;
  get sharedPreferences => _sharedPreferences!;
  get currentUserID => _currentUserID;
  get currentTeamID => _currentTeamID;

  get keyManager => _keyManager;

  set currentTeamID(val) {
    _log.finest('Team is set, $val');
    _currentTeamID = val;
  }

  set currentUserID(val) {
    _log.finest('User is set, $val');
    _currentUserID = val;
  }

  set secureStorage(val) {
    _log.finest('Secure Storage is set.');
    _secureStorageInstance = val;
  }

  set deviceInfoInstance(val) {
    _log.finest('Device Info is set.');
    _deviceInfo = val;
  }

  set sharedPreferences(val) {
    _log.finest('Shared Preferences is set.');
    _sharedPreferences = val;
  }

  factory LibMsgr() {
    return _instance;
  }

  Future<void> resetEverything(bool yesImFuckingSure) async {
    if (yesImFuckingSure) {
      await _secureStorageInstance?.deleteAll();
      await _sharedPreferences?.clear();
    }
  }

  MsgrConnection? getWebsocketConnection() {
    if (_wsConnections.isNotEmpty) {
      for (var conn in _wsConnections) {
        return conn;
      }
    }
    return null;
  }

  Future<bool> connectWebsocket(String uid, String teamName,
      String teamAccessToken, ReduxDispatchCallback dispatchFn) async {
    if (!hasBootstrapped) {
      throw 'Can\'t connect to websocket before library has bootstrapped!';
    }
    var connectedConn = getWebsocketConnection();
    if (connectedConn == null) {
      final serverUrl = ServerResolver.getTeamWebSocketServer(teamName);
      _log.info('Connecting to server $serverUrl');
      final conn = MsgrConnection(
          serverUrl, {'token': teamAccessToken}, teamName, uid, dispatchFn);
      _wsConnections.add(conn);
      await conn.connect();
      connectedConn = conn;
    }
    return connectedConn.isConnected();
  }

  Future<bool> bootstrapLibrary() async {
    if (_sharedPreferences == null) {
      throw 'Can\'t bootstrap without a SharedPreferences instance! check your implementation!';
    }
    if (_secureStorageInstance == null) {
      throw 'Can\'t bootstrap without a secure storage! check your implementation!';
    }
    if (_deviceInfo == null) {
      throw 'Can\'t bootstrap without a DeviceInfo instance! check your implementation!';
    }

    // Load cryptographic keys
    _keyManager = KeyManager(storage: _secureStorageInstance!);
    await _keyManager.getOrGenerateDeviceId();
    _authRepository = AuthRepository(teamName: 'dummy');

    // Must happen at the end
    hasBootstrapped = true;
    _log.info('LibMsgr has bootstrapped!');
    return hasBootstrapped;
  }

  static String getHashedString(String str) {
    var bytes = utf8.encode(str); // data being hashed
    Digest digest = sha1.convert(bytes);
    return digest.toString();
  }

  LibMsgr._internal() {
    _log.info('Starting up');
  }
}
