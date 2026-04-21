import 'dart:async';
import 'dart:io';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  
  factory ConnectivityService() {
    return _instance;
  }
  
  ConnectivityService._();

  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = false;
  Timer? _connectivityTimer;

  Future<void> initialize() async {
    await _checkConnectivity();
    // Check connectivity every 30 seconds
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
      }
    } catch (_) {
      final wasOnline = _isOnline;
      _isOnline = false;
      
      if (wasOnline) {
        _connectivityController.add(false);
      }
    }
  }

  Future<bool> checkNow() async {
    await _checkConnectivity();
    return _isOnline;
  }

  bool get isOnline => _isOnline;

  Stream<bool> get connectivityStream => _connectivityController.stream;

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
  }
}
