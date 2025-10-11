import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class ConnectivityEvent {
  const ConnectivityEvent(this.regained, this.lost);
  final bool regained;
  final bool lost;
}

class ConnectivityService {
  final conn = Connectivity();

  /// The internal stream controller
  final StreamController<ConnectivityEvent> _controller =
      StreamController<ConnectivityEvent>.broadcast();

  /// The logger
  final Logger _log = Logger('ConnectivityService');

  /// Caches the current connectivity state
  late List<ConnectivityResult> _connectivity;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  Stream<ConnectivityEvent> get stream => _controller.stream;

  @visibleForTesting
  void setConnectivity(ConnectivityResult result) {
    _log.warning(
      'Internal connectivity state changed by request originating from outside ConnectivityService: $result',
    );
  }

  Future<void> initialize() async {
    _connectivity = await conn.checkConnectivity();
    _log.info('ConnectivityService starting up');
    if (_connectivity.contains(ConnectivityResult.none)) {
      _log.warning('Can\'t seem to be able to connect to the internet!');
    }

    /*conn.onConnectivityChanged.listen((ConnectivityResult result) {
      final regained = _connectivity == ConnectivityResult.none &&
          result != ConnectivityResult.none;
      final lost = result == ConnectivityResult.none;
      _connectivity = result;

      _controller.add(
        ConnectivityEvent(
          regained,
          lost,
        ),
      );
    });*/
    _connectivitySubscription =
        conn.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    _log.info('Connectivity changed: $result');
    _connectivity = result;
  }

  List<ConnectivityResult> get currentState => _connectivity;

  Future<bool> hasConnection() async {
    return _connectivity.contains(ConnectivityResult.none) == false;
  }
}
