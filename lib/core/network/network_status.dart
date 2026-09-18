import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper so sync connectivity can be faked in tests.
abstract class NetworkStatus {
  Future<bool> get isOnline;
  Stream<bool> get onOnlineChanged;
}

class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Stream<bool> get onOnlineChanged =>
      _connectivity.onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      );
}

final networkStatusProvider = Provider<NetworkStatus>((ref) {
  return ConnectivityNetworkStatus();
});
