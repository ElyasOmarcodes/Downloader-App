import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the active connection is WiFi (vs mobile / other), used to
/// pick the download concurrency limit.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  Future<bool> isWifi() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }
}
